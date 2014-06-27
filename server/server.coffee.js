// Generated by CoffeeScript 1.3.3
var Application, Routine, app, getpostdata, http, io, log, run,
  __slice = [].slice;

log = console.log.bind(console);

io = require('socket.io');

http = require('express');

log(process.argv);

Routine = (function() {

  function Routine(name, iterator, onerror) {
    this.name = name;
    this.iterator = iterator;
    this.onerror = onerror != null ? onerror : function(error) {
      throw error;
    };
    this.onend = this.onend.bind(this);
  }

  Routine.prototype.next = function(value) {
    try {
      this.resume(value);
    } catch (exception) {
      this.onerror(exception);
    }
    return this.onend;
  };

  Routine.prototype["throw"] = function(exception) {
    try {
      return this.iterator["throw"](exception);
    } catch (exception) {
      return this.onerror(exception);
    }
  };

  Routine.prototype.resume = function(value) {
    var next;
    next = this.iterator.next(value);
    if (!next.done) {
      if (this.name) {
        log("resuming " + this.name);
      }
      return next.value(this);
    } else if (this.end != null) {
      if (this.name) {
        log("finished " + this.name);
      }
      return this.end.resume(next.value);
    }
  };

  Routine.prototype.onend = function(end) {
    this.end = end;
    if (this.name) {
      return log("" + this.name + " waiting on -> " + (this.end.name || this.end));
    }
  };

  return Routine;

})();

run = function(routine, name) {
  return function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (name) {
      log("running " + name);
    }
    return (new Routine(name, routine.apply(null, args), args[2])).next();
  };
};

Application = (function() {

  Application.prototype.fs = require('fs');

  Application.prototype.pm = require('child_process');

  Application.prototype.processes = {};

  function Application(mountpoints) {
    this.mountpoints = mountpoints != null ? mountpoints : {};
    this.readfile = this.readfile.bind(this);
    this.listdir = this.listdir.bind(this);
  }

  Application.prototype.readfile = function(path) {
    var _this = this;
    return function(wait) {
      return _this.fs.readFile(path, {
        encoding: 'utf8'
      }, function(error, data) {
        if (error != null) {
          return wait["throw"](error);
        }
        return wait.next(data);
      });
    };
  };

  Application.prototype.writefile = function(path, data) {
    var _this = this;
    return function(wait) {
      return _this.fs.writeFile(path, data, function(error, data) {
        if (error != null) {
          return wait["throw"](error);
        }
        return wait.next();
      });
    };
  };

  Application.prototype.listdir = function(path) {
    var _this = this;
    return function(wait) {
      return _this.fs.readdir(path, function(error, data) {
        if (error != null) {
          return wait["throw"](error);
        }
        return wait.next(data);
      });
    };
  };

  Application.prototype.exec = function(path, command) {
    var _this = this;
    return function(wait) {
      return _this.pm.exec("cd " + path + " && call ./" + command, function(error, stdout, stderr) {
        if (error != null) {
          return wait["throw"](error);
        }
        return wait.next([stdout, stderr]);
      });
    };
  };

  Application.prototype.run = function(path, command) {
    var child;
    child = this.pm.spawn('cmd', ['/C', "cd " + path + " && call ./" + command]);
    this.processes[child.pid] = child;
    return child.pid;
  };

  Application.prototype.connect = function(connection, pid) {
    var child,
      _this = this;
    child = this.processes[pid];
    if (!(child != null)) {
      connection.emit('stderr', "pid (" + pid + ") not found!");
      connection.disconnect();
      return;
    }
    child.stdout.on('data', function(data) {
      return connection.emit('stdout', data.toString());
    });
    child.stderr.on('data', function(data) {
      return connection.emit('stderr', data.toString());
    });
    child.on('close', function(exitcode) {
      log("closed (" + pid + ") " + exitcode);
      if (exitcode !== 0) {
        connection.emit('stderr', "exitcode: " + exitcode);
      }
      connection.disconnect();
      return delete _this.processes[pid];
    });
    return connection.on('disconnect', function() {
      log("killing task (" + pid + ")");
      return _this.pm.exec("taskkill /PID " + pid + " /T /F");
    });
  };

  Application.prototype.resolvepath = function(params) {
    var basepath, nextpath;
    basepath = params[0];
    nextpath = params[1];
    if (basepath === '.' || basepath === '') {
      basepath = '.';
    } else {
      basepath = this.mountpoints[basepath];
      if (!(basepath != null)) {
        throw "mountpoint undefined: " + mountpoint;
      }
    }
    return basepath + (nextpath ? '/' + nextpath : '');
  };

  Application.prototype.addProject = function(project) {
    return this.mountpoints[project.name] = project.path;
  };

  return Application;

})();

app = new Application;

run(function*() {
  var data;
  data = yield app.readfile('./config.js');
  return (eval(data))(app);
})();

getpostdata = function(request) {
  return function(wait) {
    var data;
    data = '';
    request.on('data', function(chunck) {
      data += chunck;
      if (data.length > 1e6) {
        request.connection.close();
        return wait["throw"]("POST data too large!");
      }
    });
    return request.on('end', function(chunck) {
      return wait.next(data);
    });
  };
};

http().get('/', function(request, response) {
  return response.sendfile('client/index.html');
}).get('/codemirror/*', function(request, response) {
  return response.sendfile(app.mountpoints['codemirror'] + '/' + request.params[0]);
}).get('/*', function(request, response) {
  return response.sendfile('client/' + request.params[0]);
}).listen(process.argv[2] || 8080);

http().use(function(request, response, next) {
  log(request.url);
  response.set('Access-Control-Allow-Origin', 'http://localhost:8080');
  return next();
}).get('/listdir/*', run(function*(request, response) {
  var dirpath, filelist, filename, results, stats, _i, _len;
  log("path: ", dirpath = app.resolvepath(request.params));
  filelist = yield app.listdir(dirpath);
  results = {};
  for (_i = 0, _len = filelist.length; _i < _len; _i++) {
    filename = filelist[_i];
    stats = app.fs.statSync(dirpath + '/' + filename);
    if (stats.isDirectory()) {
      results[filename] = 'dir';
    } else if (stats.isFile()) {
      results[filename] = 'file';
    }
  }
  return response.json(results);
}, 'listdir')).get('/listdir', function(request, response) {
  log(Object.keys(app.mountpoints));
  return response.json(Object.keys(app.mountpoints));
}).get('/readfile/*/*', run(function*(request, response) {
  var filedata, filepath;
  log("path: " + (filepath = app.resolvepath(request.params)));
  filedata = yield app.readfile(filepath);
  return response.json(filedata);
})).post('/writefile/*/*', run(function*(request, response) {
  var filepath, postdata;
  log("path: " + (filepath = app.resolvepath(request.params)));
  postdata = yield getpostdata(request);
  yield app.writefile(filepath, postdata);
  return response.json("" + (Date.now()) + ": file written: " + filepath);
})).get('/exec/*/*', run(function*(request, response) {
  var command, path, stderr, stdout, _ref;
  log("path: " + (path = app.resolvepath([request.params[0]])));
  log("command: " + (command = request.params[1]));
  _ref = yield app.exec(path, command), stdout = _ref[0], stderr = _ref[1];
  return response.json([stdout, stderr]);
})).get('/run/*/*', function(request, response) {
  var command, path;
  log("path: " + (path = app.resolvepath([request.params[0]])));
  log("command: " + (command = request.params[1]));
  return response.json(app.run(path, command));
}).listen(process.argv[3] || 8090);

(io.listen(process.argv[4] || 9000)).on('connection', function(connection) {
  var pid;
  pid = connection.handshake.query.pid;
  return app.connect(connection, pid);
});