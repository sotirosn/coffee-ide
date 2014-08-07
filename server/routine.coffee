log = console.log.bind console

Generator = (-> yield null).constructor
Function.prototype.isGenerator = ->
	@ instanceof Generator

Iterator = (do -> yield null).constructor
Function.prototype.isIterator = ->
	@ instanceof Iterator

class Routine extends Function
	@debug: false
	@id: 0

	next:(value)->
		@ undefined, value
	throw:(exception)->
		@ exception
	debug:->

	@lastly:(error, data)->
		throw error if error
		#console.dir data if Routine.debug
	@lastly.__proto__ = @prototype
	@lastly.id = @id++

	@start:(iterator, onreturn)->
		onreturn.__proto__ = @prototype
		onreturn.id = 'start'
		@run iterator, onreturn

	@start = @start.bind @

	@run:(iterator, onreturn = @lastly)->
		#unless iterator?.isIterator?()
		#	log iterator
		#	throw new TypeError 'Routine.run expects iterator as first argument' 

		id = "#{onreturn.id}/#{@id++}"
		log "#{id} -> run" if @debug
		
		routine = (error, data)=>
			# try to resume the iterator (either normally -> next, or with an error -> throw)
			try
				log "#{id} -> resume" if Routine.debug
				{done, value} = unless error
					log "#{id} -> next" if Routine.debug
					iterator.next data
				else # something bad happend, throw the exception to that which yielded
					log "#{id} -> exception" if Routine.debug
					iterator.throw error
			
			catch exception # if anything bad happens, throw up on the parent routine
				log "#{id} -> throwing to #{onreturn.id}" if Routine.debug
				onreturn.throw exception
				return

			# iterator has yielded successfully (no exceptions), process {done, value} 

			if done # all done, resume parent routine
				log "#{id} -> returning to #{onreturn.id}" if Routine.debug
				onreturn.next value
			
			else if value.next # not done, and value is an iterator, start a subroutine
				log "#{id} -> yield subroutine" if Routine.debug
				@run value, routine
			
			else # not done, and value is an async routine callback, pass it the routine
				log "#{id} -> yield async routine callback" if Routine.debug
				try value routine
				catch exception then onreturn.throw exception

		# changing the routine function prototype makes it both,
		#   a callback: (error, data)-> 
		#   and an iterator object: { next:(data)->, throw:(exception)-> }
		routine.__proto__ = @prototype
		routine.id = id
		
		# actually do the next step of the iterator
		do routine
		
		# return the routine function/object
		routine 
	
	@run = @run.bind @

class Routine.WaitAll
	errors: 0
	count: 1

	constructor:->
		@all = @all.bind @
		@wait = @wait.bind @
		@resume = @resume.bind @
		@resume.__proto__ = Routine.prototype
		@resume.id = 'wait'

	resume:(error)->
		if error
			@error = error
			@errors++
		if --@count == 0
			@error?.count = @errors
			@onreturn @error

	wait:(iterator)->
		++@count
		Routine.run iterator, @resume

	all:(@onreturn)->
		@resume()
		
class Routine.fs
	_fs = require 'fs'

	@write:(path, data)->
		(routine)-> _fs.writeFile path, data, encoding:'utf8', routine

	@read:(path)->
		(routine)-> _fs.readFile path, encoding:'utf8', routine

	all = (stat)-> stat
	@list:(dirpath, filter = all)->
		dirlist = yield (routine)-> _fs.readdir dirpath, routine
		
		list = {}
		{wait, all} = new Routine.WaitAll
		for path in dirlist
			wait ((path)=> list[path] = filter (yield @stat "#{dirpath}/#{path}")) path
		yield all
		list

	@stat:(path)->
		(routine)-> _fs.stat path, routine
		
module.exports = Routine
