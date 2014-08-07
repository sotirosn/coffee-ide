var DataEditor, TextEditor,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ide.editor = (function(_super) {

  __extends(editor, _super);

  editor.html('<editor><textarea></textarea></editor>');

  editor.components = {
    textarea: 'textarea'
  };

  editor.properties({
    value: {
      set: function(value) {
        return this.html.textarea.value = value;
      },
      get: function() {
        return this.html.textarea.value;
      }
    },
    error: {
      set: function(value) {
        return this._error = value;
      },
      get: function() {
        return this._error;
      }
    }
  });

  editor.create = function*(file) {
    var editor;
    editor = new this(file);
    yield editor.load();
    return editor;
  };

  function editor(file) {
    this.file = file;
    log("new file editor -> " + this.file.path);
    editor.__super__.constructor.call(this);
  }

  editor.prototype.load = function*() {
    var text;
    text = yield http.get("read/" + this.file.path);
    this.value = text;
    return this.element.oninput = this.autosave.bind(this);
  };

  editor.prototype.autosaveDelay = 30000;

  editor.prototype.autosave = function() {
    var _this = this;
    if (this.saving) {
      return;
    }
    this.saving = setTimeout((function() {
      return run(_this.save(true));
    }), this.autosaveDelay);
    return this.tab.label = "" + this.file.name + "*";
  };

  editor.prototype.save = function*(autosaving) {
    var result;
    if (autosaving == null) {
      autosaving = false;
    }
    if (!this.autosaving) {
      clearTimeout(this.saving);
    }
    delete this.saving;
    this.tab.label = this.file.name;
    return log(result = yield http.post("write/" + this.file.path, this.value));
  };

  editor.prototype.close = function*() {
    if (this.saving || this.error) {
      return yield this.save();
    }
  };

  editor.prototype.focus = function() {
    return this.element.focus();
  };

  return editor;

})(ide.html);

DataEditor = (function(_super) {

  __extends(DataEditor, _super);

  function DataEditor() {
    return DataEditor.__super__.constructor.apply(this, arguments);
  }

  DataEditor.extensions = {};

  return DataEditor;

})(ide.editor);

TextEditor = (function(_super) {
  var ErrorMark;

  __extends(TextEditor, _super);

  function TextEditor() {
    return TextEditor.__super__.constructor.apply(this, arguments);
  }

  ErrorMark = (function(_super1) {

    __extends(ErrorMark, _super1);

    ErrorMark.html('<label class="error">&#8855;</label>');

    ErrorMark.properties({
      message: {
        set: function(value) {
          return this.element.title = value;
        }
      }
    });

    function ErrorMark(symbol) {
      ErrorMark.__super__.constructor.call(this);
      this.element.innerHTML = symbol;
    }

    return ErrorMark;

  })(ide.html);

  TextEditor.html('<editor></editor>');

  TextEditor.components = {};

  TextEditor.properties({
    value: {
      set: function(value) {
        return this.editor.setValue(value);
      },
      get: function() {
        return this.editor.getValue();
      }
    },
    error: {
      set: function(value) {
        var lineNumber, _, _ref, _ref1, _ref2;
        if (value) {
          _ref = value.message.match(/on line (\d+)/), _ = _ref[0], lineNumber = _ref[1];
          if ((_ref1 = this.errorLineMark) == null) {
            this.errorLineMark = new ErrorMark('&#9670;');
          }
          if ((_ref2 = this.errorTabMark) == null) {
            this.errorTabMark = new ErrorMark('&#9670;');
          }
          this.errorLineMark.message = this.errorTabMark.message = value.message;
          this.editor.setGutterMarker(+lineNumber - 1, 'CodeMirror-linenumbers', this.errorLineMark.element);
          this.tab.element.appendChild(this.errorTabMark.element);
        } else if (this._error) {
          this.editor.clearGutter('CodeMirror-linenumbers');
          this.tab.element.removeChild(this.errorTabMark.element);
        }
        return this._error = value;
      },
      get: function() {
        return this._error;
      }
    }
  });

  TextEditor.extensions = {
    'txt': 'text',
    'html': 'html',
    'Cakefile': 'coffeescript',
    'jade': 'jade',
    'css': 'css',
    'xml': 'xml',
    'json': 'json',
    'coffee': 'coffeescript',
    'js': 'javascript'
  };

  TextEditor.prototype.load = function*() {
    var text;
    text = yield http.get("read/" + this.file.path);
    this.editor = CodeMirror(this.element, {
      mode: TextEditor.extensions[this.file.filetype[0]] || 'text',
      value: text.replace(/^[ ]+/gm, function(leadingSpace) {
        return leadingSpace.replace(/[ ]{4}/g, '\t');
      }),
      lineNumbers: true,
      tabSize: 4,
      indentUnit: 4,
      indentWithTabs: true
    });
    return this.editor.on('change', this.autosave.bind(this));
  };

  TextEditor.prototype.save = function*(autosaving) {
    var _ref;
    if (autosaving == null) {
      autosaving = false;
    }
    try {
      yield TextEditor.__super__.save.apply(this, arguments);
      return this.error = void 0;
    } catch (exception) {
      if (exception instanceof SyntaxError || ((_ref = exception.message) != null ? _ref.match(/Parse error/) : void 0)) {
        if (autosaving || !confirm("" + exception.name + ": '" + exception.message + "'. Close anyway?")) {
          this.error = exception;
          return yield function() {};
        }
      }
    }
  };

  TextEditor.prototype.focus = function() {
    this.editor.refresh();
    return this.editor.focus();
  };

  return TextEditor;

}).call(this, ide.editor);
