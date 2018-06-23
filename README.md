# Tink HTTP
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

[Documentation](https://haxetink.github.io/tink_http/): Documentation site for the [pure](https://github.com/haxetink/tink_http/tree/pure) branch.

## Client

```haxe
// pick a client of your choice (see tink.http.Client)
var client:Client = ...;

// construct your request
var request:OutgoingRequest = ...;

client.request(request).handle(function(response) {
	// handle the response here
	trace(response);
});
```

## Handler

Handler is just a function that takes in a request and return a future response.

```haxe
typedef Handler = IncomingRequest->Future<OutgoingResponse>
```

## Container

```haxe
// prepare your handler
var handler:Handler = ...;

// pick a container of your choice (see tink.http.containers.*)
var container:Container = ...;

// start the container
container.run(handler).handle(function(result) switch result {
	case Running(running):
		// for persistent servers like NodeJS. Use running.shutdown() to shutdown the server.
	case Done;
		// for CGI-like environments like mod_neko or php
	case Failed(e):
		// something's wrong
});
```

## Multipart

Todo...

## Middleware

Todo...
