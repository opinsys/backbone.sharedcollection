fs = require "fs"

cs = require "coffee-script"
express = require("express")
sharejs = require("share").server

app = express.createServer()

sharejs.attach app,
  db:{ type: "none" }


app.get "/test/:filename", (req, res) ->
  console.log req.params.filename
  fs.readFile __dirname + "/" + req.params.filename, (err, data) ->
    console.log data
    res.header('Content-Type', 'application/javascript')
    res.send cs.compile data.toString()


app.configure 'development', ->
  app.use express.static __dirname + '/public'
  app.use express.static __dirname + '/..'

app.listen 3001, ->
  console.log "Now listening on http://localhost:3001/"
