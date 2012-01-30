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
    exec("cp sharedcollection.js examples/todos/public/").on "exit", (code) ->
      if code is 0
        console.log "build ok"
      else
        console.log "cp failed"

task "build", ->
  build()

task "watch", ->
  fs.watchFile src, -> build()
