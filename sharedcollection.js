(function() {
  var S4, log;
  var __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  log = function() {
    var msg;
    msg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    msg.unshift("SharedCollection:");
    return typeof console !== "undefined" && console !== null ? console.log.apply(console, msg) : void 0;
  };

  S4 = function() {
    return (((1 + Math.random()) * 65536) | 0).toString(16).substring(1);
  };

  Backbone.SharedCollection = (function() {

    __extends(SharedCollection, Backbone.Collection);

    SharedCollection.generateGUID = function() {
      return S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4();
    };

    function SharedCollection(models, opts) {
      this.modelTypes = opts.modelTypes || {};
      if (!(this.collectionId = opts.collectionId)) {
        throw new Error("SharedCollection needs a collectionId in options!");
      }
      SharedCollection.__super__.constructor.apply(this, arguments);
    }

    SharedCollection.prototype._initModel = function(json) {
      var Model;
      Model = this.modelTypes[json.type];
      if (!Model) {
        log("DEBUG: no custom model found for type '" + json.type + "' id: " + json.id);
        Model = Backbone.Model;
      }
      if (!json.id) {
        log("DEBUG: User did not give an id. generating one");
        json.id = SharedCollection.generateGUID;
      }
      return this.add(new Model(json));
    };

    SharedCollection.prototype._setConnected = function() {
      if (this.connected) return;
      this.connected = true;
      return this.trigger("connect", this);
    };

    SharedCollection.prototype.connect = function(sharejsDoc, cb) {
      var _this = this;
      if (cb == null) cb = function() {};
      this._syncDoc = sharejsDoc;
      this._syncAttributes = {};
      if (this._syncDoc.created && !this._syncDoc._bb_collection_inited) {
        this._initSyncDoc(cb);
      } else {
        this._loadModelsFromSyncDoc(cb);
      }
      this._bindSendOperations();
      return this._syncDoc.on("remoteop", function(operations) {
        var op, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = operations.length; _i < _len; _i++) {
          op = operations[_i];
          if (op.p[0] === _this.collectionId) {
            _results.push(_this._receiveModelOperation(op));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
    };

    SharedCollection.prototype._initSyncDoc = function(cb) {
      var ob;
      var _this = this;
      log("Creating new sync doc with " + this.collectionId);
      ob = {};
      ob[this.collectionId] = {};
      return this._syncDoc.submitOp([
        {
          p: [],
          oi: ob
        }
      ], function() {
        _this._syncDoc._bb_collection_inited = true;
        _this._setConnected();
        return cb();
      });
    };

    SharedCollection.prototype._loadModelsFromSyncDoc = function(cb) {
      var id, json, modelMap;
      var _this = this;
      if (modelMap = this._syncDoc.snapshot[this.collectionId]) {
        this._setConnected();
        for (id in modelMap) {
          json = modelMap[id];
          this._initModel(json);
        }
        return cb();
      } else {
        log("Creating collection " + this.collectionId);
        return this._syncDoc.submitOp([
          {
            p: [this.collectionId],
            oi: {}
          }
        ], function() {
          _this._setConnected();
          return cb();
        });
      }
    };

    SharedCollection.prototype._bindSendOperations = function() {
      var _this = this;
      this.bind("change", function(model) {
        if (model._syncOk) {
          return _this._sendModelChange(model);
        } else {
          return log("Model '" + model.id + "' is not in sync machinery yet. Skipping change event");
        }
      });
      this.bind("add", function(model) {
        return _this._sendModelAdd(model);
      });
      return this.bind("destroy", function(model) {
        return _this._sendModelDestroy(model);
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
          if (this._syncAttributes[attribute] === value) {
            delete this._syncAttributes[attribute];
            continue;
          }
          log("SEND CHANGE: " + model.id + ": " + attribute + ": " + value);
          _results.push({
            p: [this.collectionId, model.id, attribute],
            oi: value
          });
        }
        return _results;
      }).call(this);
      if (!this._syncDoc.snapshot[this.collectionId][model.id]) {
        log("ERROR: snapshot has no this model " + model.id);
      }
      if (operations.length !== 0) return this._syncDoc.submitOp(operations);
    };

    SharedCollection.prototype._sendModelAdd = function(model) {
      if (this._syncAdded === model.id) {
        this._syncAdded = null;
        return;
      }
      log("SEND ADD " + model.id + ": " + (JSON.stringify(model.toJSON())));
      return this._syncDoc.submitOp([
        {
          p: [this.collectionId, model.id],
          oi: model.toJSON()
        }
      ]);
    };

    SharedCollection.prototype._sendModelDestroy = function(model) {
      if (this._syncRemoved === model.id) {
        this._syncRemoved = null;
        return;
      }
      log("SEND REMOVE " + model.id);
      return this._syncDoc.submitOp([
        {
          p: [this.collectionId, model.id],
          od: true
        }
      ]);
    };

    SharedCollection.prototype._receiveModelOperation = function(op) {
      if (op.p.length === 2) {
        if (op.oi) return this._receiveModelAdd(op);
        if (op.od) return this._receiveModelDestroy(op);
      }
      if (op.p[2]) return this._receiveModelChange(op);
      return log("Unkown model operation " + (JSON.stringify(op)));
    };

    SharedCollection.prototype._receiveModelAdd = function(op) {
      log("RECEIVE ADD " + op.oi.id + ": " + (JSON.stringify(op.oi)));
      this._syncAdded = op.oi.id;
      return this._initModel(op.oi);
    };

    SharedCollection.prototype._receiveModelDestroy = function(op) {
      var model, modelId;
      modelId = op.p[1];
      model = this.get(modelId);
      if (!model) {
        log("ERROR: Remote asked to remove non existing model " + modelId);
        return;
      }
      log("RECEIVE REMOVE " + model.id + ": " + (JSON.stringify(modelId)));
      this._syncRemoved = model.id;
      model.destroy();
      if (this._syncDoc.snapshot[this.collectionId][modelId]) {
        return log("ERROR: Model exists after deletion! " + modelId);
      }
    };

    SharedCollection.prototype._receiveModelChange = function(op) {
      var attrName, attrValue, model, modelId;
      modelId = op.p[1];
      attrName = op.p[2];
      attrValue = op.oi;
      model = this.get(modelId);
      if (!model) {
        log("ERROR: Remote asked to update non existing model: " + model.id + " " + modelId);
        return;
      }
      log("RECEIVE CHANGE " + model.id + ": " + attrName + ": " + attrValue);
      this._syncAttributes[attrName] = attrValue;
      return model.set(this._syncAttributes);
    };

    SharedCollection.prototype.add = function(models) {
      var m, _i, _len;
      if (models.length === 0) return;
      if (!this.connected) {
        throw new Error("SharedCollection must be connected to ShareJS document before models can be added to it!");
      }
      SharedCollection.__super__.add.apply(this, arguments);
      if (_.isArray(models)) {
        for (_i = 0, _len = models.length; _i < _len; _i++) {
          m = models[_i];
          m._syncOk = true;
        }
      } else {
        models._syncOk = true;
      }
      return this;
    };

    SharedCollection.prototype.getOrCreate = function(id, Model) {
      var model;
      if (Model == null) Model = Backbone.Model;
      if (model = this.get(id)) {
        log("getOrCreate: Got!");
        return model;
      }
      log("getOrCreate: creating!");
      model = new Model({
        id: id
      });
      this.add(model);
      return model;
    };

    return SharedCollection;

  })();

}).call(this);
