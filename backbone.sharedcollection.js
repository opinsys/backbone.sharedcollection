(function() {
  var S4, log,
    __slice = Array.prototype.slice,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  if (localStorage.debugSharedCollection && (typeof console !== "undefined" && console !== null ? console.log : void 0)) {
    log = function() {
      var msg;
      msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      msg.unshift("SharedCollection:");
      return console.log.apply(console, msg);
    };
  } else {
    log = function() {};
  }

  S4 = function() {
    return (((1 + Math.random()) * 65536) | 0).toString(16).substring(1);
  };

  Backbone.sync = function(method, model, options) {
    if (method === "delete") return options.success();
  };

  Backbone.SharedCollection = (function(_super) {

    __extends(SharedCollection, _super);

    SharedCollection.version = "0.1.0";

    SharedCollection.prototype.model = Backbone.Model;

    SharedCollection.generateGUID = function() {
      return S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4();
    };

    function SharedCollection(models, opts) {
      if (opts == null) opts = {};
      this.captureError = __bind(this.captureError, this);
      this.classMap = {};
      if (opts.modelClasses) this.mapTypes(opts.modelClasses);
      this._addingQueue = [];
      if (opts.sharejsDoc) this._setShareJSDoc(opts.sharejsDoc);
      if (!(this.collectionId = opts.collectionId)) {
        throw new Error("SharedCollection needs a collectionId in options!");
      }
      SharedCollection.__super__.constructor.apply(this, arguments);
    }

    SharedCollection.prototype.mapTypes = function(modelClasses) {
      var Model, existing, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = modelClasses.length; _i < _len; _i++) {
        Model = modelClasses[_i];
        if (!Model.prototype.type) {
          throw new Error("Model class " + Model.prototype.constructor.name + " is missing `type` attribute.");
        }
        if (existing = this.classMap[Model.prototype.type]) {
          if (existing !== Model) {
            throw new Error("Type id collision. " + Model.prototype.constructor.name + " and " + existing.prototype.constructor.name + " have the same type-property!");
          }
        }
        _results.push(this.classMap[Model.prototype.type] = Model);
      }
      return _results;
    };

    SharedCollection.prototype.captureError = function(model, method) {
      var _this = this;
      return function(err) {
        if (err) {
          log("Sync error! " + method + ":", err);
          return model.trigger("syncerror", model, method, err);
        }
      };
    };

    SharedCollection.prototype.create = function(model, options) {
      var Model, attrs;
      if (options == null) options = {};
      if (!(model instanceof Backbone.Model)) {
        attrs = model;
        Model = this.classMap[attrs.__type] || this.model;
        model = new Model(attrs, {
          collection: this
        });
        if (model.validate && !model._performValidation(attrs, options)) {
          return false;
        }
      }
      if (!model.collection) model.collection = this;
      this.add(model, options);
      return model;
    };

    SharedCollection.prototype._setShareJSDoc = function(doc) {
      var _this = this;
      this._syncDoc = doc;
      return doc.connection.on("disconnect", function() {
        return _this.trigger("disconnect", _this, doc);
      });
    };

    SharedCollection.prototype.fetch = function(options) {
      var callbackWrapper,
        _this = this;
      if (options == null) options = {};
      if (this.fetched) return cb();
      this.fetched = true;
      callbackWrapper = function(err) {
        if (err) {
          return options != null ? typeof options.error === "function" ? options.error(err) : void 0 : void 0;
        } else {
          _this.trigger("syncload");
          _this.connected = true;
          _this._flushAddingQueue();
          _this.trigger("connect", _this);
          return options != null ? typeof options.success === "function" ? options.success() : void 0 : void 0;
        }
      };
      if (options.sharejsDoc) this._setShareJSDoc(options.sharejsDoc);
      if (this._syncDoc.type.name !== "json") {
        throw new Error("The ShareJS document type must be 'json', not '" + this._syncDoc.type.name + "'");
      }
      this._bindSendOperations();
      this._initSyncDoc(function(err) {
        if (err) return callbackWrapper(err);
        return _this._initCollection(function(err) {
          if (err) return callbackWrapper(err);
          return _this._loadModelsFromSyncDoc(callbackWrapper);
        });
      });
      return this._syncDoc.on("remoteop", function(operations) {
        var op, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = operations.length; _i < _len; _i++) {
          op = operations[_i];
          if (op.p[0] === _this.collectionId) {
            _results.push(_this.parse(op));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
    };

    SharedCollection.prototype._flushAddingQueue = function() {
      var model, _results;
      _results = [];
      while (model = this._addingQueue.shift()) {
        _results.push(this.add(model));
      }
      return _results;
    };

    SharedCollection.prototype._initSyncDoc = function(cb) {
      if (!this._syncDoc.created) return cb();
      if (this._syncDoc.snapshot) return cb();
      log("Creating new sync doc");
      return this._syncDoc.submitOp([
        {
          p: [],
          oi: {}
        }
      ], cb);
    };

    SharedCollection.prototype._initCollection = function(cb) {
      if (this._syncDoc.snapshot[this.collectionId]) return cb();
      log("Adding new collection to syncdoc: " + this.collectionId);
      return this._syncDoc.submitOp([
        {
          p: [this.collectionId],
          oi: {}
        }
      ], cb);
    };

    SharedCollection.prototype._loadModelsFromSyncDoc = function(cb) {
      var id, json, modelMap;
      if (cb == null) cb = function() {};
      if (modelMap = this._syncDoc.snapshot[this.collectionId]) {
        for (id in modelMap) {
          json = modelMap[id];
          this.create(json);
        }
        return cb();
      } else {
        log("Creating collection " + this.collectionId);
        return this._syncDoc.submitOp([
          {
            p: [this.collectionId],
            oi: {}
          }
        ], cb);
      }
    };

    SharedCollection.prototype._bindSendOperations = function() {
      var _this = this;
      this.bind("change", function(model, options) {
        if (!(options != null ? options.local : void 0)) {
          return _this._sendModelChange(model);
        }
      });
      this.bind("add", function(model, collection, options) {
        if (!(options != null ? options.local : void 0)) {
          return _this._sendModelAdd(model);
        }
      });
      return this.bind("destroy", function(model, collection, options) {
        if (!(options != null ? options.local : void 0)) {
          return _this._sendModelDestroy(model);
        }
      });
    };

    SharedCollection.prototype._sendModelChange = function(model) {
      var attribute, operations, value;
      operations = (function() {
        var _ref, _results;
        _ref = model.changedAttributes();
        _results = [];
        for (attribute in _ref) {
          value = _ref[attribute];
          log("SEND CHANGE: " + model.id + ": " + attribute + ": " + value);
          _results.push({
            p: [this.collectionId, model.id, attribute],
            oi: value
          });
        }
        return _results;
      }).call(this);
      if (!this._syncDoc.snapshot[this.collectionId][model.id]) {
        throw new Error("ERROR: snapshot has no model with id " + model.id);
      }
      if (operations.length !== 0) {
        return this._syncDoc.submitOp(operations, this.captureError(model, "change"));
      }
    };

    SharedCollection.prototype._sendModelAdd = function(model, options) {
      var attrs, _ref;
      if (!model.id) {
        model.set({
          id: SharedCollection.generateGUID()
        });
      }
      if ((_ref = this._syncDoc.snapshot[this.collectionId]) != null ? _ref[model.id] : void 0) {
        return;
      }
      log("SEND ADD " + model.id + ": " + (JSON.stringify(model.toJSON())));
      attrs = model.toJSON();
      if (model.type) {
        if (!this.classMap[model.type]) {
          throw new Error("Cannot serialize model. Unkown type: '" + model.type + "'. You must add this model class to `modelClasses` options when creating this collection");
        }
        attrs.__type = model.type;
      }
      return this._syncDoc.submitOp([
        {
          p: [this.collectionId, model.id],
          oi: attrs
        }
      ], this.captureError(model, "add"));
    };

    SharedCollection.prototype._sendModelDestroy = function(model) {
      log("SEND REMOVE " + model.id);
      return this._syncDoc.submitOp([
        {
          p: [this.collectionId, model.id],
          od: true
        }
      ], this.captureError(model, "destroy"));
    };

    SharedCollection.prototype.parse = function(op) {
      if (op.p.length === 2) {
        if (op.oi) return this._receiveModelAdd(op);
        if (op.od) return this._receiveModelDestroy(op);
      }
      if (op.p[2]) return this._receiveModelChange(op);
      return log("Unkown model operation " + (JSON.stringify(op)));
    };

    SharedCollection.prototype._receiveModelAdd = function(op) {
      log("RECEIVE ADD " + op.oi.id + ": " + (JSON.stringify(op.oi)));
      return this.create(op.oi, {
        local: true,
        remote: true
      });
    };

    SharedCollection.prototype._receiveModelDestroy = function(op) {
      var model, modelId;
      modelId = op.p[1];
      model = this.get(modelId);
      if (!model) {
        throw new Error("Remote asked to remove non existing model " + modelId);
      }
      log("RECEIVE REMOVE " + model.id + ": " + (JSON.stringify(modelId)));
      model.destroy({
        local: true,
        remote: true
      });
      if (this._syncDoc.snapshot[this.collectionId][modelId]) {
        return log("ERROR: Model exists after deletion! " + modelId);
      }
    };

    SharedCollection.prototype._receiveModelChange = function(op) {
      var attrName, attrValue, model, modelId, ob;
      modelId = op.p[1];
      attrName = op.p[2];
      attrValue = op.oi;
      model = this.get(modelId);
      if (!model) {
        throw new Error("Remote asked to update non existing model: " + model.id + " " + modelId);
      }
      log("RECEIVE CHANGE " + model.id + ": " + attrName + ": " + attrValue);
      ob = {};
      ob[attrName] = attrValue;
      return model.set(ob, {
        local: true,
        remote: true
      });
    };

    SharedCollection.prototype.add = function(models, options) {
      var m, model, _i, _len;
      if (!models || models.length === 0) return this;
      if (!_.isArray(models)) models = [models];
      if (!this.fetched) {
        while (model = models.shift()) {
          console.log("Adding " + (model.get("name")) + " to queue");
          this._addingQueue.push(model);
        }
        return this;
      }
      for (_i = 0, _len = models.length; _i < _len; _i++) {
        m = models[_i];
        this._sendModelAdd(m, options);
      }
      SharedCollection.__super__.add.apply(this, arguments);
      return this;
    };

    return SharedCollection;

  })(Backbone.Collection);

}).call(this);
