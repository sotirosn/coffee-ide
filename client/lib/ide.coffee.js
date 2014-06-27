var $, Generator, Http, app, error, http, ide, info, log, onclick, sleep, stdlog,
  __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

$ = document.querySelector.bind(document);

log = console.log.bind(console);

info = console.info.bind(console);

error = console.error.bind(console);

Generator = (function*() {
  return yield void 0;
}).constructor;

stdlog = function(_arg) {
  var stderr, stdout;
  stdout = _arg[0], stderr = _arg[1];
  if (stdout) {
    log(stdout);
  }
  if (stderr) {
    return error(stderr);
  }
};

onclick = function(iterator) {
  return function(event) {
    event.stopPropagation();
    event.preventDefault();
    return run(iterator);
  };
};

Http = (function() {

  Http.prototype.debug = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return log.apply(null, args);
  };

  function Http(host) {
    this.host = host != null ? host : '';
    if (this.host.length > 0 && this.host[this.host.length - 1] !== '/') {
      this.debug(this.host += '/');
    }
  }

  Http.prototype.urlencode = function(data) {
    var delimeter, key, result, value;
    result = '';
    delimeter = '?';
    for (key in data) {
      value = data[key];
      result += delimeter + urlencode(key) + '=' + urlencode(value);
      delimeter = '&';
    }
    return result;
  };

  Http.prototype.get = function(path, data) {
    var url;
    url = this.host + path + this.urlencode(data);
    this.debug("GET " + url);
    return function(wait) {
      var request,
        _this = this;
      request = new XMLHttpRequest;
      request.open('GET', url);
      request.onreadystatechange = function() {
        if (request.readyState === 4) {
          if (request.status === 200) {
            return wait.next(JSON.parse(request.responseText));
          } else {
            return wait["throw"](request.responseText);
          }
        }
      };
      return request.send();
    };
  };

  Http.prototype.post = function() {
    var args, data, path, url, value;
    path = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    data = (typeof args[0] === 'object' ? args[0] : void 0);
    value = (typeof args[0] === 'string' ? args[0] : void 0);
    if (args.length === 2) {
      if (data == null) {
        data = (typeof args[1] === 'object' ? args[1] : void 0);
      }
      if (value == null) {
        value = (typeof args[1] === 'string' ? args[1] : void 0);
      }
    }
    url = this.host + path + this.urlencode(data);
    this.debug("POST " + url);
    return function(wait) {
      var request,
        _this = this;
      request = new XMLHttpRequest;
      request.open('POST', url);
      request.onreadystatechange = function() {
        if (request.readyState === 4) {
          if (request.status === 200) {
            return wait.next(JSON.parse(request.responseText));
          } else {
            return wait["throw"](request.responseText);
          }
        }
      };
      return request.send(value);
    };
  };

  return Http;

})();

app = null;

http = new Http('http://localhost:8090');

sleep = function(time) {
  return function(wait) {
    log("sleeping for " + time + " milliseconds");
    return setTimeout((function() {
      return wait.next(time);
    }), time);
  };
};

ide = (function() {

  function ide() {}

  ide.load = function*() {
    var projectlist, projectname, _i, _len, _results;
    projectlist = yield http.get('listdir');
    _results = [];
    for (_i = 0, _len = projectlist.length; _i < _len; _i++) {
      projectname = projectlist[_i];
      _results.push(this.hierarchy.addProject(projectname));
    }
    return _results;
  };

  ide.openLocation = function(location) {
    var iframe;
    iframe = new html.iframe(location);
    iframe.tab = this.rightpane.createTab(location, iframe.element);
    return iframe;
  };

  return ide;

})();

ide.hierarchy = (function(_super) {

  __extends(hierarchy, _super);

  function hierarchy() {
    return hierarchy.__super__.constructor.apply(this, arguments);
  }

  hierarchy.prototype.html = new html('hierarchy');

  hierarchy.prototype.addProject = function(projectname) {
    var project;
    project = new ide.hierarchy.project(projectname);
    this.element.appendChild(project.element);
    return project;
  };

  hierarchy.prototype.remove = function(element) {
    return this.element.removeChild(element.element);
  };

  return hierarchy;

})(html.element);

ide.hierarchy.element = (function(_super) {

  __extends(element, _super);

  element.prototype.html = new html('element', '<label></label>');

  element.prototype.type = 'element';

  element.properties({
    pathname: {
      get: function() {
        return "" + this.parent.pathname + "/" + this.name;
      }
    },
    label: {
      set: function(value) {
        return this.html.label.innerHTML = value;
      }
    }
  });

  function element(project, parent, name) {
    var _this = this;
    this.project = project;
    this.parent = parent;
    this.name = name;
    element.__super__.constructor.call(this);
    this.label = name;
    this.element.addEventListener('contextmenu', function(event) {
      return app.contextmenu.display(_this, event);
    });
  }

  element.prototype.rename = function*(name) {
    if (name === this.name) {
      return;
    }
    yield http.get("rename/" + this.pathname + "?name=" + name);
    console.log("renamed " + name);
    return this.label = this.name = name;
  };

  return element;

})(html.element);

ide.hierarchy.directory = (function(_super) {

  __extends(directory, _super);

  directory.prototype.html = new html('directory', '<label></label><div class="directories"></div><div class="files"></div>', {
    directories: 'div.directories',
    files: 'div.files',
    label: 'label'
  });

  directory.prototype.type = 'directory';

  function directory() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    directory.__super__.constructor.apply(this, args);
    this.html.label.onclick = this.onclick(this.toggleOpenClose);
  }

  directory.prototype.open = function*() {
    var filelist, name, type;
    filelist = yield http.get("listdir/" + this.pathname);
    for (name in filelist) {
      type = filelist[name];
      switch (type) {
        case 'dir':
          this.addDirectory(name);
          break;
        case 'file':
          this.addFile(name);
      }
    }
    this.element.setAttribute('expanded', true);
    return this.expanded = true;
  };

  directory.prototype.close = function() {
    this.html.directories.innerHTML = '';
    this.html.files.innerHTML = '';
    this.element.removeAttribute('expanded');
    return this.expanded = false;
  };

  directory.prototype.createDirectory = function*(name) {
    yield http.get("mkdir/" + this.pathname + "/" + name);
    return this.addDirectory(name);
  };

  directory.prototype.createFile = function*(name) {
    yield http.post("writefile/" + this.pathname + "/" + name, '');
    return this.addFile(name);
  };

  directory.prototype.addDirectory = function(name) {
    var directory;
    directory = new ide.hierarchy.directory(this.project, this, name);
    this.html.directories.appendChild(directory.element);
    return directory;
  };

  directory.prototype.addFile = function(name) {
    var file;
    file = new ide.hierarchy.file(this.project, this, name);
    this.html.files.appendChild(file.element);
    return file;
  };

  directory.prototype.removeDirectory = function(directory) {
    return this.html.directories.removeChild(directory.element);
  };

  directory.prototype.removeFile = function(file) {
    return this.html.files.removeChild(file.element);
  };

  directory.prototype.toggleOpenClose = function*() {
    if (this.expanded) {
      return this.close();
    } else {
      return yield run("" + name + ".open", this.open());
    }
  };

  directory.prototype.remove = function() {
    return this.parent.removeDirectory(this);
  };

  return directory;

})(ide.hierarchy.element);

ide.hierarchy.project = (function(_super) {

  __extends(project, _super);

  project.prototype.html = new html('project', '<label></label><div class="directories"></div><div class="files"></div>', {
    directories: 'div.directories',
    files: 'div.files',
    label: 'label'
  });

  project.prototype.type = 'project';

  project.properties({
    pathname: {
      get: function() {
        return this.name;
      }
    }
  });

  function project(name) {
    var _this = this;
    log("project added: " + name);
    project.__super__.constructor.call(this, this, this, name);
    this.editors = [];
    run((function*() {
      var script;
      script = yield http.get("readfile/" + _this.pathname + "/.project.coffee.js");
      return (eval(script))(_this);
    })());
  }

  project.prototype.save = function*() {
    var editor, _i, _len, _ref, _results;
    _ref = this.editors;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      editor = _ref[_i];
      if (editor.unsaved) {
        _results.push(yield run(editor.save()));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  project.prototype.remove = function() {
    return app.hierarchy.remove(this);
  };

  project.prototype.addIcon = function(label, routine) {
    var icon;
    icon = new html.icon(label, this.onclick(routine));
    this.html.label.appendChild(icon.element);
    return icon;
  };

  return project;

})(ide.hierarchy.directory);

ide.hierarchy.file = (function(_super) {

  __extends(file, _super);

  file.prototype.html = new html('file', '<label></label>', {
    label: 'label'
  });

  file.prototype.type = 'file';

  function file() {
    var args,
      _this = this;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    file.__super__.constructor.apply(this, args);
    this.name.replace(/[^.]+$/, function(extension) {
      _this.extension = extension;
    });
    this.element.onclick = this.onclick(this.edit);
  }

  file.prototype.write = function(data) {
    return http.post("writefile/" + this.pathname, data);
  };

  file.prototype.read = function() {
    return http.get("readfile/" + this.pathname);
  };

  file.prototype.edit = function*() {
    var filedata;
    if (this.editor) {
      return this.editor.tab.focus();
    } else {
      filedata = yield this.read();
      this.editor = new ide.hierarchy.file.editor(this, filedata);
      this.editor.tab = app.leftpane.createTab(this.name, this.editor.element, this.editor.close.bind(this.editor));
      return this.project.editors.push(this.editor);
    }
  };

  file.prototype.createHTML = function() {
    return html('element', {
      onclick: onclick(this.edit)
    }, [html('label', this.file.name)]);
  };

  file.prototype.remove = function() {
    return this.parent.removeFile(this);
  };

  return file;

})(ide.hierarchy.element);

ide.hierarchy.file.editor = (function(_super) {

  __extends(editor, _super);

  editor.extensions = {
    'js': 'javascript',
    'css': 'css',
    'xml': 'xml',
    'txt': 'text',
    'html': 'htmlmixed',
    'coffee': 'coffeescript'
  };

  editor.properties({
    tab: {
      set: function(value) {
        this.tab_ = value;
        return this.editor.refresh();
      },
      get: function() {
        return this.tab_;
      }
    },
    unsaved: {
      set: function(value) {
        this.unsaved_ = value;
        return this.tab.label = this.file.name + (value ? '*' : '');
      },
      get: function() {
        return this.unsaved_;
      }
    }
  });

  function editor(file, data) {
    var _this = this;
    this.file = file;
    this.editor = new CodeMirror((function(element) {
      _this.element = element;
    }), {
      mode: ide.hierarchy.file.editor.extensions[this.file.extension] || 'text',
      lineNumbers: true,
      indentUnit: 4,
      tabSize: 4,
      indentWithTabs: true,
      autofocus: true,
      value: data.replace(/^[ ]+/gm, function(leadingSpace) {
        return leadingSpace.replace(/[ ]{4}/g, '\t');
      })
    });
    this.editor.on('change', this.bind(this.onchange));
    this.element.focus = this.editor.focus.bind(this.editor);
  }

  editor.prototype.autosaveDelay = 30000;

  editor.prototype.onchange = function() {
    var _this = this;
    if (this.unsaved) {
      return;
    }
    return this.unsaved = setTimeout((function() {
      return run(_this.save(false));
    }), this.autosaveDelay);
  };

  editor.prototype.save = function*(unsaved) {
    var stderr, stdout, _ref;
    this.unsaved = unsaved != null ? unsaved : this.unsaved;
    if (this.unsaved) {
      clearTimeout(this.unsaved);
      this.unsaved = false;
    }
    return stdlog((_ref = yield this.file.write(this.editor.getValue()), stdout = _ref[0], stderr = _ref[1], _ref));
  };

  editor.prototype.close = function*() {
    if (this.unsaved) {
      yield run('editor.save', this.save());
    }
    return delete this.file.editor;
  };

  return editor;

})(html.element);

ide.hierarchy.contextmenu = (function(_super) {

  __extends(contextmenu, _super);

  contextmenu.prototype.placeholder = new html('file', '<input/>', {
    input: 'input'
  });

  contextmenu.prototype.input = document.createElement('input');

  function contextmenu() {
    contextmenu.__super__.constructor.call(this);
    this.addMenuItem('New File', this.bind(this.createFile));
    this.addMenuItem('New Directory', this.bind(this.createDirectory));
    this.addMenuItem('Rename', this.bind(this.rename));
    this.addMenuItem('Delete', this.bind(this["delete"]));
  }

  contextmenu.prototype.rename = function(target) {
    var element;
    element = target.element;
    element.insertBefore(this.input, target.html.label);
    target.html.label.setAttribute('hidden', true);
    this.input.focus();
    this.input.value = target.name;
    this.input.onchange = function() {
      element.removeChild(this);
      target.html.label.removeAttribute('hidden');
      return run(target.rename(this.value));
    };
    return this.input.onblur = function() {
      element.removeChild(this);
      return target.html.label.removeAttribute('hidden');
    };
  };

  contextmenu.prototype.createFile = function(target) {
    var directory, input,
      _this = this;
    if (!(target instanceof ide.hierarchy.directory)) {
      target = target.parent;
    }
    directory = target.html.directories;
    directory.insertBefore(this.placeholder.element, directory.firstChild);
    input = this.placeholder.html.input;
    input.value = '';
    input.placeholder = 'new file';
    input.onchange = function() {
      directory.removeChild(_this.placeholder.element);
      return run(target.createFile(input.value));
    };
    input.onblur = function() {
      return directory.removeChild(_this.placeholder.element);
    };
    return input.focus();
  };

  contextmenu.prototype.createDirectory = function(target) {
    var directory, input,
      _this = this;
    if (!(target instanceof ide.hierarchy.directory)) {
      target = target.parent;
    }
    directory = target.html.directories;
    directory.insertBefore(this.placeholder.element, directory.firstChild);
    input = this.placeholder.html.input;
    input.value = '';
    input.placeholder = 'new directory';
    input.onchange = function() {
      directory.removeChild(_this.placeholder.element);
      return run(target.createDirectory(input.value));
    };
    input.onblur = function() {
      return directory.removeChild(_this.placeholder.element);
    };
    return input.focus();
  };

  contextmenu.prototype["delete"] = function*(target) {
    if (confirm("Are you sure you want to delete " + target.type + " " + target.pathname + "?")) {
      yield http.get("delete/" + target.pathname);
      return this.target.remove();
    }
  };

  return contextmenu;

})(html.contextmenu);

this.onload = function() {
  var logger;
  logger = new html.log;
  error = logger.error.bind(logger);
  stdlog = logger.stdlog.bind(logger);
  app = (function(_super) {

    __extends(app, _super);

    function app() {
      return app.__super__.constructor.apply(this, arguments);
    }

    app.contextmenu = new ide.hierarchy.contextmenu;

    app.toolbar = new html.toolbar($('toolbar'));

    app.hierarchy = new ide.hierarchy($('hierarchy'));

    app.leftpane = new html.tabarea($('tabarea#leftpane'));

    app.rightpane = new html.tabarea($('tabarea#rightpane'));

    return app;

  })(ide);
  document.body.appendChild(app.contextmenu.element);
  app.rightpane.createTab('log', logger.element);
  return run("app.load", app.load());
};
