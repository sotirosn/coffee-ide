class ide
	constructor:(elements)->
		@hierarchy = new ide.hierarchy elements.hierarchy
		@toolbar = new ide.toolbar elements.toolbar
		@leftpane = new ide.tabarea elements.leftpane
		@rightpane = new ide.tabarea elements.rightpane
		@statusbar = new ide.statusbar elements.statusbar
	
class ide.html
	node = document.createElement 'div'
	
	@properties:(properties)->
		Object.defineProperties @prototype, properties
	
	@html:(html, @components = {})->
		node.innerHTML = html
		@element = node.firstChild
	
	@create:(element)->
		#log "new html element:", @element
		
		element ?= @element.cloneNode true
		
		if !element.innerHTML && @element.innerHTML
			element.innerHTML = @element.innerHTML
		
		# capture html components from element children
		html = {}
		for key, value of @components
			html[key] = element.querySelector value
		return {element, html}
		
	constructor:(element)->
		{@element, @html} = @constructor.create element
	hide:->
		@element.style.display = 'none'
	show:->
		@element.style.display = 'block'
	
	run:(iterator)->
		run iterator.call @
	
	onclick:(iterator)->
		if iterator instanceof Generator
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				run iterator.call @, event
				return false
		else
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				iterator.call @, event
				return false		
			
class ide.editor extends ide.html
	@html '<textarea></textarea>'
	
	constructor:(@file, value)->
		super()
		
		# subclasses may not wish to pass in a value if they handle it themselves
		@value = value if value?
		
	@properties
		value:
			set:(value)-> @element.value = value
			get:-> @element.value
	
		saving:
			set:(value)->
				@_saving = value
				@tab.label = @file.name + if value then '*' else ''
			get:-> @_saving
	
	autosaveDelay: 30000
	autosave:->
		# if not already scheduled, schedule a save
		@saving = setTimeout (=> run @save(true)), @autosaveDelay if !@saving
	
	save:(autosave = false)->
		# clear autosave if something other than the autosaver 
		# is requesting the save, (like tab closed)
		clearTimeout @saving if !autosave
			
		[stdout, stderr] = yield http.postdata "writefile/#{@file.path}", @value
		log stdout if stdout
		console.error stderr if stderr
		
		@saving = false
		
	close:->
		# save before closing
		(yield run @save()) if @saving
		@file.close() # the file element needs to know so it will open a new editor on edit

	focus:->
		@element.focus()
		
class TextEditor extends ide.editor
	extensions:
		'txt': 'text'
		'html': 'html'
		'js': 'javascript'
		'coffee': 'coffeescript'
		'Cakefile': 'coffeescript'
		'jade': 'jade'
		'css': 'css'
		'xml': 'xml'
		'json': 'json'
	
	@html '<div></div>'
	
	@properties
		value:
			set:(value)-> @editor.setValue value
			get:-> @editor.getValue()
	
	constructor:(file, data)->
		super file
		@editor = CodeMirror @element,
			mode: @extensions[@file.filetype[0]] || 'text'
			value: data.replace(/^[ ]+/gm, (leadingSpace)-> leadingSpace.replace /[ ]{4}/g, '\t')
			lineNumbers: true
			tabSize: 4
			indentUnit: 4
			indentWithTabs: true
			autofocus: true
		@editor.on 'change', @autosave.bind @
		
	focus:->
		@editor.focus()
		@editor.refresh()
	
class ImageViewer extends ide.html
	@html '<editor><img/></editor>',
		image: 'img'
	
	constructor:(@file)->
		super()
		@html.image.src = "#{http.host}/readfile/#{@file.path}"
	close:->
		
class SpriteEditor extends ide.editor