var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

ide.button = (function(_super) {

  __extends(button, _super);

  button.html('<button></button>');

  button.properties({
	label: {
	  set: function(value) {
		return this.element.innerHTML = value;
	  }
	}
  });

  function button(label, onclick) {
	button.__super__.constructor.call(this);
	this.label = label;
	this.element.onclick = this.onclick(onclick);
  }

  return button;

})(ide.html);

(function(project) {
  var runCommand, saveAllCommand;
  project.saveAll = function() {
	var editor, _i, _len, _ref, _results;
	_ref = this.editors;
	_results = [];
	for (_i = 0, _len = _ref.length; _i < _len; _i++) {
	  editor = _ref[_i];
	  if (editor.saving) {
		_results.push(run(editor.save()));
	  } else {
		_results.push(void 0);
	  }
	}
	return _results;
  };
  saveAllCommand = {
	button: project.createButton('save all', function() {
	  return project.saveAll();
	})
  };
  return runCommand = (function() {
	var _this = this;

	function runCommand() {}

	runCommand.console = null;

	runCommand.ports = [7070, 7071, 7072];

	runCommand.button = project.createButton('run', function*() {
	  var consoleID, _ref, _ref1;
	  log(runCommand.button);
	  runCommand.button.enabled = false;
	  try {
		consoleID = yield project.runCommand("run " + (runCommand.ports.join(' ')));
		if ((_ref = runCommand.console) == null) {
		  runCommand.console = ide.console.create("" + project.name + ":run");
		}
		yield runCommand.console.connect(consoleID);
		if ((_ref1 = runCommand.iframe) == null) {
		  runCommand.iframe = ide.iframe.create("" + project.name + ":run");
		}
		yield runCommand.iframe.open("http://localhost:" + runCommand.ports[0] + "?appport=" + runCommand.ports[1] + "&ioport=" + ports[2]);
		return runCommand.button.enabled = true;
	  } catch (error) {
		return runCommand.button.error = error;
	  }
	});

	return runCommand;

  }).call(this);
});
