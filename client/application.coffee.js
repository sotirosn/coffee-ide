var Icon, loadApplicationUi,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Editor.js = (function(_super) {

  __extends(js, _super);

  function js() {
    var _this = this;
    log("js.editor.constructor");
    js.__super__.constructor.call(this);
    this.editor = new CodeMirror((function(window) {
      _this.window = window;
    }), {
      mode: 'javascript',
      lineNumbers: true,
      indentUnit: 4,
      tabSize: 4,
      indentWithTabs: true,
      autofocus: true
    });
    this.window.focus = function() {
      return _this.editor.focus();
    };
  }

  js.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value.replace(/\n( +)/g, function($0, $1) {
          return '\n' + $1.replace(/( {4})/g, '\t');
        }));
      },
      get: function() {
        return this.editor.getValue();
      }
    }
  });

  js.prototype.onload = function() {
    return this.editor.on('change', this.autosave);
  };

  js.prototype.toString = function() {
    var _ref;
    return "[editor.coffee: " + ((_ref = this.file) != null ? _ref.pathname : void 0) + "]";
  };

  return js;

})(Editor);

Editor.coffee = (function(_super) {

  __extends(coffee, _super);

  function coffee() {
    var _this = this;
    log("coffee.editor.constructor");
    coffee.__super__.constructor.call(this);
    this.editor = new CodeMirror((function(window) {
      _this.window = window;
    }), {
      mode: 'coffeescript',
      lineNumbers: true,
      indentUnit: 4,
      tabSize: 4,
      indentWithTabs: true,
      autofocus: true
    });
    this.window.focus = function() {
      return _this.editor.focus();
    };
  }

  coffee.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value.replace(/\n( +)/g, function($0, $1) {
          return '\n' + $1.replace(/( {4})/g, '\t');
        }));
      },
      get: function() {
        return this.editor.getValue();
      }
    }
  });

  coffee.prototype.onload = function() {
    return this.editor.on('change', this.autosave);
  };

  coffee.prototype.toString = function() {
    var _ref;
    return "[editor.coffee: " + ((_ref = this.file) != null ? _ref.pathname : void 0) + "]";
  };

  return coffee;

})(Editor);

Editor.html = (function(_super) {

  __extends(html, _super);

  function html() {
    var _this = this;
    log("html.editor.constructor");
    html.__super__.constructor.call(this);
    this.editor = new CodeMirror((function(window) {
      _this.window = window;
    }), {
      mode: 'htmlmixed',
      lineNumbers: true,
      indentUnit: 4,
      tabSize: 4,
      indentWithTabs: true,
      autofocus: true
    });
    this.window.focus = function() {
      return _this.editor.focus();
    };
  }

  html.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value.replace(/\n( +)/g, function($0, $1) {
          return '\n' + $1.replace(/( {4})/g, '\t');
        }));
      },
      get: function() {
        return this.editor.getValue();
      }
    }
  });

  html.prototype.onload = function() {
    return this.editor.on('change', this.autosave);
  };

  html.prototype.toString = function() {
    var _ref;
    return "[editor.coffee: " + ((_ref = this.file) != null ? _ref.pathname : void 0) + "]";
  };

  return html;

})(Editor);

Editor.css = (function(_super) {

  __extends(css, _super);

  function css() {
    var _this = this;
    log("css.editor.constructor");
    css.__super__.constructor.call(this);
    this.editor = new CodeMirror((function(window) {
      _this.window = window;
    }), {
      mode: 'css',
      lineNumbers: true,
      indentUnit: 4,
      tabSize: 4,
      indentWithTabs: true,
      autofocus: true
    });
    this.window.focus = function() {
      return _this.editor.focus();
    };
  }

  css.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value.replace(/\n( +)/g, function($0, $1) {
          return '\n' + $1.replace(/( {4})/g, '\t');
        }));
      },
      get: function() {
        return this.editor.getValue();
      }
    }
  });

  css.prototype.onload = function() {
    return this.editor.on('change', this.autosave);
  };

  css.prototype.toString = function() {
    var _ref;
    return "[editor.coffee: " + ((_ref = this.file) != null ? _ref.pathname : void 0) + "]";
  };

  return css;

})(Editor);

Icon = (function(_super) {

  __extends(Icon, _super);

  function Icon(label, action) {
    Icon.__super__.constructor.call(this, {
      icon: html('icon', label)
    });
    this.ui.icon.onclick = this.onclick(action);
  }

  return Icon;

})(UserInterface);

loadApplicationUi = function() {
  var ui;
  log('applicationui.load');
  ui = {
    window: window,
    toolbar: $('#toolbar'),
    content: $('#content iframe').contentWindow
  };
  global.projects = {
    server: './server',
    client: './client',
    site: './site'
  };
  run(function*(wait) {
    var directory, name, path, _ref, _results;
    _ref = global.projects;
    _results = [];
    for (name in _ref) {
      path = _ref[name];
      directory = {
        ui: {
          element: html('directory', htmlEncode(name))
        }
      };
      global.hierarchy.add(directory);
      try {
        _results.push(yield global.hierarchy.open(wait, path));
      } catch (error) {
        console.error(error);
        directory.ui.element.className = 'error';
        _results.push(directory.ui.element.innerHTML += ' - not found');
      }
    }
    return _results;
  });
  ui.toolbar.appendChild((new Icon('save', function*(wait) {
    var tab, _i, _len, _ref, _ref1;
    _ref = global.ide.ui.tablist;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      tab = _ref[_i];
      if ((_ref1 = tab.editor) != null ? _ref1.autosaving : void 0) {
        yield tab.editor.save(wait);
      }
    }
    log('saved all');
    return ui.window.location.reload();
  })).ui.icon);
  return ui.toolbar.appendChild((new Icon('preview', function*(wait) {
    var tab, _i, _len, _ref, _ref1;
    _ref = global.ide.ui.tablist;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      tab = _ref[_i];
      if ((_ref1 = tab.editor) != null ? _ref1.autosaving : void 0) {
        yield tab.editor.save(wait);
      }
    }
    log('saved all');
    return ui.content.location.reload();
  })).ui.icon);
};
