class extends ide.project
	siteUrl: 'https://localhost:8080/?'

	constructor:->
		log 'new client project'
		super

		@addButton 'run', =>
			yield @saveAll()
			@connection?.close()
			
			if @log then @log.show()
			else
				@log = new Log
				@log.tab = app.rightpane.createTab 'server', @log, =>
					@connection?.close()
					delete @connection
				
			
				
			
			try
				pid = yield http.get "run/#{@path}"
				@connection = yield http.connect '.', {pid}
				@log.stdout "connection opened (#{pid})"
			catch exception
				@log.error exception
				
			@connection.onmessage = ({data})=>
				{type, text} = JSON.parse data
				switch type
					when 'stdout' then @log.stdout text
					when 'stderr' then @log.stderr text
			@connection.onclose = (event)=>
				@log.stdout "connection closed (#{pid})"
				delete @connection
				
			
		@addButton 'update', =>
			yield @saveAll()
			[stdout, stderr] = yield http.get "update/#{@path}"
			@log stdout, stderr
