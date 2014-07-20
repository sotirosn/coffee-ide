class ide.iframe extends ide.html
	@html '<iframe></iframe>'
	@properties
		label:set:(value)-> @tab?.label = value
		location:set:(value)-> @element.src = value
	
	open:(url)->
		@element.src = url
		(routine)=>
			@element.onload =>
				title = @element.querySelector('title')
				@label = title?.innerHTML || url
				routine.next()
				
	@create:(label)->
		iframe = new ide.iframe
		iframe.tab = app.rightpane.createTab label, iframe
		iframe
		
class ide.console extends ide.html
	class stdout extends ide.html
		@html '<pre class="stdout"></pre>'
		
		constructor:(text)->
			super()
			@element.innerHTML = text

	class stderr extends ide.html
		@html '<pre class="stderr"></pre>'
		
		constructor:(text)->
			super()
			@element.innerHTML = text
	
	@html '<console></console>'
	@properties
		label:set:(value)-> @tab?.label = value
	
	connect:(@pid)->
		# close old connection
		@connection?.close()
		
		# open new connection
		@connection = ws.open {@pid}
		
		# on sudden close, log info
		@connection.onclose = (event)=>
			log event
			@info "(#{@pid}) connection closed."
			delete @connection
			
		# on sudden error, log error	
		@connection.onerror = (event)->
			console.error event
		
		# on sudden message, route message
		@connection.onmessage = ({data})=>	
			for key, message of JSON.parse data
				switch key
					when stdout then @stdout message
					when stderr then @stderr message
					else @output "#{key}: #{message}"
		
		# wait for open
		(routine)->
			@connection.onopen = ->
				routine.next()
	
	output:(text)->
		element = document.createElement 'pre'
		element.innerHTML = text
		@element.appendChild element
	
	stdout:(text)->
		@element.appendChild (new stdout text).element
		
	stderr:(text)->
		@element.appendChild (new stderr text).element

	@create:(label)->
		console = new ide.console
		console.tab = app.rightpane.createTab label, console
		console