Array.prototype.remove = (element)->
	index = @indexOf element
	@splice index, 1
	index

class ide.tabpane extends ide.html
	@html '<tabcontents><div class="tabs"></div><div class="contents"></div></tabcontents>'
	@components:
		tabs: 'div.tabs'
		contents: 'div.contents'

	constructor:->
		super
		@tabs = []

	createTab:(label, content, onclose)->
		tab = new ide.tab label, content, onclose
		@addTab tab
		tab

	addTab:(tab)->
		tab.container = @
		@tabs.push tab
		@html.tabs.appendChild tab.element
		@html.contents.appendChild tab.content.element
		tab.focus()

	focusTab:(tab)->
		return if @active == tab
		@active?.element.removeAttribute 'active'
		@active?.content.element.setAttribute 'hidden', true
		@active = tab
		@active.element.setAttribute 'active', true
		@active.content.element.removeAttribute 'hidden'
		@active.content.focus?()
		
	removeTab:(tab)->
		@html.tabs.removeChild tab.element
		@html.contents.removeChild tab.content.element
		
		index = @tabs.remove tab

		if @active == tab && @tabs.length > 0
			@tabs[if index < @tabs.length then index else index - 1].focus()

class ide.tab extends ide.html
	@html '<tab><label></label><close>x</close></tab>'
	@components:
		label: 'label'
		close: 'close'

	@properties
		label:set:(value)-> @html.label.innerHTML = value

	constructor:(label, @content, @onclose)->
		super()
		@label = label
		@element.onclick = @onclick @focus
		
		@html.close.onclick = @onclick (
			if @content.close?.isGenerator()
				=>
					yield @content.close()
					@container.removeTab @
					@onclose?()
			else
				=>
					@content.close?()
					@container.removeTab @
					@onclose?()
		)

	focus:->
		@container.focusTab @
		@content.focus()

class ide.view extends ide.html
	@html '<iframe></iframe>'

	@properties
		location:
			set:(value)-> @element.src = value
			get:-> @element.src
			
	constructor:(location)->
		super()
		setTimeout (=> @location = location), 0

	refresh:->
		@location = @location
		
	focus:->
		@element.focus()
		@onclick = onclick
		
