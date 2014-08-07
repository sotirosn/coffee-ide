var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

(function(_super) {

  __extends(_Class, _super);

  _Class.prototype.siteUrl = 'https://localhost:9080/?';

  function _Class() {
    var _this = this;
    log('new client project');
    _Class.__super__.constructor.apply(this, arguments);
    this.addButton('view', function*() {
      yield _this.saveAll();
      if (_this.view != null) {
        return _this.view.refresh();
      } else {
        _this.view = new ide.view(_this.siteUrl);
        return _this.view.tab = app.rightpane.createTab(_this.name, _this.view, function() {
          return delete _this.view;
        });
      }
    });
    this.addButton('update', function*() {
      var stderr, stdout, _ref;
      yield _this.saveAll();
      _ref = yield http.get("#update/{@path}"), stdout = _ref[0], stderr = _ref[1];
      return _this.log(stdout, stderr);
    });
  }

  _Class.prototype.log = function(stdout, stderr) {
    if (stdout) {
      console.log("" + this.name + "/> " + stdout);
    }
    if (stderr) {
      return console.error("" + this.name + "/> " + stderr);
    }
  };

  return _Class;

})(ide.project);
