# Chunked Transfer Encoding

HTTP chunked transfer encoding splits a body into chunks, each with its own size prefix. tink_http provides helpers in `Chunked` and on `OutgoingResponse`.

## Chunked encode/decode

```haxe
import tink.http.Chunked;

// Encode a source into chunked transfer encoding
var chunked:IdealSource = Chunked.encode(source);

// Decode a chunked source back to raw bytes
var decoded:RealSource = Chunked.decode(chunkedSource);
```

Lower-level access:

```haxe
Chunked.encoder().transform(source);
Chunked.decoder().transform(source);
```

## Outgoing responses

Use `withChunkedEncoding()` to automatically add chunked encoding when the response has no `Content-Length` header:

```haxe
var res = new OutgoingResponse(new ResponseHeader(OK), body);
return res.withChunkedEncoding();
```

Or use the `chunked()` factory which sets `Transfer-Encoding: chunked` and encodes the body:

```haxe
OutgoingResponse.chunked(OK, 'text/plain', null, source);
```

## Incoming requests

When parsing raw HTTP with `IncomingRequest.parse()`, a request body with `Transfer-Encoding: chunked` is automatically decoded via `Chunked.decode()`.

This applies to non-GET/OPTIONS requests that lack a `Content-Length` header but include `chunked` in `Transfer-Encoding`.
