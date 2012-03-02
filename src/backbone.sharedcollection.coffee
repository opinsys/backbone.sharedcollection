

if localStorage.debugSharedCollection and console?.log
  log = (msg...) ->
    msg.unshift "SharedCollection:"
    console.log.apply console, msg
else
  log = ->


S4 = -> (((1 + Math.random()) * 65536) | 0).toString(16).substring(1)



Backbone.sync = (method, model, options) ->
  # Call options.success() callback to trigger destroy event which triggers
  # synchronization to other browsers.
  if method is "delete"
    options.success()

class Backbone.SharedCollection extends Backbone.Collection

  @version = "0.1.0"

  model: Backbone.Model

  @generateGUID = ->
    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()

  constructor: (models, opts={}) ->
    @classMap = {}
    @mapTypes opts.modelClasses if opts.modelClasses

    @_addingQueue = []

    if opts.sharejsDoc
      @_setShareJSDoc opts.sharejsDoc

    if not @collectionId = opts.collectionId
      throw new Error "SharedCollection needs a collectionId in options!"

    super

  mapTypes: (modelClasses) ->
    for Model in modelClasses

      if not Model::type
        throw new Error "Model class #{ Model::constructor.name } is missing `type` attribute."

      if existing = @classMap[Model::type]
        if existing isnt Model
          throw new Error "Type id collision. #{ Model::constructor.name } and #{ existing::constructor.name } have the same type-property!"

      @classMap[Model::type] = Model

  captureError: (model, method) => (err) =>
    if err
      log "Sync error! #{ method }:", err
      model.trigger "syncerror", model, method, err


  create: (model, options={}) ->

    if not (model instanceof Backbone.Model)
      attrs = model
      Model = @classMap[attrs.__type] or @model
      model = new Model attrs,
        collection: this
      if model.validate and not model._performValidation(attrs, options)
        return false

    if not model.collection
      model.collection = this

    @add model, options
    return model

  _setShareJSDoc: (doc) ->
    @_syncDoc = doc
    doc.connection.on "disconnect", =>
      @trigger "disconnect", this, doc

  fetch: (options={}) ->
    # Fetch can be called only once
    if @fetched
      return cb()
    @fetched = true

    # Convert Backbone.js style object callback to Node.js style callback
    callbackWrapper = (err) =>
      if err
        options?.error? err
      else
        @trigger "syncload"
        @connected = true
        @_flushAddingQueue()
        @trigger "connect", this
        options?.success?()

    if options.sharejsDoc
      @_setShareJSDoc options.sharejsDoc

    if @_syncDoc.type.name isnt "json"
      throw new Error "The ShareJS document type must be 'json', not '#{ @_syncDoc.type.name }'"

    @_bindSendOperations()

    # TODO: Clean up before this is the pyramid of doom
    @_initSyncDoc (err) =>
      return callbackWrapper err if err
      @_initCollection (err) =>
        return callbackWrapper err if err
        @_loadModelsFromSyncDoc callbackWrapper




    # And also bind receive operations:
    @_syncDoc.on "remoteop", (operations) =>
      for op in operations

        # If first part in operation path is @collectionId this operation is a
        # change to some of our models
        if op.p[0] is @collectionId
          @parse op


  _flushAddingQueue: ->
    while model = @_addingQueue.shift()
      @add model

  _initSyncDoc: (cb) ->

    if not @_syncDoc.created
      return cb()

    if @_syncDoc.snapshot
      return cb()

    log "Creating new sync doc"
    @_syncDoc.submitOp [
      p: []
      oi: {}
    ], cb

  _initCollection: (cb) ->
    if @_syncDoc.snapshot[@collectionId]
      return cb()

    log "Adding new collection to syncdoc: #{ @collectionId }"
    @_syncDoc.submitOp [
      p: [@collectionId]
      oi: {}
    ], cb

  _loadModelsFromSyncDoc: (cb=->) ->
    if modelMap = @_syncDoc.snapshot[@collectionId]
      for id, json of modelMap
        @create json
      cb()
    else
      log "Creating collection #{ @collectionId }"
      @_syncDoc.submitOp [
        p: [@collectionId]
        oi: {}
      ], cb



  _bindSendOperations: ->

    @bind "change", (model, options) =>
      @_sendModelChange model unless options?.local

    @bind "add", (model, collection, options) =>
      @_sendModelAdd model unless options?.local

    @bind "destroy", (model, collection, options) =>
      @_sendModelDestroy model unless options?.local


  _sendModelChange: (model) ->

    operations = for attribute, value of model.changedAttributes()

      log "SEND CHANGE: #{ model.id }: #{ attribute }: #{ value }"
      { p: [@collectionId , model.id, attribute ],  oi: value }


    if not @_syncDoc.snapshot[@collectionId][model.id]
      throw new Error  "ERROR: snapshot has no model with id #{ model.id }"

    if operations.length isnt 0
      @_syncDoc.submitOp operations, @captureError(model, "change")


  _sendModelAdd: (model, options) ->

    # Models in shared collection must have unique id. Create one if user did
    # not give one.
    if not model.id
      model.set id: SharedCollection.generateGUID()

    # Just ignore readds
    if @_syncDoc.snapshot[this.collectionId]?[model.id]
      return


    log "SEND ADD #{ model.id }: #{ JSON.stringify model.toJSON() }"

    attrs = model.toJSON()

    # If model has type property we must put it with serialized attributes so
    # that it can be properly deserialized in the other end.
    if model.type
      if not @classMap[model.type]
        throw new Error "Cannot serialize model. Unkown type: '#{ model.type }'. You must add this model class to `modelClasses` options when creating this collection"
      attrs.__type = model.type

    @_syncDoc.submitOp [
      p: [@collectionId , model.id]
      oi: attrs
    ], @captureError(model, "add")


  _sendModelDestroy: (model) ->

    log "SEND REMOVE #{ model.id }"

    @_syncDoc.submitOp [
      p: [@collectionId , model.id]
      od: true
    ], @captureError(model, "destroy")



  parse: (op) ->

    # If path has form of [ @collectionId , modelId ] it must be add or remove
    if op.p.length is 2

      # We have insert object
      if op.oi
        return @_receiveModelAdd op

      # We have delete object
      if op.od
        return @_receiveModelDestroy op

    # If we have a third item in path it means that this is an attribute
    # update to existing model.
    if op.p[2]
      return @_receiveModelChange op


    log "Unkown model operation #{ JSON.stringify op }"


  _receiveModelAdd: (op) ->

    log "RECEIVE ADD #{ op.oi.id }: #{ JSON.stringify op.oi }"

    @create op.oi,
      local: true
      remote: true


  _receiveModelDestroy: (op) ->
    modelId = op.p[1]

    model = @get modelId
    if not model
      throw new Error "Remote asked to remove non existing model #{ modelId }"

    log "RECEIVE REMOVE #{ model.id }: #{ JSON.stringify modelId }"


    model.destroy
      local: true
      remote: true

    if @_syncDoc.snapshot[@collectionId][modelId]
      log "ERROR: Model exists after deletion! #{ modelId }"


  _receiveModelChange: (op) ->
    modelId = op.p[1]
    attrName = op.p[2]
    attrValue = op.oi


    model = @get modelId
    if not model
      throw new Error "Remote asked to update non existing model: #{ model.id } #{ modelId }"

    log "RECEIVE CHANGE #{ model.id }: #{ attrName }: #{ attrValue }"

    ob = {}
    ob[attrName] = attrValue
    model.set ob,
      local: true
      remote: true


  add: (models, options) ->

    if not models or models.length is 0
      return this

    if not _.isArray models
      models = [ models ]

    if not @fetched
      while model = models.shift()
        console.log "Adding #{ model.get "name" } to queue"
        @_addingQueue.push model
      return this

    for m in models
      @_sendModelAdd m, options

    super

    return this


