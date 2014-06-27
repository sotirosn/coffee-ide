Object.defineProperties Array.prototype,
	last:get:-> if @length > 0 then @[@length-1] else undefined
	remove:value:(value)-> @splice (@indexOf value), 1
	
clone = (object)->
	result = {}
	for key, value of result
		if (typeof value) == 'object'
			result[key] = clone(value)
		else
			result[key] = value
	result

class html
	constructor:(tagname, innerHTML = '', @querySelectors = {})->
		@element = document.createElement tagname
		@element.innerHTML = innerHTML
		@html = {}
		for key, query of @querySelectors
			@html[key] = @element.querySelector query
	
	clone:(element)->
		element ?= @element.cloneNode true
		html = {}
		for key, query of @querySelectors
			html[key] = element.querySelector query
		{html, element}

class html.element
	@properties:(properties)->
		Object.defineProperties @prototype, properties
	
	bind:(method)->
		method.bind @
	
	html: new html 'element'
	
	run:(method)->
		if method instanceof Generator
			(args...)=>
				run method.call @, args...
		else
			(args...)=>
				method.call @, args...
		
	onclick:(method)->
		if method instanceof Generator
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				run "onclick", (method.call @, event)
		else
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				method.call @, event
	
	constructor:(element)->
		{@html, @element} = @html.clone(element || @element)
		
	show:->
		@element.removeAttribute 'hidden'
		
	hide:->
		@element.setAttribute 'hidden', true

class html.iframe extends html.element
	html: new html 'iframe'
	
	@properties
		label:set:(value)->
			@tab.label = value
			
	constructor:(@location)->
		super()
		@element.src = location
		@element.onload = =>
			log "loaded: ", @label = @element.contentDocument.title || location
			
	reload:->
		@element.src = @location

class html.icon extends html.element
	html: new html 'icon'
	constructor:(label, onclick)->
		super()
		@element.innerHTML = label
		@element.onclick = onclick
		
	error:(exception)->
		@element.className = 'error'
		@element.title = exception
		
class html.contextmenu extends html.element
	html: new html('contextmenu', '<div></div>'
		div: 'div'
	)
	@properties
		x:set:(value)-> @element.style.left = value + 'px'
		y:set:(value)-> @element.style.top = value + 'px'
	
	constructor:->
		super arguments...
		@hide()
		@element.onmouseleave = @bind @hide
	
	addMenuItem:(label, onclick)->
		menuitem = new html.icon label, (=> onclick(@target))
		@html.div.appendChild menuitem.element
		menuitem
	
	display:(@target, event)->
		@x = event.clientX
		@y = event.clientY
		@show()
		event.preventDefault()
		event.stopPropagation()
		
class html.tab extends html.element
	html: new html('tab', '<label></label><close>x</close>',
		label: 'label'
		close: 'close'
	)
	@properties {
		label:set:(value)->@html.label.innerHTML = value
	}
	constructor:(label, @contents, @onclose)->
		super()
		@label = label
		@element.onclick = @onclick @focus
		@html.close.onclick = @onclick @close

	close:->
		yield run @onclose() if @onclose?
		@container.remove this
		
	focus:->
		@container.activate this
		@contents.focus()

class html.tabarea extends html.element
	html: new html('tabarea', '<tabs></tabs><contents></contents>',
		tabs: 'tabs'
		contents: 'contents'
	)
	constructor:(element)->
		super(element)
		@active = (null)
		@container = []
	
	createTab:(label, contents, onclose)->
		@add new html.tab label, contents, onclose
		
	add:(tab)->
		@container.push tab
		@html.tabs.appendChild tab.element
		@html.contents.appendChild tab.contents
		tab.container = this
		tab.focus()
		tab
		
	remove:(tab)->
		@container.splice (@container.indexOf tab), 1
		@html.tabs.removeChild tab.element
		@html.contents.removeChild tab.contents
		if @active == tab
			@active = (null)
			if @container.length > 0
				@container[0].focus()
			
	activate:(tab)->
		return if @active == tab
		if @active
			@active.element.removeAttribute('active')
			@active.contents.setAttribute('hidden', true)
		@active = tab
		@active.element.setAttribute('active', true)
		@active.contents.removeAttribute('hidden')

class html.log extends html.element
	@print:(args...)->
		result = ''
		for arg in args
			switch typeof arg
				when 'object'
					subresult = '{'
					subdelimeter = ''
					for key, value of arg
						subresult += "#{subdelimeter}<span class='key'>#{key}</span>: #{value}"
						subdelimeter = ', '
					subresult += '}'
				else
					subresult = arg + ' '
			result += subresult + ' '
		result

	class section extends html.element
		html: new html('div', '<span></span><div></div>',
			info: 'span'
			body: 'div'
		)
		constructor:(args...)->
			super()
			@html.info.innerHTML = html.log.print args...
			@html.info.onclick = @onclick @fold
			@isVisible = (true)

		fold:-> 
			if @isVisible
				@html.body.setAttribute 'hidden', (true)
				@isVisible = (false)
			else
				@html.body.removeAttribute 'hidden'
				@isVisible = (true)
		
		log:(html)->
			@html.body.innerHTML += html

	html: new html 'log'
	
	format:(format)->
		(args...) => 
			@log format args...
	
	start:(args...)->
		console.log @current
		if @current?.isVisible
			@current.fold()
		@current = new section(args...)
		@element.appendChild @current.element
	
	log:(args...)->
		@current.log "<p>#{html.log.print args...}</p>"
	
	error:(args...)->
		@current.log "<p class='error'>#{html.log.print args...}</p>"
	
	stdout:(message)->
		@current.log "<pre>#{message}</pre>"
	
	stderr:(message)->
		@current.log "<pre class='error'>#{message}</pre>"
		
	stdlog:([stdout, stderr])->
		@stdout stdout if stdout
		@stderr stderr if stderr
		
class html.toolbar extends html.element
	html: new html 'toolbar'		
	