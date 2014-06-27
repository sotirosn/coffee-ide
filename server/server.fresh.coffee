log = console.log.bind console
io = require('socket.io')
http = require('express')

log process.argv

# mostly equivilent to iterator.next() except when that iterator finishes
# then it recursivly calls .end.next()
# so it could actually call iterator.end...end.next()

# warps a routine (generator) in a thread (iterator) and returns a callback
# the thread is expected to return a callback from next which then accepts the
# iterator object itself.  This gives the the async callback the ability to resume
# the iterator with next() or throw an exception with throw()
class Routine
	constructor:(@name, @iterator, @onerror = (error)->throw error)->
		
	next:(value)->
		try @resume value # resume the iterator but with caution
		catch exception then @onerror exception
		(@end)=> log "#{@name} waiting on -> #{@end.name || @end}" if @name
	
	throw:(exception)->
		try @iterator.throw exception
		catch exception then @onerror exception
		
	resume:(value)->
		next = @iterator.next value
		if !next.done
			log "resuming #{@name}" if @name
			next.value @
		else if @end?
			log "finished #{@name}" if @name
			@end.resume next.value
		
run = (routine, name)->
	(args...)->
		log "running #{name}" if name
		# arg[2] is the express api next() callback used to
		# send exceptions and errors back to the requesting client
		(new Routine name, routine(args...), args[2]).next()

class Application
	fs: require('fs')
	pm: require('child_process')
	processes: {}
	
	constructor:(@mountpoints = {})->
		@readfile = @readfile.bind @
		@listdir = @listdir.bind @
		
	readfile:(path)->
		(wait)=>
			@fs.readFile path, encoding:'utf8', (error, data)->
				return wait.throw error if error?
				wait.next data

	writefile:(path, data)->
		(wait)=>
			@fs.writeFile path, data, (error, data)->
				return wait.throw error if error?
				wait.next()
			
	listdir:(path)->
		(wait)=>
			@fs.readdir path, (error, data)->
				return wait.throw error if error?
				wait.next data
				
	mkdir:(path)->
		(wait)=>
			@fs.mkdir path, (error)->
				return wait.throw error if error?
				wait.next()		
				
	statfile:(path)->
		exists = yield (wait)=> @fs.exists path, (result)->
			wait.next result
		return false if !exists
		
		return yield (wait)=> @fs.stat path, (error, stats)->
			return wait.throw error if error?
			wait.next stats

	delete:(path)->
		
	rename:(path, name)->
		(wait)=>
			newpath = path.replace /([^/])+$/, name
			@fs.rename path, newpath, (error)->
				return wait.throw error if error?
				wait.next()
	
	exec:(path, command)->
		log "/> cd #{path} && #{command}"
		(wait)=>
			@pm.exec "cd #{path} && #{command}", (error, stdout, stderr)->
				return wait.throw error if error?
				wait.next [stdout, stderr]
	
	run:(path, command)->
		child = @pm.spawn 'cmd', ['/C', "cd #{path} && call ./#{command}"]
		@processes[child.pid] = child
		return child.pid
	
	connect:(connection, pid)->
		child = @processes[pid]
		if !child?
			connection.emit 'stderr', "pid (#{pid}) not found!"
			connection.disconnect() 
			return 
		
		child.stdout.on 'data', (data)->
			connection.emit 'stdout', data.toString()
		child.stderr.on 'data', (data)->
			connection.emit 'stderr', data.toString()
		child.on 'close', (exitcode)=>
			log "closed (#{pid}) #{exitcode}"
			# note: if client closes the connection this will not be recevied
			(connection.emit 'stderr', "exitcode: #{exitcode}") if exitcode != 0
			connection.disconnect()
			delete @processes[pid]
		connection.on 'disconnect', =>
			log "killing task (#{pid})"
			@pm.exec "taskkill /PID #{pid} /T /F"
		
	getpath:(path)->
		# pull off the first */ as the basepath, join the remaining */*/*... as the filepath
		path = path.split '/'
		[base, path] = [path.splice(0, 1)[0], path.join '/']
		
		return ['.', path] if base == ''
			
		throw "basepath not found: #{base}" if !@mountpoints[base]?
		[@mountpoints[base], path]

	getcommandpath:(path)->
		# pull off the first */ as the basepath, join the remaining */*/*... as the filepath
		path = path.split ' '
		[base, path] = [path.splice(0, 1)[0], path.join ' ']
		
		return ['.', path] if base == ''
			
		throw "basepath not found: #{base}" if !@mountpoints[base]?
		[@mountpoints[base], path]
		
	getsitepath:(path)->
		# pull off the first */ as the basepath, join the remaining */*/*... as the filepath
		path = path.split '/'
		[base, path] = [path.splice(0, 1)[0], path.join '/']
			
		throw "sitepath not found: #{base}" if !@sitepaths[base]?
		[@sitepaths[base], path].join '/'
	
	addProject:(project)->
		@mountpoints[project.name] = project.path

app = new Application
###
do run ->
	data = yield app.readfile './config.js'
	(eval data) app
###
(require process.cwd() + '/config.coffee') app

getpostdata = (request)->
	(wait)->
		data = ''
		request.on 'data', (chunck)->
			data += chunck
			if data.length > 1e6
				request.connection.close()
				wait.throw "POST data too large!"
		request.on 'end', (chunck)->
			wait.next data
	
# regular http web server
codemirrordir = '/Users/Games/Documents/GitHub/CodeMirror/'
http()
	#.use (request, response, next)->
	#	log request.url
	#	next()
	.get '/',
		(request, response)->
			response.sendfile 'client/index.html'
	.get '/codemirror/*',
		(request, response)->
			response.sendfile codemirrordir + request.params[0]
	.get '/site/*',
		(request, response)->
			log request.url
			sitepath = app.getsitepath request.params[0]
			response.sendfile sitepath
	.get '/*',
		(request, response)->
			response.sendfile 'client/' + request.params[0]
			
	.listen(process.argv[2] || 8080)
	
# application http RESTful server
http()
	.use (request, response, next)->
		log request.url
		response.set('Access-Control-Allow-Origin', 'http://localhost:8080')
		next()
	
	.get '/listdir/*',
		run (request, response)->
			dirpath = (app.getpath request.params[0]).join '/'
			
			log "listing files in: #{dirpath}"
			filelist = yield app.listdir(dirpath)
			
			# sort out directories from files
			results = {}
			for filename in filelist
				stats = app.fs.statSync dirpath + '/' + filename
				if stats.isDirectory()
					results[filename] = 'dir'
				else if stats.isFile()
					results[filename] = 'file'
			response.json results
		#, 'listdir'
	
	.get '/listdir',
		(request, response)->
			log Object.keys app.mountpoints
			response.json (Object.keys app.mountpoints)

	.get '/readfile/*',
		run (request, response)->
			filepath = (app.getpath request.params[0]).join '/'
			
			log "reading from: #{filepath}"
			filedata = yield app.readfile(filepath)
			response.json filedata
		#, 'readfile'

	.post '/writefile/*',
		run (request, response)->
			# parse url -> file path
			[basepath, filepath] = app.getpath request.params[0]
			
			# capture POST data
			postdata = yield (getpostdata request)
			
			log "writing to: #{basepath}/#{filepath}"
			yield app.writefile("#{basepath}/#{filepath}", postdata)
			
			log [stdout, stderr] = yield app.exec basepath, "cake -f #{filepath} files:onwrite"
			response.json [stdout, stderr]
		#, 'writefile'

	.get '/mkdir/*',
		run (request, response)->
			dirpath = (app.getpath request.params[0]).join '/'
			log "mkdir: #{dirpath}"
			yield app.mkdir dirpath
			response.json 'ok'
		#, 'mkdir'
		
	.get '/rename/*',
		run (request, response)->
			# parse url -> file path
			path = (app.getpath request.params[0]).join '/'
			name = request.query.name
			
			log "rename: #{path} -> #{name}"
			yield app.rename(path, name)
			response.json 'ok'
		#, 'rename'
	
	.get '/delete/*',
		run (request, response)->
			# parse url -> file path
			path = (app.getpath request.params[0]).join '/'
			
			log "delete: #{path}"
			yield app.delete(path)
			response.json 'ok'
		#, 'delete'
		
	.get '/exec/*',
		run (request, response)->
			log "command:", [path, command] = app.getcommandpath request.params[0]
			[stdout, stderr] = yield app.exec path, command
			response.json [stdout, stderr]
		#, 'exec'
	
	.get '/run/*/*',
		(request, response)->
			log "path: ", path = app.resolvepath [request.params[0]]
			log "command: " + command = request.params[1]
			response.json app.run path, command
	
	.listen(process.argv[3] || 8090)

(io.listen process.argv[4] || 9000).on 'connection', (connection)->
	# find the process the socket wants to receive
	pid = connection.handshake.query.pid
	app.connect connection, pid
