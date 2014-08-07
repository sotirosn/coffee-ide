var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Array.prototype.remove = function(element) {
  var index;
  index = this.indexOf(element);
  this.splice(index, 1);
  return index;
};

ide.tabpane = (function(_super) {

  __extends(tabpane, _super);

  tabpane.html('<tabcontents><div class="tabs"></div><div class="contents"></div></tabcontents>');

  tabpane.components = {
    tabs: 'div.tabs',
    contents: 'div.contents'
  };

  function tabpane() {
    tabpane.__super__.constructor.apply(this, arguments);
    this.tabs = [];
  }

  tabpane.prototype.createTab = function(label, content, onclose) {
    var tab;
    tab = new ide.tab(label, content, onclose);
    this.addTab(tab);
    return tab;
  };

  tabpane.prototype.addTab = function(tab) {
    tab.container = this;
    this.tabs.push(tab);
    this.html.tabs.appendChild(tab.element);
    this.html.contents.appendChild(tab.content.element);
    return tab.focus();
  };

  tabpane.prototype.focusTab = function(tab) {
    var _base, _ref, _ref1;
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
    this.active.content.element.removeAttribute('hidden');
    return typeof (_base = this.active.content).focus === "function" ? _base.focus() : void 0;
  };

  tabpane.prototype.removeTab = function(tab) {
    var index;
    this.html.tabs.removeChild(tab.element);
    this.html.contents.removeChild(tab.content.element);
    index = this.tabs.remove(tab);
    if (this.active === tab && this.tabs.length > 0) {
      return this.tabs[index < this.tabs.length ? index : index - 1].focus();
    }
  };

  return tabpane;

})(ide.html);

ide.tab = (function(_super) {

  __extends(tab, _super);

  tab.html('<tab><label></label><close>x</close></tab>');

  tab.components = {
    label: 'label',
    close: 'close'
  };

  tab.properties({
    label: {
      set: function(value) {
        return this.html.label.innerHTML = value;
      }
    }
  });

  function tab(label, content, onclose) {
    var _ref,
      _this = this;
    this.content = content;
    this.onclose = onclose;
    tab.__super__.constructor.call(this);
    this.label = label;
    this.element.onclick = this.onclick(this.focus);
    this.html.close.onclick = this.onclick((((_ref = this.content.close) != null ? _ref.isGenerator() : void 0) ? function*() {
      yield _this.content.close();
      _this.container.removeTab(_this);
      return typeof _this.onclose === "function" ? _this.onclose() : void 0;
    } : function() {
      var _base;
      if (typeof (_base = _this.content).close === "function") {
        _base.close();
      }
      _this.container.removeTab(_this);
      return typeof _this.onclose === "function" ? _this.onclose() : void 0;
    }));
  }

  tab.prototype.focus = function() {
    this.container.focusTab(this);
    return this.content.focus();
  };

  return tab;

})(ide.html);

ide.view = (function(_super) {

  __extends(view, _super);

  view.html('<iframe></iframe>');

  view.properties({
    location: {
      set: function(value) {
        return this.element.src = value;
      },
      get: function() {
        return this.element.src;
      }
    }
  });

  function view(location) {
    var _this = this;
    view.__super__.constructor.call(this);
    setTimeout((function() {
      return _this.location = location;
    }), 0);
  }

  view.prototype.refresh = function() {
    return this.location = this.location;
  };

  view.prototype.focus = function() {
    this.element.focus();
    return this.onclick = onclick;
  };

  return view;

})(ide.html);
