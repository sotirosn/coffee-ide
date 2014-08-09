var Application, Directory, Project, ServerProject, SourceFolder, User, app, log, sourcedir, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

log = console.log.bind(console);

process.chdir(__dirname);

sourcedir = "../server";

_ref = require("" + sourcedir + "/Path"), User = _ref.User, Directory = _ref.Directory, Project = _ref.Project, SourceFolder = _ref.SourceFolder;

Application = require("" + sourcedir + "/Application");

ServerProject = (function(_super) {
  var ChildProcess, exec, spawn, _ref1;

  __extends(ServerProject, _super);

  log((_ref1 = require('child_process'), spawn = _ref1.spawn, exec = _ref1.exec, _ref1));

  switch (process.platform) {
    case 'win32':
      ChildProcess = (spawn('cmd')).constructor;
      ChildProcess.prototype.kill = function() {
        log("child process (" + this.pid + ") terminated by user");
        return exec("taskkill /F /T /PID " + this.pid, function(error, stdout, stderr) {
          if (error) {
            return console.error(error);
          }
        });
      };
      ServerProject.prototype.spawn = function(command, commandline) {
        return spawn('cmd', ['/K', command].concat(__slice.call(commandline)));
      };
      break;
    default:
      ChildProcess = (spawn('ls')).constructor;
      ChildProcess.prototype.kill = function() {
        log("child process (" + this.pid + ") terminated by user");
        return exec("kill -TERM -" + this.pid, function(error, stdout, stderr) {
          if (error) {
            return console.error(error);
          }
        });
      };
      ServerProject.prototype.spawn = function(command, commandline) {
        return spawn(command, commandline, {
          detach: true
        });
      };
  }

  function ServerProject() {
    ServerProject.__super__.constructor.apply(this, arguments);
    this.processes = app.processes;
  }

  ServerProject.prototype.run = function*() {
    var _this = this;
    return yield function(routine) {
      var child, pid;
      child = _this.spawn('coffee', ['--nodejs', '--harmony_generators', 'server.coffee', 'devel.config.json'], {
        detached: true
      });
      if (pid = child.pid) {
        log("child process (" + pid + ") started");
        _this.processes[pid] = child;
        child.on('exit', function(exitcode) {
          log("child process (" + pid + ") exited with exit code: " + exitcode);
          delete _this.processes[pid];
          if (child.connection) {
            return child.connection.close();
          } else {
            child.stdout.pipe(process.stdout);
            return child.stderr.pipe(process.stderr);
          }
        });
        return routine.next(pid);
      } else {
        log('child process failed to execute');
        return child.on('error', function(error) {
          return routine["throw"](error);
        });
      }
    };
  };

  ServerProject.commands('run');

  return ServerProject;

})(Project);

app = Application.create(process.argv[2]);

app.users = {
  developer: new User({
    password: '$masterDev',
    path: "" + __dirname + "/..",
    isVirtual: true,
    dirmap: {
      project: new Project({
        path: 'project'
      }),
      client: new Project({
        path: 'client',
        dirmap: {
          source: new SourceFolder({
            path: 'source',
            targetdir: '../lib'
          })
        }
      }),
      server: new ServerProject({
        path: 'server'
      })
    }
  })
};
