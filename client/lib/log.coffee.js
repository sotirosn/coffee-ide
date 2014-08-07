var Log,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Log = (function(_super) {
  var ErrorMessage, Message;

  __extends(Log, _super);

  function Log() {
    return Log.__super__.constructor.apply(this, arguments);
  }

  Message = (function(_super1) {

    __extends(Message, _super1);

    Message.html('<pre></pre>');

    function Message(text) {
      Message.__super__.constructor.call(this);
      this.element.innerHTML = text;
    }

    return Message;

  })(ide.html);

  ErrorMessage = (function(_super1) {

    __extends(ErrorMessage, _super1);

    ErrorMessage.html('<pre class="error"></pre>');

    function ErrorMessage(text) {
      ErrorMessage.__super__.constructor.call(this);
      this.element.innerHTML = text;
    }

    return ErrorMessage;

  })(ide.html);

  Log.html('<log></log>');

  Log.prototype.focus = function() {};

  Log.prototype.show = function() {
    this.element.innerHTML = '';
    return app.rightpane.addTab(this.tab);
  };

  Log.prototype.error = function(exception) {
    return console.error(exception);
  };

  Log.prototype.stdout = function(text) {
    return this.element.appendChild((new Message(text)).element);
  };

  Log.prototype.stderr = function(text) {
    return this.element.appendChild((new ErrorMessage(text)).element);
  };

  return Log;

}).call(this, ide.html);
