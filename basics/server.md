
# Server

A server handles incoming HTTP requests by providing HTTP responses. In `tink_http` we have a very simple compositional unit to define such an "HTTP handler":

## Handler

A handler is quite simply put anything that can process a request:

```haxe
abstract Handler {
  function process(req:IncomingRequest):Future<OutgoingResponse>;
  @:from static function ofFunc(f:OutgoingReuest->Promise<IncomingResponse>):Handler
}

class IncomingRequest extends Message<RequestHeader, IncomingRequestBody> {
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
function serveFiles(fromDirectory:String):Handler
  return /* here goes an implementation */

function router(m:Map<String, Handler>):Handler 
  return function (i:IncominRequest) {
    for (k in m.keys()) 
      if (i.header.url.path.startsWith(k))
        return m[k].process(i);
    return new OutgoingResponse(new OutgoingResponseHeader(404, 'not found'), 'The requested URL was not found');
  }

router([
  '/static' => serveFiles('./assets'),
  '/route1' => handler1,
  '/route2' => handler2,
  '/route3' => router([
    '/sub1' => sub1,
    '/sub2' => sub2,
  ])
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

typedef StructuredBody = Array<Named<BodyPart>>;

enum BodyPart {
  Value(v:String);
  File(handle:UploadedFile);
}

abstract UploadedFile {
  
  var fileName(get, never):String;
  var mimeType(get, never):String;
  var size(get, never):Int;
  
  function read():RealSource;
  function saveTo(path:String):Promise<Noise>;
}
```

In itself, the request body is just a stream of binary data. However, in "classical" web server environments, e.g. PHP/neko through Apache with (Fast)CGI, you will find the request body preparsed. For example if a form with a file attached is submitted to your server, it will upload the file to a temporary location and once the upload is completed, control is handed off to your application. This is necessary in environments where every worker (thread or process) of your web application handles only one request at a time. Otherwise all workers could easily be blocked by just a few dozen incoming uploads. It has a couple of disadvantages:

1. If somebody mistakenly posts a lot of data to the wrong URL (through an API or what not), you can only tell them *after* the upload has completed. Take an even worse scenario: imagine a user uploads a big file through a form over a small connection, which takes 15 minutes. When your application is finally handed the request, the client was inactive for 15 minutes and if your policy happens to be to discard such sessions, then the whole upload will fail.
2. If you actually wanted to forward the form to another server, you will have to read the file back from the file system and construct a new request. In simpler cases you can get the front facing server (e.g. Apache) to do it for you, but as the logic grows more complex you have to choose between inefficiency or splitting logic between server specific configuration and application code.
3. It renders your server more vulnerable to DoS attacks. An attacker can just upload huge amounts of data to your server, or smaller amounts but *very slowly* causing your server to keep many open connections. This vulnerabilities must then be mitigated by configuration, setting limits for how long a request may upload or how much data it may carry at maximum. But the same limits will then apply to anonymous users, authenticated ones and even admins.

An alternative approach is taken in environments such as NodeJS, where your application can handle multiple requests concurrently and always gets the request body as a raw stream to parse itself.

As we see, the body of the request may be delivered in a parsed form as a raw stream.
