

a = new Backbone.SharedCollection [],
  collectionId: "testing"

b = new Backbone.SharedCollection [],
  collectionId: "testing"

fetchFor = (collection, cb) ->

  sharejs.open "testingsharejs", "json", (err, doc) =>
    throw err if err
    collection.fetch
      sharejsDoc: doc
      success: -> cb()
      error: -> cb new Error "failed to open"


beforeEach (done) ->
  fetchFor a, (err) ->
    done err if err
    fetchFor b, (err) ->
      done err


describe "test test", ->

  it "is ok", ->


describe "model adding", ->

  it "works", (done) ->

    b.bind "add", (model) ->
      done()

    m = new Backbone.Model
    a.add m

    # m.set foo: "bar"

