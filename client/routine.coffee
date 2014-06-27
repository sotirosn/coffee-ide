log = console.log.bind console

class Logger
	constructor:(@log = console.log.bind console)->
	start:(name)->
		new Logger @log.bind(console, "#{name}")
		
class Routine
	@logger: new Logger
	@log: @logger.log
	
	@debug:(name, iterator)->
		@log name, iterator
		switch typeof iterator
			when 'function'
				routine = Object.create @prototype
				@call(routine, iterator(routine), (@logger.start "#{name}:"))
			else
				routine = new Routine(iterator, (@logger.start "#{name}:"))
		routine.next()
	debug:@debug
	
	@start:(iterator)->
		return if !iterator.next?
		routine = new Routine(iterator, Routine.logger)
		routine.next()
	start:@start
	
	@run:(args...)->
		switch args.length
			when 1 then @start args...
			when 2 then @debug args...
	run:@run
	
	constructor:(@iterator, @logger)->
		@log = logger.log
		@throw = @iterator.throw.bind @iterator
		
	next:(nextvalue)->
		{@done, @value} = @iterator.next nextvalue
		if @done then @end?.next @value
		else @value this
		# this is where the magic happens -> return chain
		(@end)=> @end.next @value if @done

run = Routine.run.bind Routine

###
sleep = (time)->
	(wait)-> setTimeout (-> wait.log "slept for #{time} milliseconds"; wait.next()), time
run "t1", (routine)->
	routine.log "start"
	result = yield (wait)->
		wait.log "waiting for this to finish"
		wait.next 10
	routine.log "got " + result
	yield routine.run do ->
		log "wait"
		yield sleep 1000
	routine.log "finished"
###