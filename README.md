[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

# Tink HTTP

Tink HTTP provides a cross platform abstraction over the server and client side of HTTP, based on asynchronous immutable streams. Its API is an attempt to expose the protocol as directly as possible. While it can be used directly, it is meant as an abstraction layer to build frameworks on.

## Messages and Headers

Fundamentally, HTTP is always the exchange of a request and a response, both of which are messages with a header and a (possibly empty) body. In tink_http these are modelled as immutable objects like so:

```haxe
class Message<H:Header, B> {
  public var header(default, null):H;
  public var body(default, null):B;   
}
```

The body can be many things depending on context, but headers are all quite similar across platforms. Request headers have a method and a url, response headers have a status code, but other than that they are primarily a list of header fields, where each field is a pair of a *case insensitive* name and a value.

That is exactly how `tink_http` defines headers:

```haxe
@:enum abstract HeaderName(String) to String {
  
  public var REFERER             = 'referer';
  public var HOST                = 'host';
  
  public var SET_COOKIE          = 'set-cookie';
  public var COOKIE              = 'cookie';
  
  public var CONTENT_TYPE        = 'content-type';
  public var CONTENT_LENGTH      = 'content-length';
  public var CONTENT_DISPOSITION = 'content-disposition';
  
  public var ACCEPT              = 'accept';
  public var ACCEPT_ENCODING     = 'accept-encoding';
  
  public var LOCATION            = 'location';
  
  @:from static function ofString(s:String):HeaderName
    return new HeaderName(s.toLowerCase());//<-- here we ensure case insensitive header treatment
} 

abstract HeaderValue(String) from String to String {}

class HeaderField extends NamedWith<HeaderName, HeaderValue> {
  public function toString():String;    
  static public function ofString(s:String):HeaderField;
}

class Header {
  public function get(name:HeaderName):Array<HeaderValue>;
  public function byName(name:HeaderName):Outcome<HeaderValue, Error>;
  public function iterator():Iterator<HeaderField>;
  public function new(fields:Array<HeaderField>):Void;
}
```


## Client

A client allows you to make HTTP requests. In other words it turns outgoing requests into incoming responses.

```haxe
interface Client {
  function request(r:OutgoingRequest):Promise<IncomingResponse>;
}

class OutgoingRequest {
  public function new() {
	
  }
}
```

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
