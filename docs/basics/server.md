
# Server

A server handles incoming HTTP requests by providing HTTP responses. In `tink_http` we have a very simple compositional unit to define such an "HTTP handler":

## Handler

A handler is quite simply put anything that can process a request:

```haxe
typedef HandlerFunction = IncomingRequest->Future<OutgoingResponse>;

abstract Handler(HandlerObject) {
  function process(req:IncomingRequest):Future<OutgoingResponse>;
  @:from static function ofFunc(f:HandlerFunction):Handler;
}

class IncomingRequest extends Message<IncomingRequestHeader, IncomingRequestBody> {
  public var clientIp(default, null):String;
}

class OutgoingResponse extends Message<ResponseHeader, IdealSource> {}
```

When you're building server applications with tink_http, you will always express them as handlers of some form. A handler is basically just a function turning requests into responses.

This has the following advantages:

1. Every handler is easily testable, by giving it a request and examining the response. You don't even need to run a server to test it.
2. Handlers are very easily composed. Even if you have two handlers, each of which is built on a different framework, you can combine them into a single application.

Let's look into the second point by building a very simple router:

```haxe
import tink.http.Handler;
import tink.http.Response;
using StringTools;
using tink.CoreApi;

function serveFiles(fromDirectory:String):Handler
  return Handler.ofFunc(function(req) return Future.sync(('Not implemented':OutgoingResponse)));

function router(m:Map<String, Handler>):Handler
  return Handler.ofFunc(function(req) {
    var path:String = req.header.url.path;
    for (k in m.keys())
      if (StringTools.startsWith(path, k))
        return m[k].process(req);
    return Future.sync(new OutgoingResponse(new ResponseHeader(NotFound, 'not found'), 'The requested URL was not found'));
  });

var app = router([
  '/static' => serveFiles('./assets'),
  '/route1' => handler1,
  '/route2' => handler2,
]);
```

Note that `handler1` could be a whole application written with one framework and `handler2` with another.

## Incoming Request Bodies

The request body may be presented to you in two different forms, either as a raw stream that you get to process yourself, or in a pre-parsed form:

```haxe
enum IncomingRequestBody {
  Plain(source:RealSource);
  Parsed(parts:StructuredBody);
}
```

- **`Plain`** — the body is a raw stream. This is what you get in Node.js and similar environments.
- **`Parsed`** — the body has already been parsed into a `StructuredBody` (e.g. multipart form data). This happens automatically in PHP and Neko SAPI containers.

See [Multipart](multipart.md) for details on structured bodies, file uploads, and when each form is used.
