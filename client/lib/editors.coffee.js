var ImageViewer, SpriteEditor, TextEditor, ide,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ide = (function() {

  function ide(elements) {
    this.hierarchy = new ide.hierarchy(elements.hierarchy);
    this.toolbar = new ide.toolbar(elements.toolbar);
    this.leftpane = new ide.tabarea(elements.leftpane);
    this.rightpane = new ide.tabarea(elements.rightpane);
    this.statusbar = new ide.statusbar(elements.statusbar);
  }

  return ide;

})();

ide.html = (function() {
  var node;

  node = document.createElement('div');

  html.properties = function(properties) {
    return Object.defineProperties(this.prototype, properties);
  };

  html.html = function(html, components) {
    this.components = components != null ? components : {};
    node.innerHTML = html;
    return this.element = node.firstChild;
  };

  html.create = function(element) {
    var html, key, value, _ref;
    if (element == null) {
      element = this.element.cloneNode(true);
    }
    if (!element.innerHTML && this.element.innerHTML) {
      element.innerHTML = this.element.innerHTML;
    }
    html = {};
    _ref = this.components;
    for (key in _ref) {
      value = _ref[key];
      html[key] = element.querySelector(value);
    }
    return {
      element: element,
      html: html
    };
  };

  function html(element) {
    var _ref;
    _ref = this.constructor.create(element), this.element = _ref.element, this.html = _ref.html;
  }

  html.prototype.hide = function() {
    return this.element.style.display = 'none';
  };

  html.prototype.show = function() {
    return this.element.style.display = 'block';
  };

  html.prototype.run = function(iterator) {
    return run(iterator.call(this));
  };

  html.prototype.onclick = function(iterator) {
    var _this = this;
    if (iterator instanceof Generator) {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        run(iterator.call(_this, event));
        return false;
      };
    } else {
      return function(event) {
        event.stopPropagation();
        event.preventDefault();
        iterator.call(_this, event);
        return false;
      };
    }
  };

  return html;

})();

ide.editor = (function(_super) {

  __extends(editor, _super);

  editor.html('<textarea></textarea>');

  function editor(file, value) {
    this.file = file;
    editor.__super__.constructor.call(this);
    if (value != null) {
      this.value = value;
    }
  }

  editor.properties({
    value: {
      set: function(value) {
        return this.element.value = value;
      },
      get: function() {
        return this.element.value;
      }
    },
    saving: {
      set: function(value) {
        this._saving = value;
        return this.tab.label = this.file.name + (value ? '*' : '');
      },
      get: function() {
        return this._saving;
      }
    }
  });

  editor.prototype.autosaveDelay = 30000;

  editor.prototype.autosave = function() {
    var _this = this;
    if (!this.saving) {
      return this.saving = setTimeout((function() {
        return run(_this.save(true));
      }), this.autosaveDelay);
    }
  };

  editor.prototype.save = function*(autosave) {
    var stderr, stdout, _ref;
    if (autosave == null) {
      autosave = false;
    }
    if (!autosave) {
      clearTimeout(this.saving);
    }
    _ref = yield http.postdata("writefile/" + this.file.path, this.value), stdout = _ref[0], stderr = _ref[1];
    if (stdout) {
      log(stdout);
    }
    if (stderr) {
      console.error(stderr);
    }
    return this.saving = false;
  };

  editor.prototype.close = function*() {
    if (this.saving) {
      yield run(this.save());
    }
    return this.file.close();
  };

  editor.prototype.focus = function() {
    return this.element.focus();
  };

  return editor;

})(ide.html);

TextEditor = (function(_super) {

  __extends(TextEditor, _super);

  TextEditor.prototype.extensions = {
    'txt': 'text',
    'html': 'html',
    'js': 'javascript',
    'coffee': 'coffeescript',
    'Cakefile': 'coffeescript',
    'jade': 'jade',
    'css': 'css',
    'xml': 'xml',
    'json': 'json'
  };

  TextEditor.html('<div></div>');

  TextEditor.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value);
      },
      get: function() {
        return this.editor.getValue();
      }
    }
  });

  function TextEditor(file, data) {
    TextEditor.__super__.constructor.call(this, file);
    this.editor = CodeMirror(this.element, {
      mode: this.extensions[this.file.filetype[0]] || 'text',
      value: data.replace(/^[ ]+/gm, function(leadingSpace) {
        return leadingSpace.replace(/[ ]{4}/g, '\t');
      }),
      lineNumbers: true,
      tabSize: 4,
      indentUnit: 4,
      indentWithTabs: true,
      autofocus: true
    });
    this.editor.on('change', this.autosave.bind(this));
  }

  TextEditor.prototype.focus = function() {
    this.editor.focus();
    return this.editor.refresh();
  };

  return TextEditor;

})(ide.editor);

ImageViewer = (function(_super) {

  __extends(ImageViewer, _super);

  ImageViewer.html('<editor><img/></editor>', {
    image: 'img'
  });

  function ImageViewer(file) {
    this.file = file;
    ImageViewer.__super__.constructor.call(this);
    this.html.image.src = "" + http.host + "/readfile/" + this.file.path;
  }

  ImageViewer.prototype.close = function() {};

  return ImageViewer;

})(ide.html);

SpriteEditor = (function(_super) {

  __extends(SpriteEditor, _super);

  function SpriteEditor() {
    return SpriteEditor.__super__.constructor.apply(this, arguments);
  }

  return SpriteEditor;

})(ide.editor);
