var app, http, ide,
  __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ide = (function() {

  function ide(object) {
    var key, value,
      _this = this;
    for (key in object) {
      value = object[key];
      this[key] = value;
    }
    run((function*() {
      var projectlist;
      try {
        projectlist = yield http.get('');
      } catch (exception) {
        console.error(exception);
        _this.login.show();
      }
      return _this.hierarchy.load(projectlist);
    })());
  }

  ide.prototype.login = function*(username, password) {
    var projectlist;
    projectlist = yield http.post('', {
      username: username,
      password: password
    });
    return this.load(projectlist);
  };

  return ide;

})();

ide.html = (function() {
  var dom;

  dom = document.createElement('div');

  html.properties = function(properties) {
    return Object.defineProperties(this.prototype, properties);
  };

  html.html = function(htmlstring) {
    dom.innerHTML = htmlstring;
    this.element = dom.firstChild;
    return log("declare", this.element);
  };

  html.components = {};

  html.onclick = function(method) {
    if (method.isGenerator()) {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        run(method(event));
        return false;
      };
    } else {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        method(event);
        return false;
      };
    }
  };

  html.prototype.onclick = function(method) {
    var _this = this;
    if (method.isGenerator()) {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        run(method.call(_this, event));
        return false;
      };
    } else {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        method.call(_this, event);
        return false;
      };
    }
  };

  function html(element) {
    var key, value, _ref;
    this.element = element || this.constructor.element.cloneNode(true);
    log('new', this.element, this.constructor.components);
    this.html = {};
    _ref = this.constructor.components;
    for (key in _ref) {
      value = _ref[key];
      this.html[key] = this.element.querySelector(value);
    }
  }

  html.createTab = function() {
    var args, content, label;
    label = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    content = (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args), t = typeof result;
      return t == "object" || t == "function" ? result || child : child;
    })(this, args, function(){});
    content.tab = new ide.tab(label, content);
    return [content.tab, content];
  };

  return html;

})();

ide.login = (function(_super) {

  __extends(login, _super);

  function login() {
    return login.__super__.constructor.apply(this, arguments);
  }

  login.html('<login><label>username</label><input name="username"/><br/><label>password</label><input name="password"/><br/></login>');

  login.prototype.show = function() {
    return app.leftpane.element.appendChild(this.element);
  };

  login.prototype.hide = function() {
    return app.leftpane.element.removeChild(this.element);
  };

  return login;

})(ide.html);

ide.hierarchy = (function(_super) {

  __extends(hierarchy, _super);

  function hierarchy() {
    return hierarchy.__super__.constructor.apply(this, arguments);
  }

  hierarchy.html('<hierarchy></hierarchy>');

  hierarchy.prototype.load = function(projectlist) {
    var projectname, _results,
      _this = this;
    log(projectlist);
    _results = [];
    for (projectname in projectlist) {
      _results.push(run((function*() {
        var project;
        project = yield ide.project.create(projectname);
        return _this.element.appendChild(project.element);
      })()));
    }
    return _results;
  };

  return hierarchy;

})(ide.html);

ide.file = (function(_super) {

  __extends(file, _super);

  file.html('<file><label></label></file>');

  file.components = {
    label: 'label'
  };

  file.properties({
    label: {
      set: function(value) {
        return this.html.label.innerHTML = value;
      }
    },
    path: {
      get: function() {
        return "" + this.parent.path + "/" + this.name;
      }
    },
    filetype: {
      get: function() {
        return (this.name.split('.')).reverse();
      }
    }
  });

  function file(project, parent, name) {
    this.project = project;
    this.parent = parent;
    this.name = name;
    file.__super__.constructor.call(this);
    this.label = this.name;
    this.html.label.onclick = this.onclick(this.edit);
  }

  file.prototype.edit = function*() {
    var Editor, filetype,
      _this = this;
    if (this.editor != null) {
      return this.editor.tab.focus();
    }
    filetype = (this.name.split('.')).reverse();
    if (filetype[0] === 'json') {
      Editor = DataEditor.extensions[filetype[1]];
    }
    if (Editor == null) {
      Editor = TextEditor;
    }
    this.editor = yield Editor.create(this);
    this.editor.tab = app.leftpane.createTab(this.name, this.editor, function() {
      _this.project.editors.remove(_this.editor);
      return delete _this.editor;
    });
    return this.project.editors.push(this.editor);
  };

  file.prototype.close = function() {
    this.project.editors.remove(this.editor);
    return delete this.editor;
  };

  return file;

})(ide.html);

ide.folder = (function(_super) {

  __extends(folder, _super);

  folder.html('<folder><label></label><div class="folders"></div><div class="files"></div></folder>');

  folder.components = {
    label: 'label',
    folders: 'div.folders',
    files: 'div.files'
  };

  folder.properties({
    label: {
      set: function(value) {
        return this.html.label.innerHTML = value;
      }
    },
    path: {
      get: function() {
        return "" + this.parent.path + "/" + this.name;
      }
    },
    expanded: {
      get: function() {
        return this._expanded;
      },
      set: function(value) {
        return this.element.setAttribute('expanded', this._expanded = value);
      }
    }
  });

  function folder(project, parent, name) {
    this.project = project;
    this.parent = parent;
    this.name = name;
    folder.__super__.constructor.call(this);
    this.label = this.name;
    this.expanded = false;
    this.element.onclick = this.toggle = this.onclick(this.toggle);
  }

  folder.prototype.toggle = function() {
    if (this.expanded) {
      return this.close();
    } else {
      return run(this.open());
    }
  };

  folder.prototype.open = function*() {
    var contentlist, name, type;
    this.html.label.className = 'loading';
    this.html.label.onclick = null;
    try {
      contentlist = yield http.get("list/" + this.path);
    } catch (error) {
      this.html.label.title = error;
      this.html.label.className = 'error';
      return;
    }
    for (name in contentlist) {
      type = contentlist[name];
      switch (type) {
        case 'folder':
          this.addFolder(name);
          break;
        case 'file':
          this.addFile(name);
      }
    }
    this.html.label.className = '';
    this.html.label.onclick = this.toggle;
    return this.expanded = true;
  };

  folder.prototype.close = function() {
    this.expanded = false;
    this.html.folders.innerHTML = '';
    return this.html.files.innerHTML = '';
  };

  folder.prototype.addFile = function(name) {
    var file;
    file = new ide.file(this.project, this, name);
    this.html.files.appendChild(file.element);
    return file;
  };

  folder.prototype.addFolder = function(name) {
    var folder;
    folder = new ide.folder(this.project, this, name);
    this.html.folders.appendChild(folder.element);
    return folder;
  };

  return folder;

})(ide.html);

ide.project = (function(_super) {

  __extends(project, _super);

  project.html('<project><label></label><div class="folders"></div><div class="files"></div></project>');

  project.properties({
    path: {
      get: function() {
        return this.name;
      }
    }
  });

  project.create = function*(name) {
    var script;
    log("create project " + name);
    try {
      script = yield http.get("read/" + name + "/.client.coffee.js");
    } catch (error) {
      return new ide.project(name);
    }
    return new (eval(script))(name);
  };

  function project(name) {
    project.__super__.constructor.call(this, this, void 0, name);
    this.editors = [];
  }

  project.prototype.addButton = function(label, onclick) {
    var button;
    button = new ide.button(label, onclick);
    this.html.label.appendChild(button.element);
    return button;
  };

  project.prototype.saveAll = function*() {
    var all, editor, wait, _i, _len, _ref, _ref1;
    _ref = new WaitAll, wait = _ref.wait, all = _ref.all;
    _ref1 = this.editors;
    for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
      editor = _ref1[_i];
      if (editor.saving) {
        wait(editor.save());
      }
    }
    return yield all;
  };

  return project;

})(ide.folder);

ide.button = (function(_super) {

  __extends(button, _super);

  button.html('<button></button>');

  button.properties({
    label: {
      set: function(value) {
        return this.element.innerHTML = value;
      }
    },
    onclick: {
      set: function(value) {
        return this.element.onclick = ide.html.onclick(value);
      }
    }
  });

  function button(label, onclick) {
    button.__super__.constructor.call(this);
    this.label = label;
    this.onclick = onclick;
  }

  return button;

})(ide.html);

http = null;

app = null;

this.onload = function() {
  log('onload');
  return app = new ide({
    login: new ide.login,
    hierarchy: new ide.hierarchy($('hierarchy')),
    leftpane: new ide.tabpane($('#leftpane')),
    rightpane: new ide.tabpane($('#rightpane'))
  });
};
