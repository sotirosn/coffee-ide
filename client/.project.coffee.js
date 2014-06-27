
(function(project) {
  (function() {
    var icon, log, tab;
    log = new html.log;
    tab = null;
    return icon = project.addIcon('build', function*() {
      var stderr, stdout, _ref;
      if (tab == null) {
        tab = app.rightpane.createTab('build:client', log.element);
      }
      log.start('build:client');
      try {
        _ref = yield http.get("exec/" + this.pathname + " cake build:client"), stdout = _ref[0], stderr = _ref[1];
      } catch (exception) {
        icon.error(exception);
        log.stderr(exception);
        return;
      }
      log.stdout(stdout);
      return log.stderr(stderr);
    });
  })();
  return (function() {
    var icon;
    return icon = project.addIcon('save', project.save);
  })();
});
