# Client

> Note: if you are looking for a simple-to-use API, please check out the [fetch API](basics/fetch.md)

A client allows you to make HTTP requests to a server. In other words it turns outgoing requests into incoming responses.

It is defined like so:

```haxe
abstract Client {
  function request(r:OutgoingRequest):Promise<IncomingResponse>;
}

class OutgoingRequest extends Message<RequestHeader, IdealSource> {
  public var to(default, null):Host;
  public function new(to:Host, header:RequestHeader, body:IdealSource):Void;
}

class IncomingResponse extends Message<ResponseHeader, RealSource> {}
```

## Client Errors

Please note that if you're performing an HTTP request, failure can occur on two layers:

1. The communication to the server is not possible, because the network is down, the server is down, DNS fails, cross origin policies prevent it etc. In this case, the error is expressed by the returned [`Promise`][promise] producing an actual [`Error`][error].
2. The server itself generates an HTTP response with an error code, either because of problems in your request (status code 4xx) or problems on the server (status code 5xx). In this case you will have an incoming response with the error code set.

[promise]: https://haxetink.github.io/tink_core/#/types/promise
[error]: https://haxetink.github.io/tink_core/#/types/error
