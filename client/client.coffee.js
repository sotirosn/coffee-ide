var $, Editor, File, FileElement, FileServer, Global, Hierarchy, Http, IDE, Tab, Type, UserInterface, error, global, html, htmlEncode, log, run, skip,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

console.clear();

log = console.log.bind(console);

error = console.error.bind(console);

$ = document.querySelector.bind(document);

Global = (function() {

  function Global() {}

  Global.prototype.error = function(error) {
    throw error;
  };

  return Global;

})();

global = Global.prototype;

Type = (function(_super) {

  __extends(Type, _super);

  function Type() {
    return Type.__super__.constructor.apply(this, arguments);
  }

  Type.properties = function(properties) {
    return Object.defineProperties(this.prototype, properties);
  };

  return Type;

})(Global);

html = function(tagname, innerHTML) {
  var element;
  if (innerHTML == null) {
    innerHTML = '';
  }
  element = document.createElement(tagname);
  element.innerHTML = innerHTML;
  return element;
};

htmlEncode = function(string) {
  return string.replace(/[\u00A0-\u9999<>\&]/gim, function($0) {
    return "&#" + ($0.charCodeAt(0)) + ";";
  });
};

run = function() {
  var args, iterator, wait, _ref;
  iterator = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  wait = function(value) {
    return iterator.next(value);
  };
  wait["throw"] = function(error) {
    log('throw ' + error);
    return iterator["throw"](error);
  };
  return (_ref = (iterator = iterator.apply(null, [wait].concat(__slice.call(args))))) != null ? typeof _ref.next === "function" ? _ref.next() : void 0 : void 0;
};

UserInterface = (function(_super) {

  __extends(UserInterface, _super);

  function UserInterface(ui) {
    this.ui = ui;
  }

  UserInterface.prototype.bind = function(method) {
    return method.bind(this);
  };

  UserInterface.prototype.action = function(iterator) {
    var name;
    if (typeof iterator === 'object') {
      iterator = iterator[name = Object.keys(iterator)[0]];
      name = "" + this + "." + name;
    } else {
      name = "" + this;
    }
    iterator = iterator.bind(this);
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      log.apply(null, ["on " + name + ":"].concat(__slice.call(args)));
      return run.apply(null, [iterator].concat(__slice.call(args)));
    };
  };

  UserInterface.prototype.onclick = function(iterator) {
    var name;
    if (typeof iterator === 'object') {
      iterator = iterator[name = Object.keys(iterator)[0]];
      name = "" + this + "." + name;
    } else {
      name = "" + this;
    }
    iterator = iterator.bind(this);
    return function(event) {
      log("onclick " + name);
      run(iterator, event);
      event.stopPropagation();
      event.preventDefault();
      return false;
    };
  };

  UserInterface.prototype.actions = function(iterators) {
    var iterator, key, _results;
    _results = [];
    for (key in itertors) {
      iterator = itertors[key];
      _results.push(this[key] = action(iterator));
    }
    return _results;
  };

  return UserInterface;

})(Type);

Http = (function(_super) {

  __extends(Http, _super);

  Http.Error = (function(_super1) {

    __extends(Error, _super1);

    function Error() {
      return Error.__super__.constructor.apply(this, arguments);
    }

    return Error;

  })(Error);

  function Http(host) {
    this.host = host;
  }

  Http.prototype.error = function(onread, message) {
    if (onread["throw"]) {
      return onread["throw"](new Http.Error(message));
    } else {
      throw new Http.Error(message);
    }
  };

  Http.prototype.get = function(onread, path, data) {
    var request, url,
      _this = this;
    url = this.host + path + this.encode(data);
    request = new XMLHttpRequest;
    request.open('GET', url);
    request.onreadystatechange = function() {
      if (request.readyState === 4) {
        if (request.status === 200) {
          return onread(JSON.parse(request.responseText));
        } else {
          return _this.error(onread, request.responseText);
        }
      }
    };
    return request.send();
  };

  Http.prototype.post = function(onread, path, data, value) {
    var request, url,
      _this = this;
    url = this.host + path + this.encode(data);
    request = new XMLHttpRequest;
    request.open('POST', url);
    request.onreadystatechange = function() {
      if (request.readyState === 4) {
        if (request.status === 200) {
          return onread(JSON.parse(request.responseText));
        } else {
          return _this.error(onread, request.responseText);
        }
      }
    };
    return request.send(value);
  };

  Http.prototype.socket = function(onread, host) {
    var socket;
    if (host == null) {
      host = 'ws://localhost:8081';
    }
    socket = new WebSocket(host);
    return socket.onmessage(function(event) {
      return onread(event.data);
    });
  };

  Http.prototype.encode = function(data) {
    var key, next, result, value;
    result = '';
    next = '?';
    for (key in data) {
      value = data[key];
      result += next + encodeURI(key + '=' + encodeURI(value));
      next = '&';
    }
    return result;
  };

  return Http;

})(Global);

FileServer = (function() {

  function FileServer(url) {
    this.http = new Http(url);
  }

  FileServer.prototype.readdir = function(read, path) {
    return this.http.get(read, '/readdir', {
      path: path
    });
  };

  FileServer.prototype.readfile = function(read, filepath) {
    return this.http.get(read, '/readfile', {
      filepath: filepath
    });
  };

  FileServer.prototype.writefile = function(read, filepath, value) {
    return this.http.post(read, '/writefile', {
      filepath: filepath
    }, value);
  };

  return FileServer;

})();

File = (function(_super) {

  __extends(File, _super);

  function File(path, filename) {
    var _ref;
    this.path = path;
    this.filename = filename;
    this.pathname = path + '/' + filename;
    log('file.constructor: ' + this.pathname);
    this.filetype = ((_ref = filename.match(/[.](.+)$/)) != null ? _ref[1] : void 0) || '';
  }

  File.prototype.read = function(wait) {
    log('file.read: ' + this.pathname);
    return this.fs.readfile(wait(this.pathname));
  };

  File.prototype.write = function(wait, value) {
    log('file.write: ' + this.pathname);
    return this.fs.writefile(this.pathname, value);
  };

  File.prototype.rename = function(wait, name) {
    log('file.rename: ' + this.pathname);
    return this.fs.renamefile(wait(this.pathname, name));
  };

  return File;

})(Global);

FileElement = (function(_super) {

  __extends(FileElement, _super);

  function FileElement(path, filename) {
    File.call(this, path, filename);
    UserInterface.call(this, {
      element: html('element'),
      label: html('label', filename),
      openclick: this.onclick({
        open: this.open
      })
    });
    this.ui.element.appendChild(this.ui.label);
    this.ui.element.onclick = this.ui.openclick;
  }

  FileElement.properties({
    label: {
      set: function(value) {
        var _ref;
        if ((_ref = this.tab) != null) {
          _ref.name = value;
        }
        return this.ui.label.innerHTML = value;
      }
    }
  });

  FileElement.prototype.open = function(wait, editor) {
    var _this = this;
    log('file(element).open: ' + this.pathname);
    editor = new (Editor[this.filetype] || Editor.text);
    editor.tab = this.ide.createTab(this.filename, editor.window);
    editor.tab.editor = editor;
    editor.tab.onclose = this.action({
      onclose: function*(wait, resume) {
        resume((yield editor.close(wait)));
        return _this.ui.element.onclick = _this.ui.openclick;
      }
    });
    this.ui.element.onclick = function() {
      return editor.tab.focus();
    };
    return editor.load(this);
  };

  FileElement.prototype.toString = function() {
    return "[file: " + this.pathname + "]";
  };

  return FileElement;

})(__extends(File, UserInterface));

Hierarchy = (function(_super) {

  __extends(Hierarchy, _super);

  Hierarchy.prototype.toString = function() {
    return 'hierarchy';
  };

  function Hierarchy() {
    log("hierarchy.constructor");
    Hierarchy.__super__.constructor.call(this, {
      container: $('#hierarchy')
    });
    this.open = this.action({
      open: this.open
    });
    log("done");
  }

  Hierarchy.prototype.open = function*(wait, resume, path) {
    var filelist;
    if (resume == null) {
      resume = skip;
    }
    log('hiererchy.open:', path);
    wait["throw"] = resume["throw"];
    filelist = (yield this.fs.readdir(wait, path));
    this.asFilelist(path, filelist);
    return resume(this);
  };

  Hierarchy.prototype.asFilelist = function(path, filelist) {
    var filename, _i, _len;
    this.filelist = filelist;
    log('hiererchy.filelist');
    for (_i = 0, _len = filelist.length; _i < _len; _i++) {
      filename = filelist[_i];
      this.add(new FileElement(path, filename));
    }
    return $('#main').style.left = (this.ui.container.offsetWidth + 10) + 'px';
  };

  Hierarchy.prototype.add = function(element) {
    return this.ui.container.appendChild(element.ui.element);
  };

  return Hierarchy;

})(UserInterface);

IDE = (function() {

  function IDE() {
    log('ide.constructor');
    this.ui = {
      tablist: [],
      tabs: $('#tabs'),
      windows: $('#windows')
    };
    this.ui.tablist.remove = function(tab) {
      var _ref;
      if (tab === this.focused) {
        this.focused = void 0;
      }
      this.splice(this.indexOf(tab), 1);
      if (!this.focused) {
        return (_ref = this[0]) != null ? _ref.focus() : void 0;
      }
    };
  }

  IDE.prototype.createTab = function(label, window) {
    var tab;
    log("new tab: " + label);
    tab = new Tab(this.ui, label, window);
    this.ui.tablist.push(tab);
    this.ui.tabs.appendChild(tab.ui.tab);
    this.ui.windows.appendChild(tab.ui.window);
    tab.focus();
    return tab;
  };

  return IDE;

})();

Tab = (function(_super) {

  __extends(Tab, _super);

  Tab.properties({
    label: {
      get: function() {
        return this.label_;
      },
      set: function(label_) {
        this.label_ = label_;
        return this.ui.label.innerHTML = label_;
      }
    }
  });

  function Tab(container, label, window) {
    this.container = container;
    log('tab.constructor');
    this.ui = {
      tab: html('tab'),
      label: html('label'),
      close: html('close', 'x'),
      window: window || html('div')
    };
    this.ui.tab.appendChild(this.ui.label);
    this.ui.tab.appendChild(this.ui.close);
    this.ui.close.onclick = this.onclick(this.close);
    this.ui.tab.onclick = this.onclick(this.focus);
    this.label = label;
  }

  Tab.prototype.close = function*(wait) {
    var _ref;
    log("tab.close");
    if (this.onclose != null) {
      yield this.onclose(wait);
    }
    if ((_ref = this.container.tablist.remove(this)) != null) {
      _ref.focus();
    }
    this.container.tabs.removeChild(this.ui.tab);
    return this.container.windows.removeChild(this.ui.window);
  };

  Tab.prototype.focus = function() {
    log("tab.focus");
    if (this.container.focused === this) {
      return;
    }
    if (this.container.focused) {
      this.container.focused.blur();
    }
    this.container.focused = this;
    this.ui.tab.className = 'active';
    this.ui.window.removeAttribute('hidden');
    return this.ui.window.focus();
  };

  Tab.prototype.blur = function() {
    log("tab.blur");
    this.ui.tab.className = '';
    return this.ui.window.setAttribute('hidden', 1);
  };

  return Tab;

})(UserInterface);

Editor = (function(_super) {

  __extends(Editor, _super);

  function Editor() {
    log("editor.constructor");
    this.load = this.action({
      load: this.load
    });
    this.save = this.action({
      save: this.save
    });
    this.close = this.action({
      close: this.close
    });
    this.autosave = this.bind(this.autosave);
  }

  Editor.prototype.load = function*(wait, file) {
    this.file = file;
    log("editor.load: " + file.pathname);
    this.value = yield this.fs.readfile(wait, file.pathname);
    return typeof this.onload === "function" ? this.onload() : void 0;
  };

  Editor.prototype.autosaveDelay = 30000;

  Editor.prototype.autosave = function() {
    var _ref,
      _this = this;
    if (this.autosaving) {
      return;
    }
    log("autosaving", this.file);
    if ((_ref = this.tab) != null) {
      _ref.label += "*";
    }
    return this.autosaving = setTimeout((function() {
      _this.autosaving = false;
      return _this.save();
    }), this.autosaveDelay);
  };

  Editor.prototype.save = function*(wait, resume) {
    if (resume == null) {
      resume = skip;
    }
    log("saving: " + this.file.pathname);
    if (this.autosaving) {
      clearTimeout(this.autosaving);
      this.autosaving = false;
    }
    resume((yield this.fs.writefile(wait, this.file.pathname, this.value)));
    return this.tab.label = this.file.filename;
  };

  Editor.prototype.close = function*(wait, resume) {
    if (resume == null) {
      resume = skip;
    }
    log("closing: " + this.file.pathname);
    if (this.autosaving) {
      return resume((yield this.save(wait)));
    } else {
      return setTimeout((function() {
        return resume();
      }), 0);
    }
  };

  Editor.prototype.toString = function() {
    var _ref;
    return "[editor: " + ((_ref = this.file) != null ? _ref.pathname : void 0) + "]";
  };

  return Editor;

})(UserInterface);

Editor.text = (function(_super) {

  __extends(text, _super);

  function text() {
    log("text.editor.constructor");
    text.__super__.constructor.call(this);
    this.editor = this.window = html('textarea');
  }

  text.properties({
    value: {
      set: function(value) {
        return this.editor.value = value;
      },
      get: function() {
        return this.editor.value;
      }
    }
  });

  text.prototype.onload = function() {
    return this.editor.onkeyup = this.editor.onchange = this.autosave;
  };

  return text;

})(Editor);

skip = function() {};

this.onload = function() {
  log("window.onload");
  global.fs = new FileServer('.');
  global.ide = new IDE;
  global.hierarchy = new Hierarchy;
  return typeof loadApplicationUi === "function" ? loadApplicationUi() : void 0;
};
