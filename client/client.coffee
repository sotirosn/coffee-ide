console.clear()
log = console.log.bind console
error = console.error.bind console
$ = document.querySelector.bind document
	
class Global
	error:(error)-> throw error
global = Global.prototype
	
class Type extends Global
	@properties:(properties)->
		Object.defineProperties @prototype, properties
#end Type

html = (tagname, innerHTML = '')->
	element = document.createElement tagname
	element.innerHTML = innerHTML 
	return element
	
htmlEncode = (string)->
	string.replace /[\u00A0-\u9999<>\&]/gim, ($0)->
		"&##{$0.charCodeAt(0)};"

run = (iterator, args...)-> 
	wait = (value)->iterator.next value
	wait.throw = (error)->log 'throw ' + error; iterator.throw error
	(iterator = iterator wait, args...)?.next?()
	
class UserInterface extends Type
	constructor:(@ui)->

	bind:(method)->
		method.bind this
	
	action:(iterator)->
		if typeof iterator is 'object'
			iterator = iterator[name = Object.keys(iterator)[0]]
			name = "#{this}.#{name}"
		else
			name = "#{this}"
			
		iterator = iterator.bind this
		(args...)->
			log "on #{name}:", args...
			run iterator, args...
			
	onclick:(iterator)->
		if typeof iterator is 'object'
			iterator = iterator[name = Object.keys(iterator)[0]]
			name = "#{this}.#{name}"
		else
			name = "#{this}"
			
		iterator = iterator.bind this
		(event)->
			# just like a regular action
			log "onclick #{name}" 
			run iterator, event
			
			# but also stops the event from bubbling
			event.stopPropagation()
			event.preventDefault()
			return (false)
			
	actions:(iterators)->
		for key, iterator of itertors
			this[key] = action iterator
#end UserInterface

class Http extends Global
	class @Error extends Error

	# when the client encounters errors from the host server
	constructor:(@host)->
	
	error:(onread, message)->
		if onread.throw
			onread.throw new Http.Error message
		else
			throw new Http.Error message
		
	get:(onread, path, data)->
		url = @host + path + @encode(data)
		request = new XMLHttpRequest
		request.open 'GET', url
		request.onreadystatechange = =>
			if request.readyState == 4
				if request.status == 200
					onread JSON.parse(request.responseText)
				else
					@error onread, request.responseText
		request.send()
		
	post:(onread, path, data, value)->
		url = @host + path + @encode(data)
		request = new XMLHttpRequest
		request.open 'POST', url
		request.onreadystatechange = =>
			if request.readyState == 4
				if request.status == 200
					onread JSON.parse(request.responseText)
				else
					@error onread, request.responseText
		request.send(value)
		
	socket:(onread, host = 'ws://localhost:8081')->
		socket = new WebSocket(host)
		socket.onmessage (event)->
			onread event.data
			
	encode:(data)->
		result = ''
		next = '?'
		for key, value of data
			result += next + encodeURI key + '=' + encodeURI value
			next = '&'
		return result
#end Http

class FileServer
	constructor:(url)->
		@http = new Http url
	readdir:(read, path)->
		@http.get read, '/readdir', {path}
	readfile:(read, filepath)->
		@http.get read, '/readfile', {filepath}
	writefile:(read, filepath, value)->
		@http.post read, '/writefile', {filepath}, value
#end FileServer

class File extends Global
	constructor:(@path, @filename)->
		@pathname = path + '/' + filename
		log 'file.constructor: ' + @pathname
		@filetype = filename.match(/[.](.+)$/)?[1] || ''
		
	read:(wait)->
		log 'file.read: ' + @pathname
		@fs.readfile wait @pathname
		
	write:(wait, value)->
		log 'file.write: ' + @pathname
		@fs.writefile @pathname, value
	
	rename:(wait, name)->
		log 'file.rename: ' + @pathname
		@fs.renamefile wait @pathname, name
#end File

class FileElement extends File extends UserInterface
	constructor:(path, filename)->
		#explicit base call
		File.call this, path, filename
	
		#explicit base call
		UserInterface.call this,
			element: html 'element'
			label: html 'label', filename
			openclick: @onclick {@open}

		#link-up ui elements
		@ui.element.appendChild @ui.label
		@ui.element.onclick = @ui.openclick
		
	@properties
		label:set:(value)-> 
			@tab?.name = value
			@ui.label.innerHTML = value

	open:(wait, editor)->
		log 'file(element).open: '+ @pathname
		editor = new (Editor[@filetype] || Editor.text)
		editor.tab = @ide.createTab @filename, editor.window
		editor.tab.editor = editor
		editor.tab.onclose = @action onclose:(wait, resume)=>
			resume (yield editor.close wait)
			@ui.element.onclick = @ui.openclick
		@ui.element.onclick = -> editor.tab.focus()
		editor.load this

	toString:-> "[file: #{@pathname}]"
#end FileElement

class Hierarchy extends UserInterface
	toString:-> 'hierarchy'
	constructor:()->
		log "hierarchy.constructor"
		super container: $('#hierarchy')
		@open = @action {@open}
		log "done"
		
	open:(wait, resume=skip, path)->
		log 'hiererchy.open:', path
		wait.throw = resume.throw
		
		# ask the server to retrieve the contents of a location
		filelist = (yield @fs.readdir wait, path)
		@asFilelist path, filelist
		resume this

	# construct this hierarchy as a filelist
	asFilelist:(path, @filelist)->
		log 'hiererchy.filelist'
		for filename in filelist
			# name is the propert name
			@add new FileElement path, filename
		$('#main').style.left = (@ui.container.offsetWidth + 10) + 'px'

	add:(element)->
		#log 'hierarchy.add: ' + element
		@ui.container.appendChild element.ui.element
#end Hierarchy

class IDE
	constructor:->
		log 'ide.constructor'
		@ui =
			tablist: []
			tabs: $('#tabs')
			windows: $('#windows')
		@ui.tablist.remove = (tab)->
			@focused = undefined if tab == @focused
			@splice (@indexOf tab), 1
			this[0]?.focus() unless @focused
		
	createTab:(label, window)->
		log "new tab: " + label
		tab = new Tab @ui, label, window
		@ui.tablist.push tab
		@ui.tabs.appendChild tab.ui.tab
		@ui.windows.appendChild tab.ui.window
		tab.focus()
		return tab
#end IDE

class Tab extends UserInterface
	@properties
		label:
			get:->@label_
			set:(@label_)-> @ui.label.innerHTML = label_
			
	constructor:(@container, label, window)->
		log 'tab.constructor'
		@ui =
			tab: html 'tab'
			label: html 'label'
			close: html 'close', 'x'
			window: window || html 'div'
		@ui.tab.appendChild @ui.label
		@ui.tab.appendChild @ui.close
		@ui.close.onclick = @onclick @close
		@ui.tab.onclick = @onclick @focus
		@label = label
		
	close:(wait)->
		log "tab.close"
		yield @onclose wait if @onclose?
		@container.tablist.remove(this)?.focus()
		@container.tabs.removeChild @ui.tab
		@container.windows.removeChild @ui.window
		
	focus:->
		log "tab.focus"
		return if @container.focused == this
		@container.focused.blur() if @container.focused
		
		@container.focused = this
		@ui.tab.className = 'active'
		@ui.window.removeAttribute 'hidden'
		@ui.window.focus()
		
	blur:->
		log "tab.blur"
		@ui.tab.className = ''
		@ui.window.setAttribute 'hidden', 1	
#end Tab

class Editor extends UserInterface
	constructor:->
		log "editor.constructor"
		@load = @action {@load}
		@save = @action {@save}
		@close = @action {@close}
		@autosave = @bind @autosave
	
	load:(wait, @file)->
		log "editor.load: " + file.pathname
		@value = yield @fs.readfile wait, file.pathname
		@onload?()
		
	autosaveDelay: 30000
	
	autosave:->
		return if @autosaving
		log "autosaving", @file
		@tab?.label += "*"
		@autosaving = setTimeout (=> @autosaving = false; @save()), @autosaveDelay
		
	save:(wait, resume=skip)->
		log "saving: #{@file.pathname}"
		if @autosaving
			clearTimeout @autosaving 
			@autosaving = (false)
		resume (yield @fs.writefile wait, @file.pathname, @value)
		@tab.label = @file.filename
		
	close:(wait, resume=skip)->
		log "closing: #{@file.pathname}"
		if @autosaving
			resume (yield @save wait)
		else setTimeout (->resume()), 0

	toString:-> "[editor: #{@file?.pathname}]"
#end Editor

class Editor.text extends Editor
	constructor:->
		log "text.editor.constructor"
		super()
		@editor = @window = html 'textarea'
		
	@properties
		value:
			set:(value)->
				@editor.value = value
			get:-> @editor.value
	
	onload:->
		@editor.onkeyup = @editor.onchange = @autosave
		
skip = ->
@onload =->
	log "window.onload"
	
	# construct global objects
	global.fs = new FileServer '.'
	global.ide = new IDE
	global.hierarchy = new Hierarchy
	
	# if there are application settings, load them
	loadApplicationUi?()
	
####