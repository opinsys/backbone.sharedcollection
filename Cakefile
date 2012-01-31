fs = require "fs"
{exec} = require "child_process"


src = "src/sharedcollection.coffee"

build = ->
  coffee = exec "coffee -c -o . #{ src }"
  for pipe in ["stderr", "stdout"]
    coffee[pipe].on "data", (data) -> process[pipe].write data.toString()

  coffee.on "exit", (code) ->
    if code isnt 0
      console.log "Failed to compile coffee"
      return
    console.log "build ok"
    exec("cp sharedcollection.js test/public/")
    exec("cp sharedcollection.js examples/todos/public/")

task "build", ->
  build()

task "watch", ->
  fs.watchFile src, -> build()
