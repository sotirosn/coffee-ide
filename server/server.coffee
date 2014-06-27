Generator = (-> yield null).constructor
log = console.log.bind console
#pm = require('child_process')
fs = require('fs')
#coffee = require('coffee-script')
#https = require('https').createServer {
#	key: fs.readFileSync('server.key')
#	cert: fs.readFileSync('server.cert')
#}
express = require('express')
#multiparty = require('multiparty')
  
class Routine
	constructor:(iterator, args...)->
		@iterator = new iterator(this, args...)
		@iterator.next() if iterator instanceof Generator
		
	resume:(value)-> 
	   	@iterator.next value

class Utility extends Routine
	constructor:(routine, @request, @response, @exit)->
		super(routine, request, response, exit)
	
	# file system helpers
	listdir:(dirname = '.')->
		fs.readdir dirname, (error, filelist)=>
			if error then @exit error else @resume filelist
	
	checkfile:(filename)->
		fs.exists filename, (exists)=>
			@resume exists
	
	statfile:(filename)->
		fs.exists filename, (exists)=>
			if !exists then @resume (null)
			else
				fs.stat filename, (error, fileinfo)=>
					if error then @exit error else @resume fileinfo
	
	writefile:(filename, value)->
		fs.writeFile filename, value, (error)=>
			if error then @exit error else @resume()
		
	readfile:(filename)->
		fs.readFile filename, 'utf8', (error, text)=>
			if error then @exit error else @resume text

	# request helpers
	streamfile:(filename)->
    	log @request.headers
		@resume(null)
		####
        ###
		form = new multiparty.Form
		form.parse @request, (error, fields, files)=>
			log "here"
			log error, fields, files
			@resume()
		###
		
		###
		#@request.setBodyEncoding("binary")
		stream = new multiparty.Stream(@request)
		data = ''
		
		stream.on 'part', (part)=>
			log part
			part.on 'body', (chunk)=>
				log 'uploaded ' + (stream.bytesReceived/stream.bytesTotal*100).toFixed(2) + '%'
				fs.writeFile filename, chunk, flag:'a', (error)=>
					@exit error
		
		stream.on 'complete', =>
			@resume stream
		####
        ###
	prefetchdata:->
		@prefetching = (true)
		@request.on 'data', (chunk)=>
		   	data += chunk
			if data.length > 1e6
				@request.connection.destroy()
				@exit 'too much data received'

		@request.on 'end', =>
			log "data:", @data, data
		
			# @data doubles as a signal to notify request on end that we are waiting for it
			if !@data then @data = data else @resume data
			
	getprefetcheddata:->
		throw "you must first call prefetchdata() to load callbacks." if !@prefetching
		
		# @data doubles as a signal to notify request on end that we are waiting for it
		if @data then @data else @data = 1

	getdata:(limit = 1e6)->
		data = ''
		
		@request.on 'data', (chunk)=>
		   	data += chunk
			if data.length > limit
				@request.connection.destroy()
				@exit 'too much data received'

		@request.on 'end', =>
			log "data:", data
			@resume data
		
	respond:(contentType, data)->
		@response.writeHead 200, 'Content-type':contentType
		@response.end data, 'utf8'  
		
route = (routine)->
	(args...)->
		new Utility(routine, args...)

# this server, serves both requested files and user commands
# client path is the path to index.html, .css and .js files loaded by the browser
# project path is the location the user desires to work in
# set the project path to the client path to edit this application itself
clientpath = '/Users/Games/Documents/GitHub/Coffee IDE/client/'
projectpath = '/Users/Games/Documents/GitHub/Coffee IDE/site/'

# serve index.html on root requests
express.get '/', route (utility)->
	html = yield utility.readfile clientpath + 'index.html'
	html = html.replace(/{version}/g, process.versions.node)
	utility.respond 'text/html', html

express.get '/site/*', (request, response)->
	response.sendfile projectpath + request.params[0]

express.post '/site/uploadphoto', route (utility, request, response, exit)->
	log (yield utility.streamfile 'testfile')
	response.redirect('back')
	
express.get '/codemirror/*', (request, response)->
	response.sendfile '/Users/Games/Documents/GitHub/CodeMirror/' + request.params[0]
	
# (*.coffee.js) compiled on-demand
express.get /(\w+)\.coffee\.js$/, route (utility, request)->
	filename = request.params[0]
	sourcename = clientpath + filename + '.coffee'
	targetname = clientpath + filename + '.coffee.js'
	
	targetinfo = yield utility.statfile targetname
	if targetinfo?
		sourceinfo = yield utility.statfile sourcename
	
	# in the case that the target already exists, compare timestamps
	if !targetinfo || targetinfo.mtime < sourceinfo.mtime
		log "compiling #{targetname}"
		source = yield utility.readfile sourcename
		
		# try to compile the target, catch parse errors
		try target = coffee.compile source, bare:1
		catch error then return utility.exit error
		
		# compilation was successful, write output file
		yield utility.writefile targetname, target
		
	# otherwise no need to recompile but the target is then not yet buffered
	else
		target = yield utility.readfile targetname
	
	# return the compiled javascript to the client
	utility.respond 'text/javascript', target

express.get '/readdir', route (utility, request, response, exit)->
	filelist = yield utility.listdir request.query.path
	response.json filelist

express.get '/readfile', route (utility, request, response)->
	filepath = request.query.filepath
	data = yield utility.readfile filepath
	response.json data

express.post '/writefile', route (utility, request, response)->
	filepath = request.query.filepath
	
	# get the request data
	data = yield utility.getdata()
	
	# write the data to the file
	yield utility.writefile filepath, data
	
	# notify the client that the file was saved
	log new Date().toISOString() + ': ' + filepath + ' saved.'
	response.json 'Ok'
	
shells = {}

#bash = '/Users/Games/Downloads/shell.w32-ix86/bash '
express.post '/command', route (utility, request, response, exit)->
	# prepare commandline and environment of new process
	commandline = yield utility.getdata(256)
	environment = merge process.env, request.query
	
	#log process.env.comspec, ['/c', commandline], {env:process.env}
	child = pm.exec commandline,
		env: environment 
		stdio: 'pipe' 
	
	#child = pm.spawn 'cmd.exe', ['/c', commandline], 
	#    detached: true
	#    env: environment 
	#    stdio: 'inherit' 
	
	#child = cp.exec commandline, {env:environment}, (error)->
	#    console.error error if error
		
	if child
		log "(#{child.pid}): #{commandline}"
		shells[child.pid] = child
		child.kill = ->
			log "taskkill /T /PID #{@pid} /f"
			pm.exec "taskkill /T /PID #{@pid} /f"
			
		response.json {pid:child.pid}
	else
		exit "unable to execute command"

express.get '/kill', route (utility, request, response, exit)->
	pid = request.query.pid;
	
	if shells[pid]
		shells[pid].kill()
		delete shells[pid]
		response.json 'ok'
	else
	   return exit "pid not found (#{request.query.pid})"
	
# listen for reqeusts
#http.listen(port = process.env.port || 8080)
https.listen(port = process.env.port || 8081)
log "starting server on port #{port}"

process.on 'exit', ->
	for child in shells
		child.exit()

####