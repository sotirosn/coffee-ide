log = console.log.bind console

sourcedir = "../server"
	
{User, Directory, Project, SourceFolder} = require "#{sourcedir}/Path"
Application = require "#{sourcedir}/Application"

class ServerProject extends Project
	log {spawn, exec} = require 'child_process'
	
	switch process.platform
		when 'win32'
			ChildProcess = (spawn 'cmd').constructor
			ChildProcess.prototype.kill = ->
				log "child process (#{@pid}) terminated by user"
				exec "taskkill /F /T /PID #{@pid}", (error, stdout, stderr)->
					console.error error if error
			@prototype.spawn = (command, commandline)->
				spawn 'cmd', ['/K', command, commandline...]
		else
			ChildProcess = (spawn 'ls').constructor
			ChildProcess.prototype.kill = ->
				log "child process (#{@pid}) terminated by user"
				exec "kill -TERM -#{@pid}", (error, stdout, stderr)->
					console.error error if error
			@prototype.spawn = (command, commandline)->
				spawn command, commandline, detach:(true)

	constructor:->
		super
		@processes = app.processes

	run:->
		yield (routine)=>
			child = @spawn 'coffee', ['--nodejs', '--harmony_generators', 'project/server.coffee', 'run.config.json'], detached:(true)
			
			if pid = child.pid
				log "child process (#{pid}) started"
				@processes[pid] = child
				
				child.on 'exit', (exitcode)=>
					log "child process (#{pid}) exited with exit code: #{exitcode}"
					delete @processes[pid]
					
					if child.connection
						# close the associated websocket connection if it exists
						child.connection.close()
					else
						# if no connection was ever made, flush child output
						child.stdout.pipe process.stdout
						child.stderr.pipe process.stderr
				
				routine.next pid
			else
				log 'child process failed to execute'
				child.on 'error', (error)->
					routine.throw error

	@commands 'run'

app = Application.create(process.argv[2])
app.users =
	developer: new User
		password: '$masterDev'
		path: "#{__dirname}/.."
		isVirtual: true
		dirmap:
			project: new Project
				path: 'project'
			client: new Project
				path: 'client'
				dirmap:
					source: new SourceFolder
						path: 'source'
						targetdir: '../lib'

			server: new ServerProject
				path: 'server'
