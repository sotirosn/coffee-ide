log = console.log.bind console
{Routine, Generator, routine} = require('./routine.coffee')
https = require('https')
server = require('express')
{unescape} = require('querystring')
#ws = require 'ws'

class App
	fs:require('fs')
	pm:require('child_process')
	express:require('express')
	
	#===================== public methods =====================
	
	constructor:(@configpath)->
		@processes = []
		
		# read in parameters from json config file
		log @config = JSON.parse @fs.readFileSync configpath, encoding:'utf8'
		{@sessions, @password, @directories} = @config
		
		# change working directory if provided
		process.chdir @config.projectdir

		# start secure server
		@application = @express()
		https.createServer
			cert: @fs.readFileSync 'server.cert'
			key: @fs.readFileSync 'server.key'
			@application
		.listen @applicationPort, =>
			log "appserver server started on port: #{@config.applicationPort}"
		
		# start client web sever
		@client = @express()
		@client.listen @clientPort, =>
			log "webserver started on port: #{@config.clientPort}"
		
		# start websocket server
		#@io = new ws.Server port:@config.ioPort
		#@io.on 'connection', (connection)->
		#	log connection
		#	connection.on 'message', (message)->
		#@io.on 'listen', ->
		#	log "ioserver started on port: #{@config.ioPort}"
		
	saveconfig:->
		
	error:(response)->
		(exception)->
			response.send 500, "#{exception}"
			console.error exception.stack
	
	run:(iterator)->
		return if iterator instanceof Generator
			(request, response, error)=>
				routine = new Routine (iterator.call @, arguments...), @error(response)
				routine.next()
		else
			(request, response, error)=>
				try iterator.call @, arguments...
				catch exception then @error(response) exception	
	
	#===================== private methods =====================
	
	authorize:(request)->
		id = request.cookies['sessionID']
		#if !@sessions[id]?
		#	throw 'Unauthorized access. Please login.'
		#@sessions[id] # return the session
	
	guid:->
		'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, ($0)->
			random = Math.random()*16|0
			result = if $0 == 'x' then random else random&0x3|0x8
			result.toString(16)
	
	setPassword:(password)->
		@account.password = password
		@saveconfig()
	
	class Path
		constructor:(@directory, @filename)->
		toString:-> "#{@directory}/#{@filename}"
	
	parsePath:(path)->
		path = path.replace /^[.][/]/, ''
		
		result = null
		path.replace /([^/]+)[/]?(.*)/, ($0, dirname, filename)=>
			if (directory = @directories[dirname])?
				result = new Path directory, filename
			else
				throw "Unknown directory: #{dirname}"
		result
	
	parseCookies:(cookie)->
		return {} if !cookie
		
		result = {}
		for entry in cookie.split ';'
			[name, value] = entry.split '='
			result[name] = value
		result
	
	getPostData:(request)->
		(routine)->
			data = ''
			request.on 'data', (chunck)->
				data += chunck
				if data.length > 1e6
					request.connection.close()
					routine.throw 'Post data size exceeded!'
			request.on 'end', ->
				routine.next data
	
	writefile:(path, data)->
		(routine)=>
			@fs.writeFile path, data, (error)->
				return routine.throw error if error
				routine.next()
	
	readfile:(path, data)->
		(routine)=>
			@fs.readFile path, encoding:'utf8', (error, data)->
				return routine.throw error if error
				routine.next data
	
	listdir:(path)->
		(routine)=>
			@fs.readdir path, (error, data)->
				return routine.throw error if error
				routine.next data

	stat:(path)->
		(routine)=>
			@fs.stat path, (error, data)->
				return routine.throw error if error
				routine.next data
	
	mkdir:(path)->
		(routine)=>
			@fs.mkdir path, (error)->
				console.log error
				return routine.throw error if error
				routine.next()
	
	rename:(path, name)->
		(routine)=>
			@fs.rename path, name, (error)->
				console.log error
				return routine.throw error if error
				routine.next()
				
	exec:(command)->
		(routine)=>
			@pm.exec command, (error, stdout, stderr)->
				return routine.throw error if error
				routine.next [stdout, stderr]
	
	spawn:(path, command)->
		(routine)=>
			child = @pm.spawn 'cmd', ['/C', "cd #{path} && #{command}"]
			@processes[child.pid] = child
			log "(#{child.pid}): cd #{path} && #{command}"
			return child.pid
	
	start:(iterator)->
		(routine)=> (new Routine (iterator.call @), routine.onerror, routine).next()
	
	delete:(path)->
		@start ->
			log "deleting #{path}..."
			
			# determine if the path is a file or directory
			file = yield @stat path

			# if it is a directory, first delete everything in it
			return if file.isDirectory()
				filelist = yield @listdir path
				for filename in filelist
					# wait for recursive routine call
					yield @delete "#{path}/#{filename}"

				# now delete the folder itself -> ends recursion
				(routine)=> 
					log "deleting directory #{path}" 
					@fs.rmdir path, (error)->
						return routine.throw error if error
						routine.next()

			# otherwise just delete the file -> ends recursion
			(routine)=> 
				log "deleting file #{path}" 
				@fs.unlink path, (error)->
					return routine.throw error if error
					routine.next()

app = new App('.project.json')
log process.cwd()

clientdir = '/Users/Games/Documents/GitHub/coffee-ide/client'
codemirrordir = '/Users/Games/Documents/GitHub/CodeMirror'
app.client
	.get '/', (request, response)->
		response.sendfile "#{clientdir}/index.html"
	.get '/codemirror/*', (request, response)->
		response.sendfile "#{codemirrordir}/#{request.params[0]}"
	.get '/*', (request, response)->
		response.sendfile "#{clientdir}/#{request.params[0]}"
		
app.application
	.use app.run (request, response, next)->
		log request.url

		request.cookies = @parseCookies request.headers.cookie
		response.set('Access-Control-Allow-Origin', "http://localhost:#{@clientPort}")
		response.set('Access-Control-Allow-Credentials', true)
		next()
	
	.post '/login',
		app.run (request, response)->
			data = yield @getPostData request
			
			authorized = false
			data.replace /password=(.*)/, ($0, password)=>
				unescape password, @password
				authorized = (@password == unescape password)
			
			if !authorized
				throw "Incorrect password. (#{@password})"
			
			# if authorized, generate a new session id, and send it back as a cookie and a json string
			@sessions[id = @guid()] = true
			response.writeHead 200,
				'Set-Cookie': "sessionID=#{id}; path=/"
				'Content-Type': 'application/json'
			response.end JSON.stringify id

	.get '/logout',
		app.run (request, response)->
			if (id = request.cookies['sessionID'])?
				delete @sessions[id]	
			response.writeHead 200,
				'Set-Cookie': "sessionID=#{id}; path=/"
				'Content-Type': 'application/json'
			response.end JSON.stringify 'ok'
	
	.get '/projectlist', 
		app.run (request, response)->
			log "here"
			
			@authorize request
			response.json Object.keys @directories
	
	.post '/writefile/*', 
		app.run (request, response)->
			@authorize request
			
			path = @parsePath request.params[0]
			data = yield @getPostData request
			yield @writefile "#{path}", data
			try
				result = yield @exec "cd #{path.directory} && cake -f #{path.filename} onwrite"
				response.json result
			catch exception
				console.error "post write action failed: #{exception}"
				response.json ["file written", "post-write action failed: #{exception}"]
				
	.get '/readdata/*', 
		app.run (request, response)->
			@authorize request
			
			path = @parsePath request.params[0]
			data = yield @readfile "#{path}"
			response.json data
			
	.get '/readfile/*', 
		app.run (request, response)->
			@authorize request
			
			log path = @parsePath request.params[0]
			response.sendfile "#{path}", hidden:true	
			
	.get '/listdir/*',
		app.run (request, response)->
			@authorize request
			
			# get the contents of the directory as a list of filenames
			path = @parsePath request.params[0]
			filelist = yield @listdir "#{path}"
			
			# for each filename, check if it is a directory or file
			results = {}
			for filename in filelist
				filestats = yield @stat "#{path}/#{filename}"
				if filestats.isDirectory()
					results[filename] = 'dir'
				else if filestats.isFile()
					results[filename] = 'file'
			
			# send back a map of name -> type
			response.json results
	
	.post '/upload/*',
		app.run (request, response)->
			@authorize request
			
			path = @parsePath request.params[0]
			
			size = 0
			total = request.headers['content-length']
			request.pipe @fs.createWriteStream "#{path.directory}/uploads/#{path.filename}"

	.get '/rename/*',
		app.run (request, response)->
			@authorize request
			
			oldpath = (@parsePath request.params[0]).toString()
			newpath = (@parsePath request.query.newpath).toString()
			
			log "renamed: #{oldpath} -> #{newpath}"
			yield @rename oldpath, newpath
			response.json 'ok'
	
	.get '/mkdir/*',
		app.run (request, response)->
			@authorize request
			path = (@parsePath request.params[0]).toString()
			
			log "new directory: #{path}"
			yield @mkdir path
			response.json 'ok'
			
	.get '/delete/*',
		app.run (request, response)->
			@authorize request
			
			path = (@parsePath request.params[0]).toString()
			yield @delete path
			response.json 'ok'
	
	.get '/run/*',
		app.run (request, response)->
			@authorize request
			
			{directory, filename} = (@parsePath request.params[0])
			response.json (yield @spawn directory, filename)
			
process.on 'SIGINT', ->
	app.saveconfig()
	process.exit()

