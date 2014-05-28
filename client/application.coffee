class Editor.js extends Editor
	constructor:->
		log "js.editor.constructor"
		super()
		@editor = new CodeMirror ((@window)=>),
			mode: 'javascript'
			lineNumbers: (true)
			indentUnit: 4
			tabSize: 4
			indentWithTabs: (true)
			autofocus: (true)
		@window.focus = =>
			@editor.focus()
		
	@properties
		value:
			set:(value)->
				# format tabs into spaces for sake of consistency
				@editor.setValue value.replace /\n( +)/g, ($0, $1)->
					'\n' + $1.replace /( {4})/g, '\t'
			get:-> @editor.getValue()
	
	onload:->
		@editor.on 'change', @autosave
	
	toString:-> "[editor.coffee: #{@file?.pathname}]"
#end Editor.html

class Editor.coffee extends Editor
	constructor:->
		log "coffee.editor.constructor"
		super()
		@editor = new CodeMirror ((@window)=>),
			mode: 'coffeescript'
			lineNumbers: (true)
			indentUnit: 4
			tabSize: 4
			indentWithTabs: (true)
			autofocus: (true)
		@window.focus = =>
			@editor.focus()
		
	@properties
		value:
			set:(value)->
				# format tabs into spaces for sake of consistency
				@editor.setValue value.replace /\n( +)/g, ($0, $1)->
					'\n' + $1.replace /( {4})/g, '\t'
			get:-> @editor.getValue()
	
	onload:->
		@editor.on 'change', @autosave
	
	toString:-> "[editor.coffee: #{@file?.pathname}]"
#end Editor.coffee

class Editor.html extends Editor
	constructor:->
		log "html.editor.constructor"
		super()
		@editor = new CodeMirror ((@window)=>),
			mode: 'htmlmixed'
			lineNumbers: (true)
			indentUnit: 4
			tabSize: 4
			indentWithTabs: (true)
			autofocus: (true)
		@window.focus = =>
			@editor.focus()
		
	@properties
		value:
			set:(value)->
				# format tabs into spaces for sake of consistency
				@editor.setValue value.replace /\n( +)/g, ($0, $1)->
					'\n' + $1.replace /( {4})/g, '\t'
			get:-> @editor.getValue()
	
	onload:->
		@editor.on 'change', @autosave
	
	toString:-> "[editor.coffee: #{@file?.pathname}]"
#end Editor.html

class Editor.css extends Editor
	constructor:->
		log "css.editor.constructor"
		super()
		@editor = new CodeMirror ((@window)=>),
			mode: 'css'
			lineNumbers: (true)
			indentUnit: 4
			tabSize: 4
			indentWithTabs: (true)
			autofocus: (true)
		@window.focus = =>
			@editor.focus()
		
	@properties
		value:
			set:(value)->
				# format tabs into spaces for sake of consistency
				@editor.setValue value.replace /\n( +)/g, ($0, $1)->
					'\n' + $1.replace /( {4})/g, '\t'
			get:-> @editor.getValue()
	
	onload:->
		@editor.on 'change', @autosave
	
	toString:-> "[editor.coffee: #{@file?.pathname}]"
#end Editor.css

class Icon extends UserInterface
	constructor:(label, action)->
		super
			icon: html 'icon', label
		@ui.icon.onclick = @onclick action		

		
loadApplicationUi = ->
	log 'applicationui.load'
	
	# required dom objects
	ui = 
		window: window
		toolbar: $('#toolbar')		
		content: $('#content iframe').contentWindow
	
	global.projects =
		server: './server'
		client: './client'
		site: './site'
	
	run (wait)->
		for name, path of global.projects
			directory = { ui:element:html 'directory', htmlEncode name }
			global.hierarchy.add directory
			try 
				yield global.hierarchy.open wait, path
			catch error
				console.error error
				directory.ui.element.className = 'error'
				directory.ui.element.innerHTML += ' - not found'
	
	ui.toolbar.appendChild (new Icon 'save', 
		(wait)->
			for tab in global.ide.ui.tablist
				yield tab.editor.save wait if tab.editor?.autosaving
			log 'saved all'
			ui.window.location.reload()
	).ui.icon
	
	ui.toolbar.appendChild (new Icon 'preview', 
		(wait)->
			for tab in global.ide.ui.tablist
				yield tab.editor.save wait if tab.editor?.autosaving
			log 'saved all'
			ui.content.location.reload()
	).ui.icon
	