var Application, Directory, Project, ServerProject, SourceFolder, User, app, log, sourcedir, spawn, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

log = console.log.bind(console);

sourcedir = "/Users/Nick/coffee-ide/newserver";

spawn = require("child_process").spawn;

_ref = require("" + sourcedir + "/Path"), User = _ref.User, Directory = _ref.Directory, Project = _ref.Project, SourceFolder = _ref.SourceFolder;

Application = require("" + sourcedir + "/Application");

ServerProject = (function(_super) {

  __extends(ServerProject, _super);

  function ServerProject() {
    return ServerProject.__super__.constructor.apply(this, arguments);
  }

  ServerProject.prototype.run = function() {
    var child;
    child = spawn("coffee --nodejs --harmony_generators server.coffee");
    app.processes[child.pid] = child;
    return child.pid;
  };

  ServerProject.commands('run');

  return ServerProject;

})(Project);

app = Application.create();

app.users = {
  developer: new User({
    password: '$masterDev',
    path: '/Users/Nick/coffee-ide',
    isVirtual: true,
    dirmap: {
      project: new Project({
        path: '.'
      }),
      client: new Project({
        path: 'newclient',
        dirmap: {
          source: new SourceFolder({
            path: 'source',
            targetdir: '../lib'
          })
        }
      }),
      server: new ServerProject({
        path: 'newserver'
      })
    }
  })
};
