var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ide.iframe = (function(_super) {

  __extends(iframe, _super);

  function iframe() {
    return iframe.__super__.constructor.apply(this, arguments);
  }

  iframe.html('<iframe></iframe>');

  iframe.properties({
    label: {
      set: function(value) {
        var _ref;
        return (_ref = this.tab) != null ? _ref.label = value : void 0;
      }
    },
    location: {
      set: function(value) {
        return this.element.src = value;
      }
    }
  });

  iframe.prototype.open = function(url) {
    var _this = this;
    this.element.src = url;
    return function(routine) {
      return _this.element.onload(function() {
        var title;
        title = _this.element.querySelector('title');
        _this.label = (title != null ? title.innerHTML : void 0) || url;
        return routine.next();
      });
    };
  };

  iframe.create = function(label) {
    var iframe;
    iframe = new ide.iframe;
    iframe.tab = app.rightpane.createTab(label, iframe);
    return iframe;
  };

  return iframe;

})(ide.html);

ide.console = (function(_super) {
  var stderr, stdout;

  __extends(console, _super);

  function console() {
    return console.__super__.constructor.apply(this, arguments);
  }

  stdout = (function(_super1) {

    __extends(stdout, _super1);

    stdout.html('<pre class="stdout"></pre>');

    function stdout(text) {
      stdout.__super__.constructor.call(this);
      this.element.innerHTML = text;
    }

    return stdout;

  })(ide.html);

  stderr = (function(_super1) {

    __extends(stderr, _super1);

    stderr.html('<pre class="stderr"></pre>');

    function stderr(text) {
      stderr.__super__.constructor.call(this);
      this.element.innerHTML = text;
    }

    return stderr;

  })(ide.html);

  console.html('<console></console>');

  console.properties({
    label: {
      set: function(value) {
        var _ref;
        return (_ref = this.tab) != null ? _ref.label = value : void 0;
      }
    }
  });

  console.prototype.connect = function(pid) {
    var _ref,
      _this = this;
    this.pid = pid;
    if ((_ref = this.connection) != null) {
      _ref.close();
    }
    this.connection = ws.open({
      pid: this.pid
    });
    this.connection.onclose = function(event) {
      log(event);
      _this.info("(" + _this.pid + ") connection closed.");
      return delete _this.connection;
    };
    this.connection.onerror = function(event) {
      return console.error(event);
    };
    this.connection.onmessage = function(_arg) {
      var data, key, message, _ref1, _results;
      data = _arg.data;
      _ref1 = JSON.parse(data);
      _results = [];
      for (key in _ref1) {
        message = _ref1[key];
        switch (key) {
          case stdout:
            _results.push(_this.stdout(message));
            break;
          case stderr:
            _results.push(_this.stderr(message));
            break;
          default:
            _results.push(_this.output("" + key + ": " + message));
        }
      }
      return _results;
    };
    return function(routine) {
      return this.connection.onopen = function() {
        return routine.next();
      };
    };
  };

  console.prototype.output = function(text) {
    var element;
    element = document.createElement('pre');
    element.innerHTML = text;
    return this.element.appendChild(element);
  };

  console.prototype.stdout = function(text) {
    return this.element.appendChild((new stdout(text)).element);
  };

  console.prototype.stderr = function(text) {
    return this.element.appendChild((new stderr(text)).element);
  };

  console.create = function(label) {
    var console;
    console = new ide.console;
    console.tab = app.rightpane.createTab(label, console);
    return console;
  };

  return console;

}).call(this, ide.html);
