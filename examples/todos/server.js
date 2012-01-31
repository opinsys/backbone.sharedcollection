
var express = require("express");
var sharejs = require("share").server;

var app = express.createServer();

sharejs.attach(app, {
  db:{ type: "none" }
});

app.configure('development', function(){
  app.use(express.static(__dirname + '/public'));
  app.use(express.static(__dirname + '/../../'));
});


app.listen(3000, function() {
  console.log("Now listening on http://localhost:3000/");
});
