class ide
	constructor:(object)->
		for key, value of object
			@[key] = value
		
		run do =>
			try
				projectlist = yield http.get ''
			catch exception
				console.error exception
				@login.show()
			@hierarchy.load projectlist

	login:(username, password)->
		projectlist = yield http.post '', {username, password}
		@load projectlist

class ide.html
	dom = document.createElement 'div'

	@properties:(properties)->
		Object.defineProperties @prototype, properties

	@html:(htmlstring)->
		dom.innerHTML = htmlstring
		@element = dom.firstChild
		log "declare", @element

	@components: {}
	
	@onclick:(method)->
		return if method.isGenerator()
			(event)->
				event.stopPropagation()
				event.preventDefault()
				run method event
				false
		else
			(event)->
				event.stopPropagation()
				event.preventDefault()
				method event
				false

	onclick:(method)->
		return if method.isGenerator()
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				run method.call @, event
				false
		else
			(event)=>
				event.stopPropagation()
				event.preventDefault()
				method.call @, event
				false

	constructor:(element)->
		@element = element || @constructor.element.cloneNode true
		log 'new', @element, @constructor.components

		@html = {}
		for key, value of @constructor.components
			@html[key] = @element.querySelector value

	@createTab:(label, args...)->
		content = new @ args...
		content.tab = new ide.tab label, content
		[content.tab, content]

class ide.login extends ide.html
	@html '<login><label>username</label><input name="username"/><br/><label>password</label><input name="password"/><br/></login>'

	show:-> app.leftpane.element.appendChild @element
	hide:-> app.leftpane.element.removeChild @element

class ide.hierarchy extends ide.html
	@html '<hierarchy></hierarchy>'

	load:(projectlist)->
		log projectlist
		for projectname of projectlist
			run do =>
				project = yield ide.project.create projectname
				@element.appendChild project.element

class ide.file extends ide.html
	@html '<file><label></label></file>'

	@components:
		label: 'label'

	@properties
		label:set:(value)-> @html.label.innerHTML = value
		path:get:-> "#{@parent.path}/#{@name}"
		filetype:get:-> (@name.split '.').reverse()

	constructor:(@project, @parent, @name)->
		super()
		@label = @name
		@html.label.onclick = @onclick @edit

	edit:->
		# just focus the editor if it is already opened
		return @editor.tab.focus() if @editor?

		# otherwise open a new editor
		filetype = (@name.split '.').reverse()
		
		# open a specific data editor for .json files, or use a text editor
		if filetype[0] == 'json'
			Editor = DataEditor.extensions[filetype[1]]
		Editor ?= TextEditor # or use a text editor

		# instantiate the editor and tab
		@editor = yield Editor.create @
		@editor.tab = app.leftpane.createTab @name, @editor, =>
			@project.editors.remove @editor
			delete @editor
		@project.editors.push @editor
		
	close:->
		@project.editors.remove @editor
		delete @editor

class ide.folder extends ide.html
	@html '<folder><label></label><div class="folders"></div><div class="files"></div></folder>'

	@components:
		label: 'label'
		folders: 'div.folders'
		files: 'div.files'
	
	@properties
		label:set:(value)-> @html.label.innerHTML = value
		path:get:-> "#{@parent.path}/#{@name}"
		expanded:
			get:-> @_expanded
			set:(value)-> @element.setAttribute 'expanded', @_expanded = value

	constructor:(@project, @parent, @name)->
		super()
		@label = @name
		@expanded = false
		@element.onclick = @toggle = @onclick @toggle

	toggle:->
		if @expanded then @close() else run @open()

	open:->
		# prevent the user from clicking again until the operation completes
		@html.label.className = 'loading'
		@html.label.onclick = null
		
		# request directory list
		try 
			contentlist = yield http.get "list/#{@path}"
		catch error
			@html.label.title = error
			@html.label.className = 'error'
			return
		
		# parse list data
		for name, type of contentlist
			switch type
				when 'folder' then @addFolder name
				when 'file' then @addFile name

		# allow user open/close onclick again
		@html.label.className = ''	
		@html.label.onclick = @toggle
		@expanded = true	
		
	close:->
		@expanded = false
		@html.folders.innerHTML = ''
		@html.files.innerHTML = ''

	addFile:(name)->
		file = new ide.file @project, @, name
		@html.files.appendChild file.element
		file

	addFolder:(name)->
		folder = new ide.folder @project, @, name
		@html.folders.appendChild folder.element
		folder

class ide.project extends ide.folder
	@html '<project><label></label><div class="folders"></div><div class="files"></div></project>'
	
	@properties
		path:get:-> @name 

	@create:(name)->
		log "create project #{name}"

		# attempt to create the project from server config script
		try
			script = yield http.get "read/#{name}/.client.coffee.js"
		catch error
			return new ide.project name
		new (eval script) name
		
	constructor:(name)->
		super @, undefined, name
		@editors = []
		
	addButton:(label, onclick)->
		button = new ide.button label, onclick
		@html.label.appendChild button.element
		button

	saveAll:->
		{wait, all} = new WaitAll
		for editor in @editors
			if editor.saving
				wait editor.save()
		yield all

class ide.button extends ide.html
	@html '<button></button>'

	@properties
		label:set:(value)-> @element.innerHTML = value
		onclick:set:(value)-> @element.onclick = ide.html.onclick value

	constructor:(label, onclick)->
		super()
		@label = label
		@onclick = onclick
				
http = null
app = null
@onload = ->
	log 'onload'
	app = new ide
		login: new ide.login
		hierarchy: new ide.hierarchy $('hierarchy')
		leftpane: new ide.tabpane $('#leftpane')
		rightpane: new ide.tabpane $('#rightpane')
