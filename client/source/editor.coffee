class ide.editor extends ide.html
	@html '<editor><textarea></textarea></editor>'
	@components:
		textarea: 'textarea'
	
	@properties
		value:
			set:(value)-> @html.textarea.value = value
			get:-> @html.textarea.value
		error:
			set:(value)-> 
				@_error = value
			get:-> @_error
	
	@create:(file)->
		editor = new @ file
		yield editor.load()
		editor
	
	constructor:(@file)->
		log "new file editor -> #{@file.path}"
		super()

	load:->
		text = yield http.get "read/#{@file.path}"
		@value = text
		@element.oninput = @autosave.bind @
		
	autosaveDelay: 30000
	autosave:->
		return if @saving
		@saving = setTimeout (=> run @save true), @autosaveDelay 
		@tab.label = "#{@file.name}*"

	save:(autosaving = false)->
		clearTimeout @saving if !@autosaving
		delete @saving
		@tab.label = @file.name

		log result = yield http.post "write/#{@file.path}", @value
		
	close:->
		yield @save() if @saving || @error

	focus:->
		@element.focus()

class DataEditor extends ide.editor
	@extensions: {}

class TextEditor extends ide.editor
	class ErrorMark extends ide.html
		@html '<label class="error">&#8855;</label>'
		
		@properties
			message:set:(value)-> @element.title = value
		
		constructor:(symbol)->
			super()
			@element.innerHTML = symbol
	
	@html '<editor></editor>'
	@components: {}

	@properties
		value:
			set:(value)-> @editor.setValue value
			get:-> @editor.getValue()

		error:
			set:(value)->
				if value
					[_, lineNumber] = value.message.match /on line (\d+)/
					@errorLineMark ?= new ErrorMark '&#9670;'
					@errorTabMark ?= new ErrorMark '&#9670;'
					@errorLineMark.message = @errorTabMark.message = value.message
					
					@editor.setGutterMarker +lineNumber - 1, 'CodeMirror-linenumbers', @errorLineMark.element
					@tab.element.appendChild @errorTabMark.element
				else if @_error
					@editor.clearGutter 'CodeMirror-linenumbers'
					@tab.element.removeChild @errorTabMark.element
				@_error = value
					
			get:-> @_error
					
	@extensions:
		'txt': 'text'
		'html': 'html'
		'Cakefile': 'coffeescript'
		'jade': 'jade'
		'css': 'css'
		'xml': 'xml'
		'json': 'json'
		'coffee': 'coffeescript'
		'js': 'javascript'

	load:->
		text = yield http.get "read/#{@file.path}"
		@editor = CodeMirror @element,
			mode: TextEditor.extensions[@file.filetype[0]] || 'text'
			value: text.replace(/^[ ]+/gm, (leadingSpace)-> leadingSpace.replace /[ ]{4}/g, '\t')
			lineNumbers: true
			tabSize: 4
			indentUnit: 4
			indentWithTabs: true
		@editor.on 'change', @autosave.bind @
		
	save:(autosaving = false)->
		return try
			yield super
			@error = undefined
		catch exception
			if exception instanceof SyntaxError || exception.message?.match /Parse error/
				if autosaving || !confirm "#{exception.name}: '#{exception.message}'. Close anyway?"
					@error = exception
					yield ->

	focus:->
		@editor.refresh()
		@editor.focus()
