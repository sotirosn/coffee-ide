var clone, html,
  __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Object.defineProperties(Array.prototype, {
  last: {
    get: function() {
      if (this.length > 0) {
        return this[this.length - 1];
      } else {
        return void 0;
      }
    }
  },
  remove: {
    value: function(value) {
      return this.splice(this.indexOf(value), 1);
    }
  }
});

clone = function(object) {
  var key, result, value;
  result = {};
  for (key in result) {
    value = result[key];
    if ((typeof value) === 'object') {
      result[key] = clone(value);
    } else {
      result[key] = value;
    }
  }
  return result;
};

html = (function() {

  function html(tagname, innerHTML, querySelectors) {
    var key, query, _ref;
    if (innerHTML == null) {
      innerHTML = '';
    }
    this.querySelectors = querySelectors != null ? querySelectors : {};
    this.element = document.createElement(tagname);
    this.element.innerHTML = innerHTML;
    this.html = {};
    _ref = this.querySelectors;
    for (key in _ref) {
      query = _ref[key];
      this.html[key] = this.element.querySelector(query);
    }
  }

  html.prototype.clone = function(element) {
    var key, query, _ref;
    if (element == null) {
      element = this.element.cloneNode(true);
    }
    html = {};
    _ref = this.querySelectors;
    for (key in _ref) {
      query = _ref[key];
      html[key] = element.querySelector(query);
    }
    return {
      html: html,
      element: element
    };
  };

  return html;

})();

html.element = (function() {

  element.properties = function(properties) {
    return Object.defineProperties(this.prototype, properties);
  };

  element.prototype.bind = function(method) {
    return method.bind(this);
  };

  element.prototype.html = new html('element');

  element.prototype.run = function(method) {
    var _this = this;
    if (method instanceof Generator) {
      return function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return run(method.call.apply(method, [_this].concat(__slice.call(args))));
      };
    } else {
      return function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return method.call.apply(method, [_this].concat(__slice.call(args)));
      };
    }
  };

  element.prototype.onclick = function(method) {
    var _this = this;
    if (method instanceof Generator) {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        return run("onclick", method.call(_this, event));
      };
    } else {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        return method.call(_this, event);
      };
    }
  };

  function element(element) {
    var _ref;
    _ref = this.html.clone(element || this.element), this.html = _ref.html, this.element = _ref.element;
  }

  element.prototype.show = function() {
    return this.element.removeAttribute('hidden');
  };

  element.prototype.hide = function() {
    return this.element.setAttribute('hidden', true);
  };

  return element;

})();

html.iframe = (function(_super) {

  __extends(iframe, _super);

  iframe.prototype.html = new html('iframe');

  iframe.properties({
    label: {
      set: function(value) {
        return this.tab.label = value;
      }
    }
  });

  function iframe(location) {
    var _this = this;
    this.location = location;
    iframe.__super__.constructor.call(this);
    this.element.src = location;
    this.element.onload = function() {
      return log("loaded: ", _this.label = _this.element.contentDocument.title || location);
    };
  }

  iframe.prototype.reload = function() {
    return this.element.src = this.location;
  };

  return iframe;

})(html.element);

html.icon = (function(_super) {

  __extends(icon, _super);

  icon.prototype.html = new html('icon');

  function icon(label, onclick) {
    icon.__super__.constructor.call(this);
    this.element.innerHTML = label;
    this.element.onclick = onclick;
  }

  icon.prototype.error = function(exception) {
    this.element.className = 'error';
    return this.element.title = exception;
  };

  return icon;

})(html.element);

html.contextmenu = (function(_super) {

  __extends(contextmenu, _super);

  contextmenu.prototype.html = new html('contextmenu', '<div></div>', {
    div: 'div'
  });

  contextmenu.properties({
    x: {
      set: function(value) {
        return this.element.style.left = value + 'px';
      }
    },
    y: {
      set: function(value) {
        return this.element.style.top = value + 'px';
      }
    }
  });

  function contextmenu() {
    contextmenu.__super__.constructor.apply(this, arguments);
    this.hide();
    this.element.onmouseleave = this.bind(this.hide);
  }

  contextmenu.prototype.addMenuItem = function(label, onclick) {
    var menuitem,
      _this = this;
    menuitem = new html.icon(label, (function() {
      return onclick(_this.target);
    }));
    this.html.div.appendChild(menuitem.element);
    return menuitem;
  };

  contextmenu.prototype.display = function(target, event) {
    this.target = target;
    this.x = event.clientX;
    this.y = event.clientY;
    this.show();
    event.preventDefault();
    return event.stopPropagation();
  };

  return contextmenu;

})(html.element);

html.tab = (function(_super) {

  __extends(tab, _super);

  tab.prototype.html = new html('tab', '<label></label><close>x</close>', {
    label: 'label',
    close: 'close'
  });

  tab.properties({
    label: {
      set: function(value) {
        return this.html.label.innerHTML = value;
      }
    }
  });

  function tab(label, contents, onclose) {
    this.contents = contents;
    this.onclose = onclose;
    tab.__super__.constructor.call(this);
    this.label = label;
    this.element.onclick = this.onclick(this.focus);
    this.html.close.onclick = this.onclick(this.close);
  }

  tab.prototype.close = function*() {
    if (this.onclose != null) {
      yield run(this.onclose());
    }
    return this.container.remove(this);
  };

  tab.prototype.focus = function() {
    this.container.activate(this);
    return this.contents.focus();
  };

  return tab;

})(html.element);

html.tabarea = (function(_super) {

  __extends(tabarea, _super);

  tabarea.prototype.html = new html('tabarea', '<tabs></tabs><contents></contents>', {
    tabs: 'tabs',
    contents: 'contents'
  });

  function tabarea(element) {
    tabarea.__super__.constructor.call(this, element);
    this.active = null;
    this.container = [];
  }

  tabarea.prototype.createTab = function(label, contents, onclose) {
    return this.add(new html.tab(label, contents, onclose));
  };

  tabarea.prototype.add = function(tab) {
    this.container.push(tab);
    this.html.tabs.appendChild(tab.element);
    this.html.contents.appendChild(tab.contents);
    tab.container = this;
    tab.focus();
    return tab;
  };

  tabarea.prototype.remove = function(tab) {
    this.container.splice(this.container.indexOf(tab), 1);
    this.html.tabs.removeChild(tab.element);
    this.html.contents.removeChild(tab.contents);
    if (this.active === tab) {
      this.active = null;
      if (this.container.length > 0) {
        return this.container[0].focus();
      }
    }
  };

  tabarea.prototype.activate = function(tab) {
    if (this.active === tab) {
      return;
    }
    if (this.active) {
      this.active.element.removeAttribute('active');
      this.active.contents.setAttribute('hidden', true);
    }
    this.active = tab;
    this.active.element.setAttribute('active', true);
    return this.active.contents.removeAttribute('hidden');
  };

  return tabarea;

})(html.element);

html.log = (function(_super) {
  var section;

  __extends(log, _super);

  function log() {
    return log.__super__.constructor.apply(this, arguments);
  }

  log.print = function() {
    var arg, args, key, result, subdelimeter, subresult, value, _i, _len;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    result = '';
    for (_i = 0, _len = args.length; _i < _len; _i++) {
      arg = args[_i];
      switch (typeof arg) {
        case 'object':
          subresult = '{';
          subdelimeter = '';
          for (key in arg) {
            value = arg[key];
            subresult += "" + subdelimeter + "<span class='key'>" + key + "</span>: " + value;
            subdelimeter = ', ';
          }
          subresult += '}';
          break;
        default:
          subresult = arg + ' ';
      }
      result += subresult + ' ';
    }
    return result;
  };

  section = (function(_super1) {

    __extends(section, _super1);

    section.prototype.html = new html('div', '<span></span><div></div>', {
      info: 'span',
      body: 'div'
    });

    function section() {
      var args, _ref;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      section.__super__.constructor.call(this);
      this.html.info.innerHTML = (_ref = html.log).print.apply(_ref, args);
      this.html.info.onclick = this.onclick(this.fold);
      this.isVisible = true;
    }

    section.prototype.fold = function() {
      if (this.isVisible) {
        this.html.body.setAttribute('hidden', true);
        return this.isVisible = false;
      } else {
        this.html.body.removeAttribute('hidden');
        return this.isVisible = true;
      }
    };

    section.prototype.log = function(html) {
      return this.html.body.innerHTML += html;
    };

    return section;

  })(html.element);

  log.prototype.html = new html('log');

  log.prototype.format = function(format) {
    var _this = this;
    return function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return _this.log(format.apply(null, args));
    };
  };

  log.prototype.start = function() {
    var args, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    console.log(this.current);
    if ((_ref = this.current) != null ? _ref.isVisible : void 0) {
      this.current.fold();
    }
    this.current = (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args), t = typeof result;
      return t == "object" || t == "function" ? result || child : child;
    })(section, args, function(){});
    return this.element.appendChild(this.current.element);
  };

  log.prototype.log = function() {
    var args, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return this.current.log("<p>" + ((_ref = html.log).print.apply(_ref, args)) + "</p>");
  };

  log.prototype.error = function() {
    var args, _ref;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return this.current.log("<p class='error'>" + ((_ref = html.log).print.apply(_ref, args)) + "</p>");
  };

  log.prototype.stdout = function(message) {
    return this.current.log("<pre>" + message + "</pre>");
  };

  log.prototype.stderr = function(message) {
    return this.current.log("<pre class='error'>" + message + "</pre>");
  };

  log.prototype.stdlog = function(_arg) {
    var stderr, stdout;
    stdout = _arg[0], stderr = _arg[1];
    if (stdout) {
      this.stdout(stdout);
    }
    if (stderr) {
      return this.stderr(stderr);
    }
  };

  return log;

})(html.element);

html.toolbar = (function(_super) {

  __extends(toolbar, _super);

  function toolbar() {
    return toolbar.__super__.constructor.apply(this, arguments);
  }

  toolbar.prototype.html = new html('toolbar');

  return toolbar;

})(html.element);
