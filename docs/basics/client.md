# Client

> Note: if you are looking for a simple-to-use API, please check out the [fetch API](fetch.md)

A client allows you to make HTTP requests to a server. In other words it turns outgoing requests into incoming responses.

It is defined like so:

```haxe
abstract Client(ClientObject) {
  static function fetch(url:Url, ?options:FetchOptions):FetchResponse;
  function augment(pipeline:Processors):Client;
  function request(r:OutgoingRequest):Promise<IncomingResponse>;
}

interface ClientObject {
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}

class OutgoingRequest extends Message<OutgoingRequestHeader, IdealSource> {}

class OutgoingRequestHeader extends RequestHeader {
  public function new(method:Method, url:Url, ?protocol:Protocol = HTTP1_1, ?fields:Array<HeaderField>):Void;
}

class IncomingResponse extends Message<ResponseHeader, RealSource> {}
```

The target host is part of `OutgoingRequestHeader.url`, not a separate field on `OutgoingRequest`.

## Request/Response Pipelines

Use `Client.augment()` to attach preprocessors and postprocessors without wrapping the client manually:

```haxe
typedef Processors = {
  ?before:Array<Preprocessor>,
  ?after:Array<Postprocessor>,
}

typedef Preprocessor = Next<OutgoingRequest, OutgoingRequest>;
typedef Postprocessor = OutgoingRequest -> Next<IncomingResponse, IncomingResponse>;
```

`FetchOptions` also accepts `?augment:Processors` — see [Fetch](fetch.md).

## Client Errors

Please note that if you're performing an HTTP request, failure can occur on two layers:

1. The communication to the server is not possible, because the network is down, the server is down, DNS fails, cross origin policies prevent it etc. In this case, the error is expressed by the returned [`Promise`][promise] producing an actual [`Error`][error].
2. The server itself generates an HTTP response with an error code, either because of problems in your request (status code 4xx) or problems on the server (status code 5xx). In this case you will have an incoming response with the error code set.

When using `FetchResponse.all()`, HTTP status codes >= 400 are treated as `Failure` rather than `Success` with an error body. See [Fetch](fetch.md).

[promise]: https://haxetink.github.io/tink_core/#/types/promise
[error]: https://haxetink.github.io/tink_core/#/types/error
