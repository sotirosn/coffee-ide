(project)->
	do ->
		log = new html.log 
		tab = null
		icon = project.addIcon 'build', ->
			tab ?= app.rightpane.createTab 'build:client', log.element
			
			log.start 'build:client'
			try 
				[stdout, stderr] = yield http.get "exec/#{@pathname} cake build:client"
			catch exception
				icon.error exception
				log.stderr exception
				return
			log.stdout stdout
			log.stderr stderr
	do ->
		icon = project.addIcon 'save', project.save