$ = document.querySelector.bind document
log = console.log.bind console
Generator = (->yield null).constructor
json = JSON.parse.bind JSON

# a convinient extendable property that stores a single value

set = (set)->
	if (typeof set) != 'function' || set.length != 1
		throw 'set expects a function with one argument'
	
	_value = null
	return {
		get:-> _value
		set:(value)-> set.call @, value; _value = value
	}

Array.prototype.remove = (element)->
	@splice (index = @indexOf element), 1
	index
	
Array.prototype.contains = (element)->
	-1 < @indexOf element

htmldecode = (text)->
	text.replace /&#([^;]+);/g, ($0, $1)-> 
		log $1
		String.fromCharCode $1
		$0

class ide.routine
	constructor:(@iterator)->
		
	throw:(exception)->
		@iterator.throw exception
		
	next:(nextvalue)->
		{@done, @value} = @iterator.next nextvalue
		if @done
			@onreturn?.next @value
		else
			@value @
			
		(@onreturn)=>
			@onreturn.next @value if @done
				
	@run:(iterator)->
		if iterator?.next?
			(new ide.routine iterator).next() 
		else
			(routine)-> routine.next()
	
class ide.http
	constructor:(@host)->
	
	encode:(data)->
		result = ''
		delimeter = '?'
		for key, value of data
			result += "#{delimeter}#{encodeURI key}=#{encodeURI value}"
			delimeter = '&'
		result
		
	request:(method, url, data, parser)->
		log method, url
		(routine)->
			request = new XMLHttpRequest()
			request.open method, url
			request.withCredentials = true
			request.onreadystatechange = ->
				if @readyState == 4
					if @status == 200
						if parser
							routine.next parser @responseText
						else
							routine.next @responseText
							
					else
						routine.throw @responseText
			request.send data
	
	get:(uri, data)->
		url = "#{@host}/#{uri}#{@encode data}"
		@request 'GET', url
			
	getdata:(uri, data)->
		url = "#{@host}/#{uri}#{@encode data}"
		@request 'GET', url, undefined, json
	
	post:(uri, data = {}, value)->
		if arguments.length == 2 && (typeof data) == 'string'
			value = data
			data = {}
		url = "#{@host}/#{uri}#{@encode data}"
		@request 'POST', url, value

	postdata:(uri, data = {}, value)->
		if arguments.length == 2 && (typeof data) == 'string'
			value = data
			data = {}
		url = "#{@host}/#{uri}#{@encode data}"
		@request 'POST', url, value, json

class ide.placeholder extends ide.html
	@html '<input/>'
	
	constructor:->
		super
		@hide = @hide.bind @
		@element.onblur = @hide
		@element.onclick = (event)->
			event.stopPropagation()
		@element.onkeypress = (event)=>
			switch event.keyCode
				when 27	then @hide()
				when 13 then @element.blur()
				
	show:(container, target, value, onblur)->
		# reset from any previous actions
		@hide() if @target?
		
		# place this input element in the given container
		container.insertBefore @element, target?.element
		@element.style.display = 'block'
		@element.onblur = onblur
		@element.value = value
		@element.select()
		
		# set and hide the new target
		@target = target 
		@target?.hide()
		
	hide:->
		# reset input element to original state
		@element.style.display = 'none'
		@element.onblur = @hide
		# reveal the target and forget it
		@target?.show()
		delete @target
	
class ide.element extends ide.html
	@html '<element><label></label></label>',
		label: 'label'
	placeholder: new ide.placeholder
		
	
	@properties
		label:set (value)-> @html.label.innerHTML = value
		path:get:-> "#{@parent.path || '.'}/#{@name}"
		
	oncontextmenu:(event)->
		event.element ?= @element
	
	constructor:(@project, @parent, @name)->
		super()
		@label = name
		@element.element = @
		@element.oncontextmenu = @oncontextmenu	
	
	rename:(name)->
		@label = @name = name
		
	delete:->
		yield http.get "delete/#{@path}"
		@element.parentNode.removeChild @element
	
	createFolder:->
		@parent.createFolder()
	
	createFile:->
		@parent.createFile()

class ide.file extends ide.element
	@html '<file><label></label></file>',
		label: 'label'
	
	imageExtensions: 'jpg', 'png', 'gif'
	
	dataExtensions:
		'sprite': SpriteEditor
		
	constructor:->
		super
		@element.onclick = @onclick @edit
		@filetype = @name.split('.').reverse()
		
	edit:->
		# just show the editor if it already exists
		return @editor.tab.activate() if @editor
			
		# '*.*.json' files may be edited with custom data editors
		if @filetype[0] == 'json' && editor = @dataExtensions[@filetype[1]]
			data = yield http.getdata "readdata/#{@path}"
			@editor = new editor @, data
			
		# an image viewer may work...
		else if @imageExtensions.contains @filetype[0]
			@editor = new ImageViewer @
			
		# otherwise open it with a text editor
		else
			text = yield http.get "readfile/#{@path}"
			@editor = new TextEditor @, text
		
		# stick the editor in a tab
		@editor.tab = app.leftpane.createTab @name, @editor
		@project.editors.push @editor
		
	close:->
		@project.editors.remove @editor
		delete @editor
		
class ide.directory extends ide.element
	@html '<directory><label></label><div class="directories"></div><div class="files"></div></directory>',
		label: 'label'
		files: 'div.files'
		directories: 'div.directories'
	
	@properties
		expanded:set (value)->
			if (value)
				@element.setAttribute 'expanded', true
			else
				@element.removeAttribute 'expanded'
			
	constructor:->
		super
		@element.onclick = @onclick @toggle
		
	open:->
		filelist = yield http.getdata "listdir/#{@path}"
		for name, type of filelist
			switch type
				when 'file' then @addFile name
				when 'dir' then @addDirectory name
		@expanded = true
		
	close:->
		@html.directories.innerHTML = ''
		@html.files.innerHTML = ''
		@expanded = false
		
	toggle:->
		if @expanded then @close() else run @open()
	
	addFile:(name)->
		file = new ide.file @project, @, name
		@html.files.appendChild file.element
		file
	
	addDirectory:(name)->
		directory = new ide.directory @project, @, name
		@html.directories.appendChild directory.element
		directory
	
	# ======================== context menu actions ========================= #
	createFolder:->
		@placeholder.show @html.directories, null, 'new folder', @onclick ->
			@placeholder.hide()
			yield http.get "mkdir/#{@path}/#{@placeholder.element.value}", ''
			@addDirectory @placeholder.element.value
	
	createFile:->
		@placeholder.show @html.files, null, 'new file', @onclick ->
			@placeholder.hide()
			yield http.post "writefile/#{@path}/#{@placeholder.element.value}", ''
			@addFile @placeholder.element.value
		
	renameElement:(target)->
		@placeholder.show target.element.parentNode, target, target.name, @onclick ->
			@placeholder.hide()
			yield http.get "rename/#{target.path}", newpath:"#{@path}/#{@placeholder.element.value}"
			target.rename @placeholder.element.value
		
class ide.project extends ide.directory
	@html '<project><label></label><div class="directories"></div><div class="files"></div></project>',
		label: 'label'
		files: 'div.files'
		directories: 'div.directories'
		
	constructor:(name)->
		super @, '.', name
		@editors = []
		@run ->
			#yield run @open()
			try
				script = yield http.get "readfile/#{@path}/.project.coffee.js"
				(eval script) @

	createButton:(label, onclick)->
		button = new ide.button label, onclick
		@html.label.appendChild button.element
		button
		
	command:(command)->
		http.getdata "command/#{@path}/#{command}"
	
	runCommand:(command)->
		http.getdata "run/#{@path}/#{command}"
		
class ide.contextmenu extends ide.html
	@html '<menu hidden=true><div></div></menu>',
		menu:'div'
	@menu: {}
	
	onclick:(action)->
		(event)=>
			event.stopPropagation()
			event.preventDefault()
			action.call @, @target
			@hide()
			return false
	
	constructor:->
		super
		
		@menu = {}
		for itemname, action of @constructor.menu
			menuitem = @html.menu.querySelector "[name=#{itemname}]"
			menuitem.onmousedown = @onclick action
			@menu[itemname] = menuitem
		@visible = false
		
	show:(event)->
		if !@visible
			@visible = true
			@element.removeAttribute 'hidden'
		@element.style.left = event.clientX + 'px'
		@element.style.top = event.clientY + 'px'
		@target = event.element
	
	hide:->
		if @visible
			@visible = false
			@element.setAttribute 'hidden', true
			

class ide.hierarchy extends ide.html
	@html '<hierarchy></hierarchy>'

	class contextmenu extends ide.contextmenu
		@html '''
			<menu hidden=true><div>
				<label name='newFolder'>New Folder</label>
				<label name='newFile'>New File</label>
				<hr/>
				<label name='rename'>Rename</label>
				<label name='cut'>Cut</label>
				<label name='copy'>Copy</label>
				<label name='paste' disabled=true>Paste</label>
				<label name='delete'>Delete</label>
				<hr/>
				<label name='download'>Download</label>
			</div></menu>
		''', menu:'div'
		
		@menu:
			newFolder:(element)->
				element.createFolder()
			newFile:(element)->
				element.createFile()
			rename:(element)->
				element.parent.renameElement element
			cut:(element)->
				@copy = undefined
				@cut = element
				@menu.paste.removeAttribute 'disabled'
			copy:(element)->
				@copy = element
				@cut = undefined
				@menu.paste.removeAttribute 'disabled'
			paste:(element)->
				if @cut?
					element.paste @cut
					@html['Paste'].setAttribute 'disabled', true
				else if @copy
					element.copy @copy
			delete:(element)->
				run element.delete()
				@menu.paste.setAttribute 'disabled', true
		
	contextmenu: new contextmenu
	
	oncontextmenu:(event)->
		return if !event.element?
		@contextmenu.show event
		
		event.preventDefault()
		event.stopPropagation()
		return false
	
	constructor:->
		document.body.appendChild @contextmenu.element
		
		super
		@element.oncontextmenu = @oncontextmenu.bind @
		
		@run ->
			sessionID = yield http.postdata 'login', 'password=$sounds'
			projectlist = yield http.getdata 'projectlist'
			for name in projectlist
				@addProject name
	
	addProject:(name)->
		project = new ide.project name
		@element.appendChild project.element
		project

class ide.toolbar extends ide.html
	@html '<toolbar></toolbar>'
	
class ide.tab extends ide.html
	@html '<tab><label></label><close>x</close></tab>',
		label: 'label'
		close: 'close'
	
	@properties
		label:set (value)->
			@html.label.innerHTML = value
	
	constructor:(label, @content)->
		super()
		@label = label
		@element.onclick = @onclick @activate
		@html.close.onclick = @onclick @close
	
	activate:->
		@tabarea.activateTab @
		@content.focus()
	
	close:->
		# wait for the content window to close shop before removing self from tabarea
		yield run @content.close()
		@tabarea.removeTab @
	
class ide.tabarea extends ide.html
	@html '<tabarea><tabs></tabs><contents></contents></tabarea>',
		tabs: 'tabs'
		contents: 'contents'
	
	constructor:->
		super
		@tabs = []
	
	activateTab:(tab)->
		return if @active == tab
		@active?.element.removeAttribute 'active'
		@active?.content.element.setAttribute 'hidden', true
		@active = tab
		@active.element.setAttribute 'active', true
		@active.content.element.removeAttribute 'hidden'
	
	removeTab:(tab)->
		# remove the tab from tabs array and dom containers
		index = @tabs.remove tab
		@html.tabs.removeChild tab.element
		@html.contents.removeChild tab.content.element
		
		# activate a new tab if this tab was the active tab (and there are more tabs)
		if @active == tab && @tabs.length > 0
			@tabs[if index == @tabs.length then index-1 else index].activate()
	
	addTab:(tab)->
		tab.tabarea = @
		@html.tabs.appendChild tab.element
		@html.contents.appendChild tab.content.element
		@tabs.push tab
		tab.activate()
	
	createTab:(label, content)->
		@addTab tab = new ide.tab label, content
		tab
	
class ide.statusbar extends ide.html
	@html '<statusbar><label></label><span></span></statusbar>',
		info: 'label'
		message: 'span'
		
app = null
http = new ide.http 'https://localhost:9090'
run = ide.routine.run

@onmousedown = (event)->
	app.hierarchy.contextmenu.hide()

@onload = ->
	app = new ide
		hierarchy: $('#hierarchy')
		toolbar: $('#toolbar')
		leftpane: $('#leftpane')
		rightpane: $('#rightpane')
		statusbar: $('#statusbar')
