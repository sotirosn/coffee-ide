// Generated by CoffeeScript 1.3.3
var exports;

exports = (function() {

  function exports(iterator, _throw) {
    this.iterator = iterator;
    this["throw"] = _throw;
  }

  exports.prototype.next = function(nextvalue) {
    var done, value, _ref;
    try {
      _ref = this.iterator.next(nextvalue), done = _ref.done, value = _ref.value;
    } catch (exception) {
      return this["throw"](exception);
    }
    if (!done) {
      return value(this);
    }
  };

  return exports;

})();
