**Still hacking. Come back later. Release coming soon!**

# Backbone.SharedCollection

Backbone.SharedCollection is a dead simple way to add automatic synchronzation
to your Backbone.js app. You don't need to do any changes to your Models. All
you need to do is add them to a collection created from
`Backbone.SharedCollection` and they will be magically shared between browsers.


## Usage

Backbone.SharedCollection uses [Node.js][] and [ShareJS][] to synchronize
Models. So you need simple Node.js server for this:


```javascript
var express = require("express");
var sharejs = require("share").server;

var app = express.createServer();

sharejs.attach(app, {
  db:{ type: "none" }
});
```

In addition to Backbone.js dependencies you need also ShareJS and it's
dependencies, Socket.io, added to your app

```html
<!-- Socket.io and ShareJS served directly from Node.js server -->
<script src="/socket.io/socket.io.js"></script>
<script src="/share/share.uncompressed.js"></script>
<script src="/share/json.uncompressed.js"></script>

<!-- Basic Backbone.js dependencies -->
<script src="/vendor/jquery.js"></script>
<script src="/vendor/underscore.js"></script>
<script src="/vendor/backbone.js"></script>

<!-- and finally you can add Backone.SharedCollection -->
<script src="backbone.sharedcollection.js"></script>
```

For fully working app see [examples/todos](https://github.com/opinsys/backbone.sharedcollection/tree/master/examples/todos)

## API

todo...

[Node.js]: http://sharejs.org/
[ShareJS]: http://sharejs.org/

