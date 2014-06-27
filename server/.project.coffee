(project)->
	###
	build = 
		log: new editor.log('server build.log')
		icon: project.addIcon('build', (wait)->
			#yield setTimeout (-> wait()), 0
			command = project.directory.path + '/build'
			try [stdout, stderr] = yield (http.get 'exec/' + command) wait
			catch exception
				build.icon.error exception
				build.log.stderr exception
			
			build.log.open "output: exec #{command}"
			build.log.stdout stdout
			build.log.stderr stderr
		)
	
	run =
		connection: null
		log: new editor.log('run server')
		icon: project.addIcon('run', (wait)->
			#yield setTimeout (-> wait()), 0
			command = '/run 8081 8091 9001'
			
			# attempt to run command on the server
			try pid = yield (http.get 'run/' + command) wait
			catch exception
				return run.icon.error exception
			
			# kill previous connection and process (if any)
			if run.connection
				run.connection.disconnect()
			
			# log output via websocket
			run.log.open "(#{pid}) output: run #{command}"
			run.connection = new io.connect "ws://localhost:9000?pid=#{pid}", forceNew: true
			run.connection.on 'stdout', (stdout)->
				run.log.stdout stdout
			run.connection.on 'stderr', (stderr)->
				run.log.stderr stderr
			run.connection.on 'close', (info)->
				run.log.info info
				server.isRunning = false
			run.connection.on 'disconnect', (event)->
				run.log.info "(#{pid}) #{event}"

			server.isRunning = true
			
			run.log.onclose = (wait)->
				build.socket.disconnect()
		)
	###