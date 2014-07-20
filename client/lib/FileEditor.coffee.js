var FileEditor, TextEditor,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

FileEditor = (function() {

  FileEditor.open = function*(file) {
    var Editor, data, _ref;
    data = yield this.file.read();
    if (file.extension[0] === 'json') {
      if (Editor = DataEditor.extensions[file.extension[1]]) {
        this.editor = new Editor(file, data);
      }
    }
    return (_ref = this.editor) != null ? _ref : this.editor = new TextEditor(file, data);
  };

  function FileEditor(file, data) {
    this.file = file;
  }

  return FileEditor;

})();

TextEditor = (function(_super) {

  __extends(TextEditor, _super);

  function TextEditor(file, data) {
    TextEditor.__super__.constructor.call(this, file);
    TextEditor.extensions[file.extension[0]];
  }

  return TextEditor;

})(FileEditor);
