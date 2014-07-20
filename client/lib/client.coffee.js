var $, Generator, app, htmldecode, http, json, log, run, set,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

$ = document.querySelector.bind(document);

log = console.log.bind(console);

Generator = (function*() {
  return yield null;
}).constructor;

json = JSON.parse.bind(JSON);

set = function(set) {
  var _value;
  if ((typeof set) !== 'function' || set.length !== 1) {
    throw 'set expects a function with one argument';
  }
  _value = null;
  return {
    get: function() {
      return _value;
    },
    set: function(value) {
      set.call(this, value);
      return _value = value;
    }
  };
};

Array.prototype.remove = function(element) {
  var index;
  this.splice((index = this.indexOf(element)), 1);
  return index;
};

Array.prototype.contains = function(element) {
  return -1 < this.indexOf(element);
};

htmldecode = function(text) {
  return text.replace(/&#([^;]+);/g, function($0, $1) {
    log($1);
    String.fromCharCode($1);
    return $0;
  });
};

ide.routine = (function() {

  function routine(iterator) {
    this.iterator = iterator;
  }

  routine.prototype["throw"] = function(exception) {
    return this.iterator["throw"](exception);
  };

  routine.prototype.next = function(nextvalue) {
    var _ref, _ref1,
      _this = this;
    _ref = this.iterator.next(nextvalue), this.done = _ref.done, this.value = _ref.value;
    if (this.done) {
      if ((_ref1 = this.onreturn) != null) {
        _ref1.next(this.value);
      }
    } else {
      this.value(this);
    }
    return function(onreturn) {
      _this.onreturn = onreturn;
      if (_this.done) {
        return _this.onreturn.next(_this.value);
      }
    };
  };

  routine.run = function(iterator) {
    if ((iterator != null ? iterator.next : void 0) != null) {
      return (new ide.routine(iterator)).next();
    } else {
      return function(routine) {
        return routine.next();
      };
    }
  };

  return routine;

})();

ide.http = (function() {

  function http(host) {
    this.host = host;
  }

  http.prototype.encode = function(data) {
    var delimeter, key, result, value;
    result = '';
    delimeter = '?';
    for (key in data) {
      value = data[key];
      result += "" + delimeter + (encodeURI(key)) + "=" + (encodeURI(value));
      delimeter = '&';
    }
    return result;
  };

  http.prototype.request = function(method, url, data, parser) {
    log(method, url);
    return function(routine) {
      var request;
      request = new XMLHttpRequest();
      request.open(method, url);
      request.withCredentials = true;
      request.onreadystatechange = function() {
        if (this.readyState === 4) {
          if (this.status === 200) {
            if (parser) {
              return routine.next(parser(this.responseText));
            } else {
              return routine.next(this.responseText);
            }
          } else {
            return routine["throw"](this.responseText);
          }
        }
      };
      return request.send(data);
    };
  };

  http.prototype.get = function(uri, data) {
    var url;
    url = "" + this.host + "/" + uri + (this.encode(data));
    return this.request('GET', url);
  };

  http.prototype.getdata = function(uri, data) {
    var url;
    url = "" + this.host + "/" + uri + (this.encode(data));
    return this.request('GET', url, void 0, json);
  };

  http.prototype.post = function(uri, data, value) {
    var url;
    if (data == null) {
      data = {};
    }
    if (arguments.length === 2 && (typeof data) === 'string') {
      value = data;
      data = {};
    }
    url = "" + this.host + "/" + uri + (this.encode(data));
    return this.request('POST', url, value);
  };

  http.prototype.postdata = function(uri, data, value) {
    var url;
    if (data == null) {
      data = {};
    }
    if (arguments.length === 2 && (typeof data) === 'string') {
      value = data;
      data = {};
    }
    url = "" + this.host + "/" + uri + (this.encode(data));
    return this.request('POST', url, value, json);
  };

  return http;

})();

ide.placeholder = (function(_super) {

  __extends(placeholder, _super);

  placeholder.html('<input/>');

  function placeholder() {
    var _this = this;
    placeholder.__super__.constructor.apply(this, arguments);
    this.hide = this.hide.bind(this);
    this.element.onblur = this.hide;
    this.element.onclick = function(event) {
      return event.stopPropagation();
    };
    this.element.onkeypress = function(event) {
      switch (event.keyCode) {
        case 27:
          return _this.hide();
        case 13:
          return _this.element.blur();
      }
    };
  }

  placeholder.prototype.show = function(container, target, value, onblur) {
    var _ref;
    if (this.target != null) {
      this.hide();
    }
    container.insertBefore(this.element, target != null ? target.element : void 0);
    this.element.style.display = 'block';
    this.element.onblur = onblur;
    this.element.value = value;
    this.element.select();
    this.target = target;
    return (_ref = this.target) != null ? _ref.hide() : void 0;
  };

  placeholder.prototype.hide = function() {
    var _ref;
    this.element.style.display = 'none';
    this.element.onblur = this.hide;
    if ((_ref = this.target) != null) {
      _ref.show();
    }
    return delete this.target;
  };

  return placeholder;

})(ide.html);

ide.element = (function(_super) {

  __extends(element, _super);

  element.html('<element><label></label></label>', {
    label: 'label'
  });

  element.prototype.placeholder = new ide.placeholder;

  element.properties({
    label: set(function(value) {
      return this.html.label.innerHTML = value;
    }),
    path: {
      get: function() {
        return "" + (this.parent.path || '.') + "/" + this.name;
      }
    }
  });

  element.prototype.oncontextmenu = function(event) {
    var _ref;
    return (_ref = event.element) != null ? _ref : event.element = this.element;
  };

  function element(project, parent, name) {
    this.project = project;
    this.parent = parent;
    this.name = name;
    element.__super__.constructor.call(this);
    this.label = name;
    this.element.element = this;
    this.element.oncontextmenu = this.oncontextmenu;
  }

  element.prototype.rename = function(name) {
    return this.label = this.name = name;
  };

  element.prototype["delete"] = function*() {
    yield http.get("delete/" + this.path);
    return this.element.parentNode.removeChild(this.element);
  };

  element.prototype.createFolder = function() {
    return this.parent.createFolder();
  };

  element.prototype.createFile = function() {
    return this.parent.createFile();
  };

  return element;

})(ide.html);

ide.file = (function(_super) {

  __extends(file, _super);

  file.html('<file><label></label></file>', {
    label: 'label'
  });

  file.prototype.imageExtensions = 'jpg';

  'png';


  'gif';


  file.prototype.dataExtensions = {
    'sprite': SpriteEditor
  };

  function file() {
    file.__super__.constructor.apply(this, arguments);
    this.element.onclick = this.onclick(this.edit);
    this.filetype = this.name.split('.').reverse();
  }

  file.prototype.edit = function*() {
    var data, editor, text;
    if (this.editor) {
      return this.editor.tab.activate();
    }
    if (this.filetype[0] === 'json' && (editor = this.dataExtensions[this.filetype[1]])) {
      data = yield http.getdata("readdata/" + this.path);
      this.editor = new editor(this, data);
    } else if (this.imageExtensions.contains(this.filetype[0])) {
      this.editor = new ImageViewer(this);
    } else {
      text = yield http.get("readfile/" + this.path);
      this.editor = new TextEditor(this, text);
    }
    this.editor.tab = app.leftpane.createTab(this.name, this.editor);
    return this.project.editors.push(this.editor);
  };

  file.prototype.close = function() {
    this.project.editors.remove(this.editor);
    return delete this.editor;
  };

  return file;

})(ide.element);

ide.directory = (function(_super) {

  __extends(directory, _super);

  directory.html('<directory><label></label><div class="directories"></div><div class="files"></div></directory>', {
    label: 'label',
    files: 'div.files',
    directories: 'div.directories'
  });

  directory.properties({
    expanded: set(function(value) {
      if (value) {
        return this.element.setAttribute('expanded', true);
      } else {
        return this.element.removeAttribute('expanded');
      }
    })
  });

  function directory() {
    directory.__super__.constructor.apply(this, arguments);
    this.element.onclick = this.onclick(this.toggle);
  }

  directory.prototype.open = function*() {
    var filelist, name, type;
    filelist = yield http.getdata("listdir/" + this.path);
    for (name in filelist) {
      type = filelist[name];
      switch (type) {
        case 'file':
          this.addFile(name);
          break;
        case 'dir':
          this.addDirectory(name);
      }
    }
    return this.expanded = true;
  };

  directory.prototype.close = function() {
    this.html.directories.innerHTML = '';
    this.html.files.innerHTML = '';
    return this.expanded = false;
  };

  directory.prototype.toggle = function() {
    if (this.expanded) {
      return this.close();
    } else {
      return run(this.open());
    }
  };

  directory.prototype.addFile = function(name) {
    var file;
    file = new ide.file(this.project, this, name);
    this.html.files.appendChild(file.element);
    return file;
  };

  directory.prototype.addDirectory = function(name) {
    var directory;
    directory = new ide.directory(this.project, this, name);
    this.html.directories.appendChild(directory.element);
    return directory;
  };

  directory.prototype.createFolder = function() {
    return this.placeholder.show(this.html.directories, null, 'new folder', this.onclick(function*() {
      this.placeholder.hide();
      yield http.get("mkdir/" + this.path + "/" + this.placeholder.element.value, '');
      return this.addDirectory(this.placeholder.element.value);
    }));
  };

  directory.prototype.createFile = function() {
    return this.placeholder.show(this.html.files, null, 'new file', this.onclick(function*() {
      this.placeholder.hide();
      yield http.post("writefile/" + this.path + "/" + this.placeholder.element.value, '');
      return this.addFile(this.placeholder.element.value);
    }));
  };

  directory.prototype.renameElement = function(target) {
    return this.placeholder.show(target.element.parentNode, target, target.name, this.onclick(function*() {
      this.placeholder.hide();
      yield http.get("rename/" + target.path, {
        newpath: "" + this.path + "/" + this.placeholder.element.value
      });
      return target.rename(this.placeholder.element.value);
    }));
  };

  return directory;

})(ide.element);

ide.project = (function(_super) {

  __extends(project, _super);

  project.html('<project><label></label><div class="directories"></div><div class="files"></div></project>', {
    label: 'label',
    files: 'div.files',
    directories: 'div.directories'
  });

  function project(name) {
    project.__super__.constructor.call(this, this, '.', name);
    this.editors = [];
    this.run(function*() {
      var script;
      try {
        script = yield http.get("readfile/" + this.path + "/.project.coffee.js");
        return (eval(script))(this);
      } catch (_error) {}
    });
  }

  project.prototype.createButton = function(label, onclick) {
    var button;
    button = new ide.button(label, onclick);
    this.html.label.appendChild(button.element);
    return button;
  };

  project.prototype.command = function(command) {
    return http.getdata("command/" + this.path + "/" + command);
  };

  project.prototype.runCommand = function(command) {
    return http.getdata("run/" + this.path + "/" + command);
  };

  return project;

})(ide.directory);

ide.contextmenu = (function(_super) {

  __extends(contextmenu, _super);

  contextmenu.html('<menu hidden=true><div></div></menu>', {
    menu: 'div'
  });

  contextmenu.menu = {};

  contextmenu.prototype.onclick = function(action) {
    var _this = this;
    return function(event) {
      event.stopPropagation();
      event.preventDefault();
      action.call(_this, _this.target);
      _this.hide();
      return false;
    };
  };

  function contextmenu() {
    var action, itemname, menuitem, _ref;
    contextmenu.__super__.constructor.apply(this, arguments);
    this.menu = {};
    _ref = this.constructor.menu;
    for (itemname in _ref) {
      action = _ref[itemname];
      menuitem = this.html.menu.querySelector("[name=" + itemname + "]");
      menuitem.onmousedown = this.onclick(action);
      this.menu[itemname] = menuitem;
    }
    this.visible = false;
  }

  contextmenu.prototype.show = function(event) {
    if (!this.visible) {
      this.visible = true;
      this.element.removeAttribute('hidden');
    }
    this.element.style.left = event.clientX + 'px';
    this.element.style.top = event.clientY + 'px';
    return this.target = event.element;
  };

  contextmenu.prototype.hide = function() {
    if (this.visible) {
      this.visible = false;
      return this.element.setAttribute('hidden', true);
    }
  };

  return contextmenu;

})(ide.html);

ide.hierarchy = (function(_super) {
  var contextmenu;

  __extends(hierarchy, _super);

  hierarchy.html('<hierarchy></hierarchy>');

  contextmenu = (function(_super1) {

    __extends(contextmenu, _super1);

    function contextmenu() {
      return contextmenu.__super__.constructor.apply(this, arguments);
    }

    contextmenu.html('<menu hidden=true><div>\n	<label name=\'newFolder\'>New Folder</label>\n	<label name=\'newFile\'>New File</label>\n	<hr/>\n	<label name=\'rename\'>Rename</label>\n	<label name=\'cut\'>Cut</label>\n	<label name=\'copy\'>Copy</label>\n	<label name=\'paste\' disabled=true>Paste</label>\n	<label name=\'delete\'>Delete</label>\n	<hr/>\n	<label name=\'download\'>Download</label>\n</div></menu>', {
      menu: 'div'
    });

    contextmenu.menu = {
      newFolder: function(element) {
        return element.createFolder();
      },
      newFile: function(element) {
        return element.createFile();
      },
      rename: function(element) {
        return element.parent.renameElement(element);
      },
      cut: function(element) {
        this.copy = void 0;
        this.cut = element;
        return this.menu.paste.removeAttribute('disabled');
      },
      copy: function(element) {
        this.copy = element;
        this.cut = void 0;
        return this.menu.paste.removeAttribute('disabled');
      },
      paste: function(element) {
        if (this.cut != null) {
          element.paste(this.cut);
          return this.html['Paste'].setAttribute('disabled', true);
        } else if (this.copy) {
          return element.copy(this.copy);
        }
      },
      "delete": function(element) {
        run(element["delete"]());
        return this.menu.paste.setAttribute('disabled', true);
      }
    };

    return contextmenu;

  })(ide.contextmenu);

  hierarchy.prototype.contextmenu = new contextmenu;

  hierarchy.prototype.oncontextmenu = function(event) {
    if (!(event.element != null)) {
      return;
    }
    this.contextmenu.show(event);
    event.preventDefault();
    event.stopPropagation();
    return false;
  };

  function hierarchy() {
    document.body.appendChild(this.contextmenu.element);
    hierarchy.__super__.constructor.apply(this, arguments);
    this.element.oncontextmenu = this.oncontextmenu.bind(this);
    this.run(function*() {
      var name, projectlist, sessionID, _i, _len, _results;
      sessionID = yield http.postdata('login', 'password=$sounds');
      projectlist = yield http.getdata('projectlist');
      _results = [];
      for (_i = 0, _len = projectlist.length; _i < _len; _i++) {
        name = projectlist[_i];
        _results.push(this.addProject(name));
      }
      return _results;
    });
  }

  hierarchy.prototype.addProject = function(name) {
    var project;
    project = new ide.project(name);
    this.element.appendChild(project.element);
    return project;
  };

  return hierarchy;

}).call(this, ide.html);

ide.toolbar = (function(_super) {

  __extends(toolbar, _super);

  function toolbar() {
    return toolbar.__super__.constructor.apply(this, arguments);
  }

  toolbar.html('<toolbar></toolbar>');

  return toolbar;

})(ide.html);

ide.tab = (function(_super) {

  __extends(tab, _super);

  tab.html('<tab><label></label><close>x</close></tab>', {
    label: 'label',
    close: 'close'
  });

  tab.properties({
    label: set(function(value) {
      return this.html.label.innerHTML = value;
    })
  });

  function tab(label, content) {
    this.content = content;
    tab.__super__.constructor.call(this);
    this.label = label;
    this.element.onclick = this.onclick(this.activate);
    this.html.close.onclick = this.onclick(this.close);
  }

  tab.prototype.activate = function() {
    this.tabarea.activateTab(this);
    return this.content.focus();
  };

  tab.prototype.close = function*() {
    yield run(this.content.close());
    return this.tabarea.removeTab(this);
  };

  return tab;

})(ide.html);

ide.tabarea = (function(_super) {

  __extends(tabarea, _super);

  tabarea.html('<tabarea><tabs></tabs><contents></contents></tabarea>', {
    tabs: 'tabs',
    contents: 'contents'
  });

  function tabarea() {
    tabarea.__super__.constructor.apply(this, arguments);
    this.tabs = [];
  }

  tabarea.prototype.activateTab = function(tab) {
    var _ref, _ref1;
    if (this.active === tab) {
      return;
    }
    if ((_ref = this.active) != null) {
      _ref.element.removeAttribute('active');
    }
    if ((_ref1 = this.active) != null) {
      _ref1.content.element.setAttribute('hidden', true);
    }
    this.active = tab;
    this.active.element.setAttribute('active', true);
    return this.active.content.element.removeAttribute('hidden');
  };

  tabarea.prototype.removeTab = function(tab) {
    var index;
    index = this.tabs.remove(tab);
    this.html.tabs.removeChild(tab.element);
    this.html.contents.removeChild(tab.content.element);
    if (this.active === tab && this.tabs.length > 0) {
      return this.tabs[index === this.tabs.length ? index - 1 : index].activate();
    }
  };

  tabarea.prototype.addTab = function(tab) {
    tab.tabarea = this;
    this.html.tabs.appendChild(tab.element);
    this.html.contents.appendChild(tab.content.element);
    this.tabs.push(tab);
    return tab.activate();
  };

  tabarea.prototype.createTab = function(label, content) {
    var tab;
    this.addTab(tab = new ide.tab(label, content));
    return tab;
  };

  return tabarea;

})(ide.html);

ide.statusbar = (function(_super) {

  __extends(statusbar, _super);

  function statusbar() {
    return statusbar.__super__.constructor.apply(this, arguments);
  }

  statusbar.html('<statusbar><label></label><span></span></statusbar>', {
    info: 'label',
    message: 'span'
  });

  return statusbar;

})(ide.html);

app = null;

http = new ide.http('https://localhost:9090');

run = ide.routine.run;

this.onmousedown = function(event) {
  return app.hierarchy.contextmenu.hide();
};

this.onload = function() {
  return app = new ide({
    hierarchy: $('#hierarchy'),
    toolbar: $('#toolbar'),
    leftpane: $('#leftpane'),
    rightpane: $('#rightpane'),
    statusbar: $('#statusbar')
  });
};
