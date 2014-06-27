$ = document.querySelector.bind document
log = console.log.bind console
info = console.info.bind console
error = console.error.bind console

Generator = (-> yield undefined).constructor

stdlog = ([stdout, stderr])-> 
	log stdout if stdout
	error stderr if stderr

onclick = (iterator)->
	(event)->
		event.stopPropagation()
		event.preventDefault()
		run iterator

class Http
	debug:(args...)->log args...
	#debug:->

	constructor:(@host = '')->
		# add a trailing / to the host if it does not already have one
		@debug @host += '/' if @host.length > 0 && @host[@host.length-1] != '/'
		
	urlencode:(data)->
		result = ''
		delimeter = '?'
		for key, value of data
			result += delimeter + urlencode(key) + '=' + urlencode(value)
			delimeter = '&'
		return result
		
	get:(path, data)->
		url = @host + path + @urlencode(data)
		@debug "GET #{url}"
		(wait)->
			request = new XMLHttpRequest
			request.open 'GET', url
			request.onreadystatechange = =>
				if request.readyState == 4
					if request.status == 200
						wait.next JSON.parse(request.responseText)
					else
						wait.throw request.responseText
			request.send()
	
	post:(path, args...)->
		data = (args[0] if typeof args[0] is 'object')
		value = (args[0] if typeof args[0] is 'string')

		if args.length is 2
			data ?= (args[1] if typeof args[1] is 'object')
			value ?= (args[1] if typeof args[1] is 'string')

		url = @host + path + @urlencode(data)
		@debug "POST #{url}"
		(wait)->
			request = new XMLHttpRequest
			request.open 'POST', url
			request.onreadystatechange = =>
				if request.readyState == 4
					if request.status == 200
						wait.next JSON.parse(request.responseText)
					else
						wait.throw request.responseText
			request.send(value)

# globals			
			
app = (null)
http = new Http 'http://localhost:8090'
sleep = (time)->
	(wait)->
		log "sleeping for #{time} milliseconds"
		setTimeout (-> wait.next time), time						

# ======= IDE =============================================================================
		
class ide
	# call this from window.onload
	@load:->
		projectlist = yield http.get 'listdir'
		for projectname in projectlist
			@hierarchy.addProject projectname
	
	@openLocation:(location)->
		iframe = new html.iframe location
		iframe.tab = @rightpane.createTab location, iframe.element
		iframe

# ======= Hierarchy =======================================================================
		
class ide.hierarchy extends html.element
	html: new html 'hierarchy'
	
	addProject:(projectname)->
		project = new ide.hierarchy.project projectname
		@element.appendChild project.element
		project

	remove:(element)->
		@element.removeChild element.element
		
class ide.hierarchy.element extends html.element
	html: new html('element', '<label></label>')
	type: 'element'
	
	@properties
		pathname:get:-> "#{@parent.pathname}/#{@name}"
		label:set:(value)->@html.label.innerHTML = value
	
	constructor:(@project, @parent, @name)->
		super()
		@label = name
		@element.addEventListener 'contextmenu', (event)=>
			app.contextmenu.display this, event

	rename:(name)->
		return if name == @name
		yield http.get "rename/#{@pathname}?name=#{name}"
		console.log "renamed " + name
		@label = @name = name

# ======= Directory ========================================================================

class ide.hierarchy.directory extends ide.hierarchy.element
	html: new html('directory', '<label></label><div class="directories"></div><div class="files"></div>',
		directories: 'div.directories'
		files: 'div.files'
		label: 'label'
	)
	type: 'directory'
	
	constructor:(args...)->
		super args...
		@html.label.onclick = @onclick @toggleOpenClose
		
	open:->
		filelist = yield http.get "listdir/#{@pathname}"
		for name, type of filelist
			switch type
				when 'dir' then @addDirectory name
				when 'file' then @addFile name
		@element.setAttribute 'expanded', true
		@expanded = true
	
	close:->
		@html.directories.innerHTML = ''
		@html.files.innerHTML = ''
		@element.removeAttribute 'expanded'
		@expanded = false

	createDirectory:(name)->
		yield http.get "mkdir/#{@pathname}/#{name}"
		@addDirectory name

	createFile:(name)->
		yield http.post "writefile/#{@pathname}/#{name}", ''
		@addFile name

	addDirectory:(name)->
		directory = new ide.hierarchy.directory @project, @, name
		@html.directories.appendChild directory.element
		directory
		
	addFile:(name)->
		file = new ide.hierarchy.file @project, @, name
		@html.files.appendChild file.element
		file
		
	removeDirectory:(directory)->
		@html.directories.removeChild directory.element
		
	removeFile:(file)->
		@html.files.removeChild file.element
		
	toggleOpenClose:->
		if @expanded then @close()
		else yield run "#{name}.open", @open()

	remove:->
		@parent.removeDirectory this
		
# ======= Project ========================================================================
		
class ide.hierarchy.project extends ide.hierarchy.directory
	html: new html('project', '<label></label><div class="directories"></div><div class="files"></div>',
		directories: 'div.directories'
		files: 'div.files'
		label: 'label'
	)
	type: 'project'
	
	@properties
		pathname:get:-> @name

	constructor:(name)->
		log "project added: #{name}"
		super this, this, name
		@editors = []
		
		run do =>
			script = yield http.get "readfile/#{@pathname}/.project.coffee.js"
			(eval script) this
		
	save:->
		for editor in @editors
			if editor.unsaved
				yield run editor.save()
		
	remove:->
		app.hierarchy.remove this

	addIcon:(label, routine)->
		icon = new html.icon label, @onclick routine
		@html.label.appendChild icon.element
		icon
		
# ======= File ============================================================================
		
class ide.hierarchy.file extends ide.hierarchy.element
	html: new html('file', '<label></label>',
		label: 'label'
	)
	type: 'file'
	
	constructor:(args...)->
		super args...
		@name.replace /[^.]+$/, (@extension)=>
		@element.onclick = @onclick @edit
			
	write:(data)->
		http.post "writefile/#{@pathname}", data
		
	read:->
		http.get "readfile/#{@pathname}"
		
	edit:->
		if @editor
			@editor.tab.focus()
		else
			filedata = yield @read()
			@editor = new ide.hierarchy.file.editor this, filedata
			@editor.tab = app.leftpane.createTab(@name, @editor.element, @editor.close.bind @editor)
			@project.editors.push @editor
			
	createHTML:->
		html 'element',
			onclick: onclick @edit
			[
				html 'label', @file.name
			]

	remove:->
		@parent.removeFile this
	
# ======= File Editor ====================================================================
			
class ide.hierarchy.file.editor extends html.element
	@extensions:
		'js': 'javascript'
		'css': 'css'
		'xml': 'xml'
		'txt': 'text'
		'html': 'htmlmixed'
		'coffee': 'coffeescript'
		
	@properties {
		tab:
			set:(value)->
				@tab_ = value
				@editor.refresh()
			get:-> @tab_
	
		unsaved: 
			set:(value)-> 
				@unsaved_ = value
				@tab.label = @file.name + (if value then '*' else '')
			get:-> @unsaved_
	}
	
	constructor:(@file, data)->
		@editor = new CodeMirror ((@element)=>),
			mode: ide.hierarchy.file.editor.extensions[@file.extension] || 'text'
			lineNumbers: (true)
			indentUnit: 4
			tabSize: 4
			indentWithTabs: (true)
			autofocus: (true)
			value: data.replace(/^[ ]+/gm, (leadingSpace)-> leadingSpace.replace /[ ]{4}/g, '\t')
		@editor.on 'change', @bind @onchange
		@element.focus = @editor.focus.bind @editor
	
	autosaveDelay: 30000
	
	onchange:->
		return if @unsaved
		@unsaved = setTimeout (=> run @save false), @autosaveDelay
	
	save:(@unsaved = @unsaved)->
		if @unsaved
			clearTimeout @unsaved
			@unsaved = (false)
		stdlog [stdout, stderr] = yield @file.write @editor.getValue()
		
	close:->
		if @unsaved
			yield run 'editor.save', @save()
		delete @file.editor

# ======= ContextMenu =====================================================================

class ide.hierarchy.contextmenu extends html.contextmenu
	# create a temporary file placeholder to be renamed by the user
	placeholder: new html('file', '<input/>', input:'input')
	input: document.createElement 'input'	

	constructor:->
		super()
		@addMenuItem 'New File', @bind @createFile
		@addMenuItem 'New Directory', @bind @createDirectory
		@addMenuItem 'Rename', @bind @rename
		@addMenuItem 'Delete', @bind @delete

	# target is the element to be renamed; i.e. a file or directory
	rename:(target)->
		element = target.element
		element.insertBefore(@input, target.html.label)
		target.html.label.setAttribute('hidden', true)

		@input.focus()
		@input.value = target.name
		@input.onchange = ->
			element.removeChild @
			target.html.label.removeAttribute('hidden')
			run target.rename @value
		@input.onblur = ->
			element.removeChild @
			target.html.label.removeAttribute('hidden')

	# target is the directory in which to create the new file
	createFile:(target)->
		if !(target instanceof ide.hierarchy.directory)
			target = target.parent
		directory = target.html.directories
		directory.insertBefore(@placeholder.element, directory.firstChild)

		input = @placeholder.html.input
		input.value = ''
		input.placeholder = 'new file'
		input.onchange = =>
			directory.removeChild @placeholder.element
			run target.createFile input.value
		input.onblur = =>
			directory.removeChild @placeholder.element
		input.focus()

	# target is the directory in which to create the new directory
	createDirectory:(target)->
		if !(target instanceof ide.hierarchy.directory)
			target = target.parent
		directory = target.html.directories
		directory.insertBefore(@placeholder.element, directory.firstChild)

		input = @placeholder.html.input
		input.value = ''
		input.placeholder = 'new directory'
		input.onchange = =>
			directory.removeChild @placeholder.element
			run target.createDirectory input.value
		input.onblur = =>
			directory.removeChild @placeholder.element
		input.focus()
	
	delete:(target)->
		if confirm "Are you sure you want to delete #{target.type} #{target.pathname}?"
			yield http.get "delete/#{target.pathname}"
			@target.remove()
		
# ======= Application Setup ====================================================================		
		
@onload	= ->
	logger = new html.log
	#log = logger.log.bind logger
	error = logger.error.bind logger
	stdlog = logger.stdlog.bind logger
	#log.section = logger.start.bind logger
	#log.section "@onload >>"
	
	class app extends ide
		@contextmenu: new ide.hierarchy.contextmenu
		@toolbar: new html.toolbar $('toolbar')
		@hierarchy: new ide.hierarchy $('hierarchy')
		@leftpane: new html.tabarea $('tabarea#leftpane')
		@rightpane: new html.tabarea $('tabarea#rightpane')
		
	document.body.appendChild app.contextmenu.element
	app.rightpane.createTab 'log', logger.element
	run "app.load", app.load()
