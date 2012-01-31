fs = require "fs"
{exec} = require "child_process"


src = "src/backbone.sharedcollection.coffee"

build = ->
  coffee = exec "coffee -c -o . #{ src }"
  for pipe in ["stderr", "stdout"]
    coffee[pipe].on "data", (data) -> process[pipe].write data.toString()

  coffee.on "exit", (code) ->
    if code isnt 0
      console.log "Failed to compile coffee"
    else
      console.log "build ok"

      exec("uglifyjs -o backbone.sharedcollection.min.js backbone.sharedcollection.js").on "exit", (code) ->
        if code isnt 0
          console.log "minification failed"
        else
          console.log "minification ok"

task "build", ->
  build()

task "watch", ->
  fs.watchFile src, -> build()
