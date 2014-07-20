{app, fs, pm} = require './application'
coffee = require 'coffee-script'
crypt = require 'md5'
	
class Routine	
	# override this method in a derived class to implement async error handling
	onerror:(exception)->
		throw exception
	
	constructor:(@iterator, @onreturn)->
		
	next:(nextvalue)->
		try
			{done, value} = @iterator.next nextvalue
			if done
				@onreturn?.next value
			else
				if value.next?
					# subroutine -> resumed on completion
					routine = new Routine value, @
					routine.onerror = @onerror
					routine.next()
				else
					# async callback -> resumed from routine.next()
					value @
					
		catch exception
			@onerror exception

	throw:(exception)->
		try 
			@iterator.throw exception
		catch exception
			@onerror exception
			
	@run:(iterator, onerror)->
		routine = new Routine iterator
		routine.onerror = onerror if onerror
		routine.next()
		
run = Routine.run
	
class Directory
	constructor:(@path = '.', @onwrite)->

	writefile:
		(routine)->
			fs.writeFile , encoding:'utf8', data, (error)->
				return routine.throw error if error
				routine.next ["#{@path}/#{path} written.", ''] # expects [stdout, stderr]
		
	write:(path, data)->
		yield @writefile "#{@path}/#{path}", data 
			
		# secondary post-write action (if available)
		(yield @onwrite data) if @onwrite?
		

			
			

class User
	password: crypt('$secret')
	
	constructor:(@configpath)->
		(coffee.eval fs.readFileSync configpath) @ if configpath?
	
	directories:
		project: new Directory
	
	parsePath:(query)->
		# remove all ./ and /./ from path
		path = path.replace /^\.\//, ''
		path = path.replace /\/\.\//, '/'
		
		path = query.split '/'
		directory = @directories[path.splice(0, 1)]
		
		# check that there is actually a directory found
		throw new Error "invalid path: #{query}" if !directory?
		return [directory, path]

class Application extends require('./server')
	users:{}
	
	constructor:(configpath)->
		super configpath
		
		if @config?
			for username, userdata of @config.users
				@users[username] = new User userdata
		else
			@users.admin = new User

	
app.router
	.post '/login',
		app.run (request, response)->
			postdata = yield @getPostData request
			
			# parse the username and password parameters from the post data
			[match, username, password] = postdata.match 'username=(.+)&password=(.+)'
				
			# lookup and validate user by username and password
			user = @users[username]
			throw new Error 'invalid username and password' if !(user?.password == crypt password)
			
			# return the user
			user
	
	.post '/write/*',
		app.run (request, response)->
			# authorize the user based on request cookie
			user = @authorize request
			
			# parse out the directory and path by user
			[directory, path] = user.parsePath request.params[0]
			
			# collect data from the POST request
			data = yield @getPostData request
			
			# have the directory object write the data
			response.json (yield directory.write path, data)
