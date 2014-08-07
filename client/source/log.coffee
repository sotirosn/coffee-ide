class Log extends ide.html
	class Message extends ide.html
		@html '<pre></pre>'
		constructor:(text)->
			super()
			@element.innerHTML = text
	
	class ErrorMessage extends ide.html
		@html '<pre class="error"></pre>'
		constructor:(text)->
			super()
			@element.innerHTML = text
	
	@html '<log></log>'
	
	focus:->
		
	show:->
		@element.innerHTML = ''
		app.rightpane.addTab @tab
		
	error:(exception)->
		console.error exception
	
	stdout:(text)->
		@element.appendChild (new Message text).element
		
	stderr:(text)->
		@element.appendChild (new ErrorMessage text).element
		
	