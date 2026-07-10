# Requests, Responses and their Headers

## Requests and Responses are Messages

Fundamentally, HTTP is always the exchange of a request and a response, both of which are messages with a header and a (possibly empty) body. In tink_http these are modelled as immutable objects like so:

```haxe
class Message<H:Header, B> {
  public var header(default, null):H;
  public var body(default, null):B;
}
```

## Headers

The body can be many things depending on context, but headers are all quite similar across platforms. Request headers have a method and a url, response headers have a status code, but other than that they are primarily a list of header fields, where each field is a pair of a *case insensitive* name and a value.

That is exactly how `tink_http` defines headers:

```haxe
@:enum abstract HeaderName(String) to String {

  public var REFERER             = 'referer';
  public var HOST                = 'host';
  public var LOCATION            = 'location';

  public var SET_COOKIE          = 'set-cookie';
  public var COOKIE              = 'cookie';
  public var AUTHORIZATION       = 'authorization';

  public var CONTENT_TYPE        = 'content-type';
  public var CONTENT_LENGTH      = 'content-length';
  public var CONTENT_DISPOSITION = 'content-disposition';

  /* ... the list goes on ... */

  @:from static function ofString(s:String):HeaderName
    return new HeaderName(s.toLowerCase());//<-- here we ensure case insensitive header treatment
}

abstract HeaderValue(String) from String to String {
  /*
   * there are some nice methods here but
   * let's ignore them for the sake of brevity
   */
}

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

With this in place you can construct and examine HTTP headers in a nice, type safe way. As said before, response and request headers vary slightly, and this is how we represent them:

```haxe
@:enum abstract Protocol(String) to String {
  var HTTP1_0 = 'HTTP/1.0';
  var HTTP1_1 = 'HTTP/1.1';
  var HTTP2   = 'HTTP/2';
}

class RequestHeader extends Header {
  public var method(default, null):Method;
  public var url(default, null):Url;
  public var protocol(default, null):Protocol;
  public function new(method:Method, url:Url, ?protocol:Protocol = HTTP1_1, fields:Array<HeaderField>):Void;
}

@:enum abstract Method(String) to String {
  var GET = 'GET';
  var HEAD = 'HEAD';
  var OPTIONS = 'OPTIONS';

  var POST = 'POST';
  var PUT = 'PUT';
  var PATCH = 'PATCH';
  var DELETE = 'DELETE';
}

class ResponseHeader extends Header {
  public var statusCode(default, null):StatusCode;
  public var reason(default, null):Reason;
  public var protocol(default, null):Protocol;
  public function new(statusCode:StatusCode, ?reason:Reason, ?fields:Array<HeaderField>, ?protocol:Protocol = HTTP1_1):Void;
}
```

`StatusCode` and `Reason` come from the `http-status` library.

## Incoming vs Outgoing Request Headers

Not all requests are the same. `tink_http` distinguishes:

- **`IncomingRequestHeader`** — used on the server side. Adds cookie helpers (`cookieNames()`, `getCookie()`) and auth parsing (`getAuth()`).
- **`OutgoingRequestHeader`** — used on the client side. If the URL contains credentials (`https://user:pass@host/...`), they are extracted into an `Authorization` header automatically.

```haxe
enum Authorization {
  Basic(user:String, pass:String);
  Bearer(token:String);
  Others(scheme:String, param:String);
}
```

See [Auth and Cookies](auth-and-cookies.md) for details on reading and setting auth and cookies.
