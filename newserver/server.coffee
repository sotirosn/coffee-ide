log = console.log.bind console
Generator = (-> yield undefined).constructor

class Routine
	@run:(iterator, onreturn = Routine.last)->
		resume = (error, data)->
			try
				{done, value} = 
					if error then iterator.throw error 
					else iterator.next data
		
				# if iterator finished, resume calling routine normally
				if done
					onreturn(undefined, value)
				# if iterator yielding for subroutine
				else if (typeof value?.next) == 'function'
					Routine.run value, resume 
				# if iterator yielding for an (error, data)-> async callback
				else if (typeof value) == 'function'
					value resume 
				# if iterator yielding for something unexpected
				else
					throw new TypeError 'Iterator expected to return a callback or iterator.'

			# uncaught routine exceptions bubble back up to calling routine
			catch exception
				onreturn exception

		# start the routine
		resume()

	@last:(error, value)->
		if error then throw error else value

class Routine.WaitAll
	count: 1 # start at 1 so self-locked until calling @all

	constructor:->
		# @resume may be passed into yielding iterator values multiple times
		@resume = @resume.bind @

		# wait, all bound for convinience ({wait, all} = new WaitAll)
		@wait = @wait.bind @
		@all = @all.bind @

	resume:(error, data)->
		if error
			@error = error # saves the last error which occured during wait, to send back the the caller
			console.error error.stack || error

		# releases locks set by @wait
		if --@count == 0
			# @error may be undefined if no errors occured
			@onreturn @error

	wait:(iterator)->
		++@count # sets locks released by @resume
		try
			if (typeof iterator.next) == 'function'
				Routine.run iterator, @resume
			else
				iterator @resume
		catch exception
			@resume exception
	
	all:(@onreturn)-> 
		@resume()

class Routine.fs
	WaitAll = Routine.WaitAll
	_fs = require 'fs'

	@listdir:(path)->
		(routine)-> _fs.readdir path, routine

	@readfile:(path)->
		(routine)-> _fs.readFile path, encoding:'utf8', routine

	@writefile:(path, data)->
		(routine)-> _fs.writeFile path, data, encoding:'utf8', routine

	@stat:(path)->
		(routine)-> _fs.stat path, routine

class Application
	express = require 'express'
	https = require 'https'
	http = require 'http'
	
	{run, fs, pm, WaitAll} = Routine
	{unescape} = require('querystring')

	guid = ->
		'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, ($0)->
			random = Math.random()*16|0
			result = if $0 == 'x' then random else random&0x3|0x8
			result.toString(16)

	route:(generator)->
		# wrap the generator function in a bind/initialization function
		if generator instanceof Generator
			return (request, response, next) => 
				run (generator.call @, arguments...), (error, data)->
					next error if error

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
		@config = JSON.parse (yield fs.readfile @configpath)
		process.chdir @config.rootdir
		console.log process.cwd()

		# starting client web server
		http.createServer(
			@webserver
		).listen @config.webserver.port, =>
			log "webserver listening on port: #{@config.webserver.port}"

		# starting secure app server
		https.createServer(
			cert: yield fs.readfile @config.appserver.cert
			key: yield fs.readfile @config.appserver.key
			@appserver
		).listen @config.appserver.port, =>
			log "appserver listening on port: #{@config.appserver.port}"

	parseCookies:(cookie)->
		result = {}
		return result unless cookie
		for entry in cookie.split ';'
			[name, value] = entry.split '='
			result[name] = value
		result

	class AuthenticationError extends Error
		name: 'AuthenticationError'
		constructor:(@message)->

	authenticate:(data)->
		[_, username, password] = (unescape data).match /username=(.+)&password=(.+)/
		user = @users[username]

		unless user?.password == password
			throw new AuthenticationError 'Invalid username and password.'
		log "authenticated user: '#{username}'"

		sessionID = guid()
		@sessions[sessionID] = user
		[sessionID, user]

	authorize:(request)->
		user = @users.developer
		#unless user = @sessions[request.cookies['sessionID']]
		#	throw new AuthenticationError 'Invalid session.'

		return user unless request.params[0]
		
		path = request.params[0].split '/'
		unless directory = user.directories[path.splice(0, 1)]
			throw new AuthenticationError 'User directory not found.' 
		[directory, path.join '/']

	class Directory
		constructor:({@path})->
		write:(path, data)->
			yield fs.writefile "#{@path}/#{path}", data
			"#{Date.now()}: wrote '#{@path}/#{path}'"

		read:(path)->
			fs.readfile "#{@path}/#{path}"

		@genericTypeFilter:(path)->
			stats = yield fs.stat path
			return 'dir' if stats.isDirectory()
			return 'file' if stats.isFile()
		@genericTypeFilter = @genericTypeFilter.bind @

		list:(path, filter = Directory.genericTypeFilter)->
			path = "#{@path}/#{path}"
			filelist = yield fs.listdir path
	
			{wait, all} = new WaitAll
			result = {}
			for filename in filelist
				wait ((key)-> result[key] = yield filter "#{path}/#{filename}") filename
			yield all
			result
		
	users:
		developer:
			password:'$masterDev'
			directories:
				'.project': new Directory 
					path: '.'
				'server': new Directory
					path: 'server'
				'client': new Directory
					path: 'client'
			list:-> @directories

	getPostData:(request)->
		data = ''
		(routine)->
			request.on 'data', (chunck)->
				data += chunck
				if data.length > 1e6
					request.connection.close()
					routine.throw new Error 'POST data is too large.'
			request.on 'end', ->
				routine.next data

app = new Application()

app.webserver
	.use (request, response, next)->
		log "#{request.method} #{request.url}"
		next()
	
	.get '/datasource.js', (request, response)->
		response.writeHead 200,
			'Content-Type': "text/javascript"	
		response.send """
			<script> http = new datasource.http 'http://localhost:#{app.config.appserver.port}'</script>
		"""

app.appserver
	.use app.route (request, resonse, next)->
		request.cookies = @parseCookies request.headers.cookie
		log "#{request.method} #{request.url}"
		next()

	.get '/index.html', app.route (request, response)->
		response.send '''
			<form action="/" method="POST">
				<label>username </label><input name="username"/><br/>
				<label>password </label><input name="password"/><br/>
				<button type="submit">sign in</button>
			</form>
		'''

	# post username/password to root url to login
	.post '/', app.route (request, response)->
		[sessionID, user] = @authenticate (yield @getPostData request)

		response.writeHead 200,
			'Set-Cookie': "sessionID=#{sessionID}; path=/"
			'Content-Type': "application/json"
		response.end JSON.stringify user.list()

	.get '/', app.route (request, response)->
		user = @authorize request
		response.json user.list()

	.get '/list/*', app.route (request, response)->
		log [directory, path] = @authorize request
		response.json (yield directory.list path)

	.get '/read/*', app.route (request, response)->
		[directory, path] = @authorize request
		response.send (yield directory.read path)

	.post '/write/*', app.route (request, response)->
		[directory, path] = @authorize request
		data = yield @getPostData request
		response.json (yield directory.write path, data)
		
	.get '/run/*', app.route (request, response)->
		[directory, path] = @authorize request
		response.json (yield directory.run path)

	