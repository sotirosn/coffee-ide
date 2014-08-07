var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

(function(_super) {

  __extends(_Class, _super);

  _Class.prototype.siteUrl = 'https://localhost:8080/?';

  function _Class() {
    var _this = this;
    log('new client project');
    _Class.__super__.constructor.apply(this, arguments);
    this.addButton('run', function*() {
      var pid, _ref;
      yield _this.saveAll();
      if (_this.log) {
        _this.log.show();
      } else {
        log('new log');
        _this.log = new Log;
        _this.log.tab = app.rightpane.createTab('server', _this.log, function() {
          var _ref;
          if ((_ref = _this.connection) != null) {
            _ref.close();
          }
          return delete _this.connection;
        });
      }
      try {
        if ((_ref = _this.connection) != null) {
          _ref.close();
        }
        pid = yield http.get("run/" + _this.path);
        _this.connection = yield http.connect('.', {
          pid: pid
        });
        _this.connection.onmessage = function(_arg) {
          var data, type, _ref1;
          data = _arg.data;
          _ref1 = JSON.parse(data), type = _ref1.type, data = _ref1.data;
          switch (type) {
            case 'stdout':
              return _this.log.stdout(data);
            case 'stderr':
              return _this.log.stderr(data);
          }
        };
        return _this.connection.onclose = function(event) {
          log(event);
          _this.log.stdout("connection closed: " + event.data);
          return delete _this.connection;
        };
      } catch (exception) {
        return _this.log.error(exception);
      }
    });
    this.addButton('update', function*() {
      var stderr, stdout, _ref;
      yield _this.saveAll();
      _ref = yield http.get("update/" + _this.path), stdout = _ref[0], stderr = _ref[1];
      return _this.log(stdout, stderr);
    });
  }

  return _Class;

})(ide.project);
