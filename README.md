**Still hacking. Come back later. Release coming soon!**

# Backbone.SharedCollection

Backbone.SharedCollection is a dead simple way to add automatic synchronzation
to your Backbone.js app. You don't need to do any changes to your Models. All
you need to do is add them to a collection created from
`Backbone.SharedCollection` and they will be magically shared between browsers.


## Installation

Backbone.SharedCollection uses [Node.js][] and [ShareJS][] to synchronize
Models. So you need simple Node.js server. Like this one:


```javascript
var express = require("express");
var sharejs = require("share").server;

var app = express.createServer();

sharejs.attach(app, {
  db:{ type: "none" }
});
```

In addition to Backbone.js you need also ShareJS and it's
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

## Usage

You start by creating instance of SharedCollection and fetching it using
ShareJS document. You must call the fetch function always before using
SharedCollections. That will connect it to ShareJS and will load previously
saved models

```javascript
var collection = new Background.SharedCollection;
sharejs.open('todos', 'json', function(err, doc) {
    if (err) throw err;
    collection.fetch({
        sharejsDoc: doc,
        success: initCallback,
        error: displayErrorCallback
    });
});
```

Then you can just start adding models to your collection

```javascript
function initCallback() {
    model = new Backbone.Model;
    collection.add model;
}
```

Now all `set` method calls to the models will propagated all other browser
instances automatically. You don't use the `save` method when the models are in
SharedCollection. All add, destroy and set calls will be automatically saved
and synced using ShareJS.

```javascript
model.set({ foo: "bar" });
```

If you need to make only local change to your model you can pass `{ local: true
}` as options to `set`.


```javascript
model.set({ foo: "bar local only" }, { local: true });
```

Custom models in collection works just like Backbone.js documentation
[states](http://documentcloud.github.com/backbone/#Collection-model). Just
override `model` property with your custom Model class.

If you want to have have multiple different Models in single SharedCollection,
you must set type attribute of your custom models to some unique string identifier.

```javascript
window.MyModel = Backbone.Model.extend({

    type: "mymodel"

    hasBar: function() {
        !! return this.get "bar"
    }
});

```

and pass those to the shared collection

```javascript
var collection = new Background.SharedCollection([], {
    modelClasses: [ MyModel ]
});
```

Only then SharedCollection can know how to deserialize your models.

### Events

Remote updates will be emited as normal `change`, `add`, `destroy` events. If
you need to know specifically if the event came from ShareJS and not by local
code you can check the options object of the event for `remote` property.

```javascript
model.bind("change", function(model, options) {
    if (options.remote) {
        // Came from remote browser
    }
});

collection.bind("add", function(model, collection, options) {
    if (options.remote) {
        // Came from remote browser
    }
});
```

Sync errors will be emited as `syncerror` events in SharedCollection instances.

```javascript
collection.bind("syncerror", function(model, method, err) {
    // `method` is a string, "add", "change" or "destroy", and `err` is the
    // error object from ShareJS
    alert("Failed to " + method + " " + model.id);
});
```

[Node.js]: http://sharejs.org/
[ShareJS]: http://sharejs.org/

