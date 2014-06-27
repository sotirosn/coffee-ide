var Logger, Routine, log, run,
  __slice = [].slice;

log = console.log.bind(console);

Logger = (function() {

  function Logger(log) {
    this.log = log != null ? log : console.log.bind(console);
  }

  Logger.prototype.start = function(name) {
    return new Logger(this.log.bind(console, "" + name));
  };

  return Logger;

})();

Routine = (function() {

  Routine.logger = new Logger;

  Routine.log = Routine.logger.log;

  Routine.debug = function(name, iterator) {
    var routine;
    this.log(name, iterator);
    switch (typeof iterator) {
      case 'function':
        routine = Object.create(this.prototype);
        this.call(routine, iterator(routine), this.logger.start("" + name + ":"));
        break;
      default:
        routine = new Routine(iterator, this.logger.start("" + name + ":"));
    }
    return routine.next();
  };

  Routine.prototype.debug = Routine.debug;

  Routine.start = function(iterator) {
    var routine;
    if (!(iterator.next != null)) {
      return;
    }
    routine = new Routine(iterator, Routine.logger);
    return routine.next();
  };

  Routine.prototype.start = Routine.start;

  Routine.run = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    switch (args.length) {
      case 1:
        return this.start.apply(this, args);
      case 2:
        return this.debug.apply(this, args);
    }
  };

  Routine.prototype.run = Routine.run;

  function Routine(iterator, logger) {
    this.iterator = iterator;
    this.logger = logger;
    this.log = logger.log;
    this["throw"] = this.iterator["throw"].bind(this.iterator);
  }

  Routine.prototype.next = function(nextvalue) {
    var _ref, _ref1,
      _this = this;
    _ref = this.iterator.next(nextvalue), this.done = _ref.done, this.value = _ref.value;
    if (this.done) {
      if ((_ref1 = this.end) != null) {
        _ref1.next(this.value);
      }
    } else {
      this.value(this);
    }
    return function(end) {
      _this.end = end;
      if (_this.done) {
        return _this.end.next(_this.value);
      }
    };
  };

  return Routine;

})();

run = Routine.run.bind(Routine);

/*
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
*/

