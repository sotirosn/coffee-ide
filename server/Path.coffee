log = console.log.bind console
({run, fs, WaitAll} = require './Routine').debug = false

class Path
	# intialization signals
	{@wait, @all} = new WaitAll
	
	@properties:(properties)->
		Object.defineProperties @prototype, properties	

	@commands:->
		# inherit and extend base class commands
		@prototype.commands = Object.create(@__super__?.commands || null)
		for key in arguments
			@prototype.commands[key] = @prototype[key]

	@properties
		path:
			set:(@_path)->
			get:-> return if @parent then "#{@parent.path}/#{@_path}" else @_path

	constructor:({@path, @dirmap, commands})->
		log "new path -> #{@path}"
		@dirmap ?= {}
		
	call:(commandName, path, data)->
		log "call: #{@constructor.name} [#{@path}] ->", arguments...
		
		# call command string with path string (join '/')
		command = @commands[commandName]
		throw new Error "invalid command: '#{commandName}' for: #{@constructor.name} [#{@path}]" unless command
		
		command.call @, path, data

	process:(command, path, data)->
		log "#{@constructor.name} [#{@path}] process path:", arguments...
		# process command string and path array (split '/')
		while path[0] == '.'
			path.splice(0, 1)

		# no more path, process the command at this point
		if path.length == 0
			return @call command, '.', data

		# look for a target to process the path
		else
			target = @dirmap[path[0]]

			if target
				# target is found, process remainder of the path
				path.splice(0, 1)
				return target.process command, path, data
			else
				# no target, process the path with 'this command'
				return @call command, (path.join '/'), data

class Directory extends Path
	type: 'folder'

	timezone = -6 * 60 * 60 * 1000
	@properties
		timestamp:get:->
			new Date(new Date()-timezone).toISOString().replace(/T/, ' ').replace(/[.].+$/, '') + ' MDT'

		parent: # refresh directories when we know where we are
			set:(@_parent)->
				log "set parent ->", @path
				@constructor.wait @refresh()
				for path, object of @dirmap
					log "\t#{@path}/#{path}"
					object.parent = @
			get:-> @_parent

	constructor:({@dirmap, @isVirtual})->
		super
		@directory = {}

	read:(path)->
		fs.read "#{@path}/#{path}"

	write:(path, data)->
		yield fs.write "#{@path}/#{path}", data
		"#{@timestamp}: wrote -> '#{@path}/{path}'"

	typeFilter:(stat)->
		return if stat.isDirectory() then 'folder'
		else if stat.isFile() then 'file'

	list:(path = '.')->
		log "list #{@path}/#{path}"
		if path != '.'
			yield fs.list "#{@path}/#{path}", @typeFilter
		else
			@directory

	refresh:->
		unless @isVirtual
			@directory = yield fs.list @path, @typeFilter

		for path, object of @dirmap
			@directory[path] = object.type || object || undefined
	
		log @directory

		#@directory
		"refreshed -> #{@path}"

	@commands 'read', 'write', 'list', 'refresh'

class SourceFolder extends Directory
	coffee = require 'coffee-script'
	
	constructor:({@targetdir})->
		super
	
	compile:(path, data)->
		log 'compiling', data
		# compile and write data to target dir
		log script = coffee.compile data, bare:true

		targetpath = "#{@path}/#{@targetdir}/#{path}.js"
		yield fs.write targetpath, script
		"/n#{@timestamp}: compiled -> #{targetpath}"

	write:(path, data)->
		# yield super write
		result = yield super
		result + (yield @compile path, data)

	@commands 'write'

class User extends Directory
	{createHash} = require 'crypto'

	constructor:({@password})->
		super
		@parent = null
		@processess = {}

	authenticate:(password)->
		sha1 = createHash('sha1')
		sha1.update password
		@password == sha1.digest 'base64'

class Project extends SourceFolder
	type: 'project'

	constructor:->
		super
		@targetdir ?= '.'

	write:(path, data)->
		return if path.match '[.]coffee$'
			# write .coffee files as source files
			yield super
		else
			# write all other files as directory files
			yield Directory.prototype.write.call @, path, data

	read:(path)->
		# check for '.client.coffee.js' in directory, if does not exist generate some js
		if path == '.client.coffee.js' && !@directory['.client.coffee.js']
			"ide.project" # <- this is actually javascript, (will be evaled by client as 'new ide.project')
		
		# otherwise read like any other file
		else
			yield super

	@commands 'read', 'write'

module.exports = { Path, User, Directory, Project, SourceFolder }

### ================= test =============== ##
log '\npath class definitions complete\n'
users =
	developer: new User
		password: 'wiMjJIhnOtz3jeh7YfcZUgga6l4='
		path: '/Users/Nick/coffee-ide'
		dirmap: 
			project: new Directory
				path: '.'
			client: new Directory
				path: 'newclient'
				dirmap:
					source: new SourceFolder
						path: 'source'
						targetdir: '../lib'

log '\npath object instantiation complete\n'

print = console.dir.bind console
run do ->
	users.developer.parent = null
	yield Path.all
	log '\npath intialialization complete\n'
	
	user = users.developer
	#print if user.authenticate '$masterDev' then 'user authenticated'
	#print (yield user.process 'list', 'client/source'.split '/')
	#print (yield user.process 'read', 'client/source/base.coffee'.split '/')
	#try
	print (yield user.process 'write', 'client/source/test.coffee'.split('/'), 'test text')
	#catch exception
	#	log "Syntax Error: #{exception.message}"


	#print (yield user.process 'refresh', 'client/source'.split '/')
	'test routine complete'
###

