# Server-Sent Events (SSE)

SSE lets a server push events to the client over a long-lived HTTP connection. tink_http provides framing helpers in the `tink.http.Sse` module.

## Event type

```haxe
typedef Sse = {
  final data:String;
  @:optional public final id:String;
  @:optional public final event:String;
  @:optional public final retry:Int;
}
```

Import with `import tink.http.Sse;` — this also brings `SseStream` into scope.

## Encoding and decoding

```haxe
import tink.http.Sse;
import tink.streams.Stream;

// Server: encode a stream of events into an HTTP response body
var events = Stream.ofIterator(input.iterator());
var body = SseStream.encode(events);
return new OutgoingResponse(
  new ResponseHeader(OK, [new HeaderField(CONTENT_TYPE, 'text/event-stream')]),
  body
);

// Client: decode an SSE stream from a response body
var stream = SseStream.decode(response.body);
stream.each(function(event) {
  trace(event.data);
  return Resume;
});
```

`SseStream.encode()` formats events according to the SSE wire format (`data:`, `id:`, `event:`, `retry:` fields, separated by blank lines). `SseStream.decode()` parses a `RealSource` back into a `RealStream<Sse>`.

## Example server handler

With a `NodeContainer` on port 8080:

```haxe
import tink.http.Sse;
import tink.http.Response;
import tink.http.Header;
import tink.streams.Stream;
using tink.CoreApi;

function sseHandler(req):Future<OutgoingResponse> {
  var events = Stream.ofIterator([
    ({ data: 'hello' }:Sse),
    ({ data: 'world', event: 'greeting' }:Sse),
  ].iterator());
  return Future.sync(new OutgoingResponse(
    new ResponseHeader(OK, [new HeaderField(CONTENT_TYPE, 'text/event-stream')]),
    SseStream.encode(events)
  ));
}
```
