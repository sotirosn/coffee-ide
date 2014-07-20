exports.Generator = (->yield null).constructor
log = console.log.bind console

class Routine
	constructor:(@iterator, @onerror, @onreturn)->
	
	next:(nextvalue)->
		try
			{done, value} = @iterator.next nextvalue
			if !done then value @ else if @onreturn? then value? @onreturn
		catch exception
			@onerror exception
	
	throw:(exception)->
		console.error "unhappy async..\n #{exception}"
		# try to throw the exception
		# if the executing next() statement is in a try/catch it will catch the
		# exception first, otherwise the exception will bubble back to here and
		# we can handle it with @onerror
		try
			@iterator.throw exception
		catch exception
			@onerror exception

	run:(iterator)->
		(new Routine iterator, @onerror).next()
			
exports.Routine = Routine


exports.routine = (iterator)->
	(routine)->
		(new Routine iterator, routine.onerror, routine).next()