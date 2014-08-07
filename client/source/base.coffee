log = console.log.bind console
$ = document.querySelector.bind document

class Routine
	@run:(iterator, onreturn = Routine.finally)->
		resume = (error, data)->
			try
				{done, value} =
					if error then iterator.throw error
					else iterator.next data

				# if iterator finished, resume calling routine normally
				if done
					onreturn(undefined, value)
				# if iterator yielding for subroutine
				else if (typeof value?.next) == 'function'
					Routine.run value, resume
				# if iterator yielding for an (error, data)-> async callback
				else if (typeof value) == 'function'
					value resume
				# if iterator yielding for something unexpected
				else
					log value
					throw new TypeError 'iterator expected to return a callback or an iterator.'

			# uncaught routine exceptions bubble back up to calling routine
			catch exception
				log 'throwing up'
				onreturn exception

		# start the routine
		resume()

	@finally:(error, value)->
		if error then throw error else value

class Routine.WaitAll
	count: 1

	constructor:->
		# @resume may be passed into yielding iterator values multiple times
		@resume = @resume.bind @

		# wait, all bound for convinience ({wait, all} = new WaitAll)
		@wait = @wait.bind @
		@all = @all.bind @

	resume:(error, data)->
		if error
			@error = error # saves the last error which occured during wait, to send back the the caller
			console.error error.stack || error

		# releases locks set by @wait
		if --@count == 0
			# @error may be undefined if no errors occured
			@onreturn @error
		@count

	wait:(iterator)->
		++@count # sets locks released by @resume
		try
			if (typeof iterator.next) == 'function'
				Routine.run iterator, @resume
			else
				iterator @resume
		catch exception
			@resume exception

	all:(@onreturn)->
		@resume()	
			
{run, WaitAll} = Routine

class Http
	json = JSON.parse.bind JSON
	raw = (text)-> text

	constructor:(@host)->
		[_, host] = @host.match /^https:\/\/(.*)$/
		@wshost = "wss://#{host}"
	
	connect:(url, data)->
		(callback)=>
			#log "#{@wshost}/#{url}/#{@encode data}"
			connection = new WebSocket "#{@wshost}/#{url}/#{@encode data}"
			connection.onopen = ->
				callback undefined, connection
		
	request:(method, url, data)->
		#log arguments...
		(callback)->
			request = new XMLHttpRequest()
			request.open method, url
			request.onreadystatechange = ->
				if request.readyState == 4
					try 
						data = JSON.parse request.responseText
					catch exception
						return callback exception
					
					if request.status == 200
						callback undefined, data
					else
						error = new (window[data.name] || Error) data.message
						error.name = data.name
						callback error
			request.send data

	post:(url, data)->
		@request 'POST', "#{@host}/#{url}", switch typeof data
			when 'object' then @encode data
			when 'string' then data
		
	get:(url, data)->
		querystring = switch typeof data
			when 'object' then @endcode data
			when 'string' then data
			else ''
		@request 'GET', "#{@host}/#{url}#{querystring}"
		
	encode:(data = {})->
		result = ''
		delimeter = '?'
		for key, value of data
			result += "#{delimeter}#{key}=#{encodeURIComponent(value)}"
			delimeter = '&'
		result
