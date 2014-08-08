log = console.log.bind console

sourcedir = "/Users/Nick/coffee-ide/server"

{spawn} = require "child_process"
{User, Directory, Project, SourceFolder} = require "#{sourcedir}/Path"
Application = require "#{sourcedir}/Application"

class ServerProject extends Project
	processes:{}
	
	run:->
		yield (routine)=>
			child = spawn 'coffee', ['--nodejs', '--harmony_generators', 'server.coffee', 'devel.config.json'], detached:true
		
			if child.pid
				log "child process (#{child.pid}) started"
				
				app.processes[child.pid] = child

				child.on 'exit', (exitCode)=>
					log "child process exited with exit code: #{exitCode}"
					delete app.processes[child.pid]

				routine.next child.pid
			else
				log "child process failed to execute"
				child.on 'error', (error)->
					routine.throw error

	@commands 'run'

app = Application.create(process.argv[2])
app.users =
	developer: new User
		password: '$masterDev'
		path: '/Users/Nick/coffee-ide'
		isVirtual: true
		dirmap:
			project: new Project
				path: '.'
			client: new Project
				path: 'client'
				dirmap:
					source: new SourceFolder
						path: 'source'
						targetdir: '../lib'

			server: new ServerProject
				path: 'server'
