class extends ide.project
	siteUrl: 'https://localhost:8080/?'

	constructor:->
		log 'new client project'
		super

		@addButton 'run', =>
			yield @saveAll()
			if @log then @log.show()
			else
				log 'new log'
				@log = new Log
				@log.tab = app.rightpane.createTab 'server', @log, =>
					@connection?.close()
					delete @connection

			try
				@connection?.close()
				
				pid = yield http.get "run/#{@path}"
				@connection = yield http.connect '.', {pid}
				@connection.onmessage = ({data})=>
					{type, data} = JSON.parse data
					switch type
						when 'stdout' then @log.stdout data
						when 'stderr' then @log.stderr data
				@connection.onclose = (event)=>
					log event
					@log.stdout "connection closed: #{event.data}"
					delete @connection
				
			catch exception
				@log.error exception
			
		@addButton 'update', =>
			yield @saveAll()
			[stdout, stderr] = yield http.get "update/#{@path}"
			@log stdout, stderr
