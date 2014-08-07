var $, Http, Routine, WaitAll, log, run;

log = console.log.bind(console);

$ = document.querySelector.bind(document);

Routine = (function() {

  function Routine() {}

  Routine.run = function(iterator, onreturn) {
    var resume;
    if (onreturn == null) {
      onreturn = Routine["finally"];
    }
    resume = function(error, data) {
      var done, value, _ref;
      try {
        _ref = error ? iterator["throw"](error) : iterator.next(data), done = _ref.done, value = _ref.value;
        if (done) {
          return onreturn(void 0, value);
        } else if ((typeof (value != null ? value.next : void 0)) === 'function') {
          return Routine.run(value, resume);
        } else if ((typeof value) === 'function') {
          return value(resume);
        } else {
          log(value);
          throw new TypeError('iterator expected to return a callback or an iterator.');
        }
      } catch (exception) {
        log('throwing up');
        return onreturn(exception);
      }
    };
    return resume();
  };

  Routine["finally"] = function(error, value) {
    if (error) {
      throw error;
    } else {
      return value;
    }
  };

  return Routine;

})();

Routine.WaitAll = (function() {

  WaitAll.prototype.count = 1;

  function WaitAll() {
    this.resume = this.resume.bind(this);
    this.wait = this.wait.bind(this);
    this.all = this.all.bind(this);
  }

  WaitAll.prototype.resume = function(error, data) {
    if (error) {
      this.error = error;
      console.error(error.stack || error);
    }
    if (--this.count === 0) {
      this.onreturn(this.error);
    }
    return this.count;
  };

  WaitAll.prototype.wait = function(iterator) {
    ++this.count;
    try {
      if ((typeof iterator.next) === 'function') {
        return Routine.run(iterator, this.resume);
      } else {
        return iterator(this.resume);
      }
    } catch (exception) {
      return this.resume(exception);
    }
  };

  WaitAll.prototype.all = function(onreturn) {
    this.onreturn = onreturn;
    return this.resume();
  };

  return WaitAll;

})();

run = Routine.run, WaitAll = Routine.WaitAll;

Http = (function() {
  var json, raw;

  json = JSON.parse.bind(JSON);

  raw = function(text) {
    return text;
  };

  function Http(host) {
    var _, _ref;
    this.host = host;
    _ref = this.host.match(/^https:\/\/(.*)$/), _ = _ref[0], host = _ref[1];
    this.wshost = "wss://" + host;
  }

  Http.prototype.connect = function(url, data) {
    var _this = this;
    return function(callback) {
      var connection;
      connection = new WebSocket("" + _this.wshost + "/" + url + "/" + (_this.encode(data)));
      return connection.onopen = function() {
        return callback(void 0, connection);
      };
    };
  };

  Http.prototype.request = function(method, url, data) {
    return function(callback) {
      var request;
      request = new XMLHttpRequest();
      request.open(method, url);
      request.onreadystatechange = function() {
        var error;
        if (request.readyState === 4) {
          try {
            data = JSON.parse(request.responseText);
          } catch (exception) {
            return callback(exception);
          }
          if (request.status === 200) {
            return callback(void 0, data);
          } else {
            error = new (window[data.name] || Error)(data.message);
            error.name = data.name;
            return callback(error);
          }
        }
      };
      return request.send(data);
    };
  };

  Http.prototype.post = function(url, data) {
    return this.request('POST', "" + this.host + "/" + url, (function() {
      switch (typeof data) {
        case 'object':
          return this.encode(data);
        case 'string':
          return data;
      }
    }).call(this));
  };

  Http.prototype.get = function(url, data) {
    var querystring;
    querystring = (function() {
      switch (typeof data) {
        case 'object':
          return this.endcode(data);
        case 'string':
          return data;
        default:
          return '';
      }
    }).call(this);
    return this.request('GET', "" + this.host + "/" + url + querystring);
  };

  Http.prototype.encode = function(data) {
    var delimeter, key, result, value;
    if (data == null) {
      data = {};
    }
    result = '';
    delimeter = '?';
    for (key in data) {
      value = data[key];
      result += "" + delimeter + key + "=" + (encodeURIComponent(value));
      delimeter = '&';
    }
    return result;
  };

  return Http;

})();
