log = console.log.bind console

class Application
	WebSocketServer = require('websocket').server
	express = require 'express'
	https = require 'https'
	http = require 'http'
	express: express
	{exec} = require 'child_process'

	({start, run, fs, pm, WaitAll} = require './Routine').debug = false
	{unescape} = require('querystring')

	fs:fs
	processes: {}

	guid = ->
		'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, ($0)->
			random = Math.random()*16|0
			result = if $0 == 'x' then random else random&0x3|0x8
			result.toString(16)

	route:(generator)->
		# wrap the generator function in a bind/initialization function
		if generator.isGenerator()
			return (request, response) =>
				start (generator.call @, arguments...), (error, data)->
					if error
						{name, message, stack} = error
						console.error stack
						response.writeHead 500, 
							'Content-Type': 'application/json'
						response.end JSON.stringify {name, message}
					else
						response.json data

		# not actually a generator function, just a function, so bind it
		generator.bind @

	constructor:->
		# create these now so they are available asynchrously
		@webserver = express()
		@appserver = express()
		@sessions = {}

		# further perform async initialization
		run @initialize arguments...

	initialize:(@configpath = '.config.json')->
		@config = JSON.parse (yield fs.read @configpath)

		process.chdir @config.rootdir
		log process.cwd()

		# starting client web server
		https.createServer(
			cert: yield fs.read @config.appserver.cert
			key: yield fs.read @config.appserver.key
			@webserver
		).listen @config.webserver.port, =>
			log "webserver listening on port: #{@config.webserver.port}"

		# starting secure app server
		server = https.createServer(
			cert: yield fs.read @config.appserver.cert
			key: yield fs.read @config.appserver.key
			@appserver
		).listen @config.appserver.port, =>
			log "appserver listening on port: #{@config.appserver.port}"

		# starting io server
		ws = new WebSocketServer
			httpServer: server, 
			autoAcceptConnections: false
		
		ws.on 'request', (request)=>
			try
				{httpRequest, socket} = request
				user = @authorize request 
				[_, pid] = httpRequest.url.match /[?]pid=([^&]*)/
				
				log 'connecting to ' + pid
				childProcess = @processes[pid]
				throw new @ReqeustError 'invalid pid' unless process

				socket = request.accept()
				socket.on 'close', =>
					# kill the process if it is still running
					if @processes[pid]
						exec "kill -TERM -#{pid}", (error, stdout, stderr)->
							if error then console.error error
					log "connection (#{pid}) closed"

				childProcess.stdout.on 'data', (data)->
					socket.send JSON.stringify { type:'stdout', data:data.toString() }
				childProcess.stderr.on 'data', (data)->
					socket.send JSON.stringify { type:'stderr', data:data.toString() }
				childProcess.on 'exit', (exitcode)->
					# in case process was not terminated from socket closure, close socket now
					socket.close()

			catch exception
				{name, message, stack} = exception
				console.error stack
				socket.write JSON.stringify {name, message}

	class @AuthenticationError extends Error
		name: 'AuthenticationError'

	class @RequestError extends Error
		name: 'RequestError'

	authenticate:(data)->
		# parse username and password from data string
		match = (unescape data).match /username=(.+)&password=(.+)/
		
		unless match
			throw new Application.RequestError 'invalid data format'

		[_, username, password] = match
		
		# lookup user from username and check password
		user = @users[username]
		unless user && user.password == password
			throw new Application.AuthenticationError 'invalid username and password'
		log "authenticated user: '#{username}'"

		# generate a new session id, save user's session
		sessionID = guid()
		@sessions[sessionID] = user
		[sessionID, user]

	authorize:(request)->
		user = @users.developer
		#user = @sessions[request.cookies['sessionID']]
		throw new Application.AuthenticationError 'invalid user session' unless user
		user

	users: {}

	# call 'data = yield request.getData()' to yield for request data collection
	http.IncomingMessage.prototype.getData = ->
		(routine)=>
			data = ''
			@on 'data', (chunck)->
				data += chunck
				if data.length > 1e6
					@connection.close()
					routine new Error 'Posted data is too large. (exceeds 1MB)'
			@on 'end', ->
				routine undefined, data

	Object.defineProperty http.IncomingMessage.prototype, 'cookies',
		get:-> 
			return @_cookies if @_cookies
			
			@_cookies = {}
			for entry in cookie.split ';'
				[name, value] = entry.split '='
				@_cookies[name] = value
			@_cookies	

	Object.defineProperty http.OutgoingMessage.prototype, 'cookies',
		set:(cookies)-> 
			cookie = ''
			for key, value of cookies
				cookie += "#{key}=#{value};"
			@set 'Set-Cookie', cookie
	
	http.OutgoingMessage.prototype.error = (error)->
		@writeHead 500,
			'Content-Type': 'application/json'
		@end JSON.stringify {name:error.name, message:error.message}

	@create:->
		app = new @ arguments...

		# setup webserver to server static client files
		app.webserver
			# log webserver requests
			.use (request, response, next)->
				log "web #{request.method} #{request.url}"
				next()

			# redirect root urls to index.html
			.get '/', app.route (request, response)->
				response.sendfile "#{@config.clientdir}/index.html"

			# custom js to link the location of the appserver
			.get '/init.js', app.route (request, response)->
				response.set 'Content-Type', 'text/javascript'
				response.end """
					http = new Http("https://localhost:#{@config.appserver.port}")
				"""

			# static client files
			.get '/*', app.route (request, response)->
				response.sendfile "#{@config.clientdir}/#{request.params[0]}"

		# setup appserver to process user commands
		app.appserver
			# for every request: parse cookies, allow access from webserver
			.use app.route (request, response, next)->
				log "app #{request.method} #{request.url}"
				response.set('Access-Control-Allow-Origin', "https://localhost:#{@config.webserver.port}")
				response.set('Access-Control-Allow-Credentials', true)
				next()

			# get root url to get user project list
			.get '/', app.route (request, response)->
				log 'here'
				user = @authorize request
				yield user.list()
			
			# post login data to root url to sign in and get user project list
			.post '/', app.route (request, response)->
				user = @authenticate request
				yield user.list()

			# route command to user process
			.get '/:command/*', app.route (request, response)->
				user = @authorize request
				yield user.process request.params.command, request.params[0].split('/')

			# route command and post data to user process
			.post '/:command/*', app.route (request, response)->
				user = @authorize request
				data = yield request.getData()
				yield user.process request.params.command, request.params[0].split('/'), data
		app

module.exports = Application
