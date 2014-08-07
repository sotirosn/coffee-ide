class extends ide.project
	siteUrl: 'https://localhost:9080/?'

	constructor:->
		log 'new client project'
		super

		@addButton 'view', =>
			yield @saveAll()
			if @view? then @view.refresh()
			else
				@view = new ide.view @siteUrl
				@view.tab = app.rightpane.createTab @name, @view, =>
					delete @view

		@addButton 'update', =>
			yield @saveAll()
			[stdout, stderr] = yield http.get "#update/{@path}"
			@log stdout, stderr

	log:(stdout, stderr)->
		console.log "#{@name}/> #{stdout}" if stdout
		console.error "#{@name}/> #{stderr}" if stderr
