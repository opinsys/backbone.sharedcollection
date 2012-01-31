
log = (msg...) ->
  msg.unshift "SharedCollection:"
  console?.log.apply console, msg

S4 = -> (((1 + Math.random()) * 65536) | 0).toString(16).substring(1)


# Convert Backone.js style options object based callbacks to Node.js style
# single function callbacks used in ShareJS
optionsCbToNodeCb = (options) -> (err) ->
  if err
    options?.error?()
  else
    options?.success?()


Backbone.sync = (method, model, options) ->
  console.log "METHOD", method

  # Call options.success() callback to trigger destroy event which triggers
  # synchronization to other browsers.
  if method is "delete"
    options.success()

class Backbone.SharedCollection extends Backbone.Collection

  model: Backbone.Model

  @generateGUID = ->
    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()

  constructor: (models, opts={}) ->
    @classMap = {}
    @mapTypes opts.modelClasses if opts.modelClasses

    if opts.sharejsDoc
      @_syncDoc = opts.sharejsDoc

    if not @collectionId = opts.collectionId
      throw new Error "SharedCollection needs a collectionId in options!"

    super

  mapTypes: (modelClasses) ->
    for Model in modelClasses
      if not Model::type
        throw new Error "Model class #{ Model::constructor.name } is missing `type` attribute."
      @classMap[Model::type] = Model

  captureError: (model, method) => (err) =>
    if err
      log "Sync error!", err
      @trigger "sharejserror", err, model

  create: (model, options={}) ->

    if not (model instanceof Backbone.Model)
      attrs = model
      Model = @classMap[attrs.type] or @model
      model = new Model attrs,
        collection: this
      if model.validate and not model._performValidation(attrs, options)
        return false

    if not model.collection
      model.collection = this


    @add model, options
    return model


  fetch: (options={}) ->

    if options.sharejsDoc
      @_syncDoc = options.sharejsDoc

    if @_syncDoc.type.name isnt "json"
      throw new Error "The ShareJS document type must be 'json', not '#{ @_syncDoc.type.name }'"

    cb = optionsCbToNodeCb options

    if @_syncDoc.created
      @_initSyncDoc cb
    else
      @_loadModelsFromSyncDoc cb

    @_bindSendOperations()


    # And also bind receive operations:
    @_syncDoc.on "remoteop", (operations) =>
      for op in operations

        # If first part in operation path is @collectionId this operation is a
        # change to some of our models
        if op.p[0] is @collectionId
          @parse op


  _initSyncDoc: (cb) ->
    log "Creating new sync doc with #{ @collectionId }"
    ob = {}
    ob[@collectionId] = {}
    @_syncDoc.submitOp [
      p: []
      oi: ob
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
      if options?.local
        console.log "LOCAL change"
      @_sendModelChange model unless options?.local

    @bind "add", (model, collection, options) =>
      if options?.local
        console.log "LOCAL add"
      @_sendModelAdd model unless options?.local

    @bind "destroy", (model, collection, options) =>
      if options?.local
        console.log "LOCAL destroy"
      @_sendModelDestroy model unless options?.local


  _sendModelChange: (model) ->

    operations = for attribute, value of model.changedAttributes()

      log "SEND CHANGE: #{ model.id }: #{ attribute }: #{ value }"
      { p: [@collectionId , model.id, attribute ],  oi: value }


    if not @_syncDoc.snapshot[@collectionId][model.id]
      throw new Error  "ERROR: snapshot has no model with id #{ model.id }"

    if operations.length isnt 0
      @_syncDoc.submitOp operations, @captureError(model, "change")


  _sendModelAdd: (model) ->

    # Models in shared collection must have unique id. Create one if user did
    # not give one.
    if not model.id
      model.set id: SharedCollection.generateGUID()

    # Just ignore readds
    if @_syncDoc.snapshot[this.collectionId][model.id]
      return

    log "SEND ADD #{ model.id }: #{ JSON.stringify model.toJSON() }"

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

    @create op.oi, local: true


  _receiveModelDestroy: (op) ->
    modelId = op.p[1]

    model = @get modelId
    if not model
      throw new Error "Remote asked to remove non existing model #{ modelId }"

    log "RECEIVE REMOVE #{ model.id }: #{ JSON.stringify modelId }"


    model.destroy local: true

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
    model.set ob, local: true


  add: (models) ->
    if models.length is 0
      return


    if _.isArray models
      for m in models
        @_sendModelAdd m
    else
      @_sendModelAdd models

    super

    return this


  getOrCreate: (id, Model=Backbone.Model) ->

    if model = @get id
      log "getOrCreate: Got!"
      return model

    log "getOrCreate: creating!"
    model = new Model id: id
    @add model
    return model








