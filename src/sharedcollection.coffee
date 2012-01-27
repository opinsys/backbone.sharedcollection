
log = (msg...) ->
  msg.unshift "SharedCollection:"
  console?.log.apply console, msg

S4 = -> (((1 + Math.random()) * 65536) | 0).toString(16).substring(1)


class Backbone.SharedCollection extends Backbone.Collection

  @generateGUID = ->
    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()

  constructor: (models, opts) ->
    @modelTypes = opts.modelTypes or {}
    if not @collectionId = opts.collectionId
      throw new Error "SharedCollection needs a collectionId in options!"

    super

  _initModel: (json) ->
    Model = @modelTypes[json.type]

    if not Model
      log "DEBUG: no custom model found for type '#{ json.type }' id: #{ json.id }"
      Model = Backbone.Model

    if not json.id
      log "DEBUG: User did not give an id. generating one"
      json.id = SharedCollection.generateGUID

    @add new Model json

  _setConnected: ->
    return if @connected
    @connected = true
    @trigger "connect", this

  connect: (sharejsDoc, cb=->) ->
    @_syncDoc = sharejsDoc
    @_syncAttributes = {}


    if @_syncDoc.created and not @_syncDoc._bb_collection_inited
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
          @_receiveModelOperation op


  _initSyncDoc: (cb) ->
    log "Creating new sync doc with #{ @collectionId }"
    ob = {}
    ob[@collectionId] = {}
    @_syncDoc.submitOp [
      p: []
      oi: ob
    ], =>
      @_syncDoc._bb_collection_inited = true
      @_setConnected()
      cb()

  _loadModelsFromSyncDoc: (cb) ->

    if modelMap = @_syncDoc.snapshot[@collectionId]
      @_setConnected()
      for id, json of modelMap
        @_initModel json
      cb()
    else
      log "Creating collection #{ @collectionId }"
      @_syncDoc.submitOp [
        p: [@collectionId]
        oi: {}
      ], =>
        @_setConnected()
        cb()



  _bindSendOperations: ->

    @bind "change", (model) =>
      if model._syncOk
        @_sendModelChange model
      else
        log "Model '#{ model.id }' is not in sync machinery yet. Skipping change event"

    @bind "add", (model) =>
      @_sendModelAdd model

    @bind "destroy", (model) =>
      @_sendModelDestroy model


  _sendModelChange: (model) ->

    operations = for attribute, value of model.changedAttributes()
      if @_syncAttributes[attribute] is value
        # We received this change. No need to resend it
        delete @_syncAttributes[attribute]
        continue

      log "SEND CHANGE: #{ model.id }: #{ attribute }: #{ value }"
      { p: [@collectionId , model.id, attribute ],  oi: value }


    if not @_syncDoc.snapshot[@collectionId][model.id]
      log "ERROR: snapshot has no this model #{ model.id }"


    @_syncDoc.submitOp operations if operations.length isnt 0


  _sendModelAdd: (model) ->
    if @_syncAdded is model.id
      # We received this add. No need to resend it
      @_syncAdded = null
      return

    log "SEND ADD #{ model.id }: #{ JSON.stringify model.toJSON() }"

    @_syncDoc.submitOp [
      p: [@collectionId , model.id]
      oi: model.toJSON()
    ]


  _sendModelDestroy: (model) ->

    if @_syncRemoved is model.id
      # We received this remove. No need to send it again
      @_syncRemoved = null
      return

    log "SEND REMOVE #{ model.id }"
    @_syncDoc.submitOp [
      p: [@collectionId , model.id]
      od: true
    ]



  _receiveModelOperation: (op) ->

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

    @_syncAdded = op.oi.id
    @_initModel op.oi


  _receiveModelDestroy: (op) ->
    modelId = op.p[1]

    model = @get modelId
    if not model
      log "ERROR: Remote asked to remove non existing model #{ modelId }"
      return

    log "RECEIVE REMOVE #{ model.id }: #{ JSON.stringify modelId }"

    # Prevent resending this remove
    @_syncRemoved = model.id

    model.destroy()

    if @_syncDoc.snapshot[@collectionId][modelId]
      log "ERROR: Model exists after deletion! #{ modelId }"


  _receiveModelChange: (op) ->
    modelId = op.p[1]
    attrName = op.p[2]
    attrValue = op.oi


    model = @get modelId
    if not model
      log "ERROR: Remote asked to update non existing model: #{ model.id } #{ modelId }"
      return

    log "RECEIVE CHANGE #{ model.id }: #{ attrName }: #{ attrValue }"

    @_syncAttributes[attrName] = attrValue

    model.set @_syncAttributes


  # Collection#add can trigger change events. We must flag models so that the
  # changes won't get sent to the sharejs document before it's added to it
  add: (models) ->
    if models.length is 0
      return

    # TODO: Should we just queue adds and add them when connected?
    if not @connected
      throw new Error "SharedCollection must be connected to ShareJS document before models can be added to it!"

    super

    # TODO: can we add models to the sharejs document here?
    if _.isArray models
      for m in models
        m._syncOk = true
    else
      models._syncOk = true

    return this


  getOrCreate: (id, Model=Backbone.Model) ->

    if model = @get id
      log "getOrCreate: Got!"
      return model

    log "getOrCreate: creating!"
    model = new Model id: id
    @add model
    return model








