# Fetch

The `fetch` API resembles that same-named API provided in Javascript.

## API

```haxe
static function fetch(url:Url, ?options:FetchOptions):FetchResponse;

typedef FetchOptions = {
	?method:Method,
	?headers:Array<HeaderField>,
	?body:IdealSource,
	?client:ClientType,
	?followRedirect:Bool,
	?augment:Processors,
}

enum ClientType {
	Default;
	Local(container:LocalContainer);
	#if (sys || nodejs) Curl; #end
	StdLib;
	Custom(v:Client);
	#if php Php; #end
	#if tink_tcp Tcp; #end
	#if flash Flash; #end
	#if openfl OpenFl; #end
}

abstract FetchResponse(Promise<IncomingResponse>) to Promise<IncomingResponse> {
	public function all():Promise<CompleteResponse>;
	public function progress():Promise<ProgressResponse>;
}

typedef CompleteResponse = Message<ResponseHeader, Chunk>;
typedef ProgressResponse = Message<ResponseHeader, Progress<Outcome<Chunk, Error>>>;
```

See [Clients](clients.md) for how `ClientType` maps to platform-specific clients.

## Behavior

### Redirects

`fetch` follows redirects automatically for status codes 301, 302, 303, 307, and 308. Set `followRedirect: false` to disable. A 303 response resets the method to GET.

### `all()` vs raw `Promise`

`FetchResponse` is a `Promise<IncomingResponse>`, so you can handle the response as a stream. Calling `all()` buffers the entire body into a single `Chunk`. **If the status code is >= 400, `all()` returns `Failure`** with the status code, reason, and body — not `Success` with an error status.

### `progress()`

`progress()` returns a `ProgressResponse` that reports download progress as chunks arrive. Like `all()`, status codes >= 400 are treated as `Failure`.

### Request pipelines

Pass `augment: { before: [...], after: [...] }` to attach preprocessors and postprocessors for this request. See [Client](client.md#requestresponse-pipelines).

## Examples

With the [quick-start server](../getting-started/quick-start.md) running on port 8080:

### GET

```haxe
import tink.http.Client;
using tink.CoreApi;

Client.fetch('http://localhost:8080').all()
  .handle(function(o) switch o {
    case Success(res):
      trace(res.header.statusCode);
      trace(res.body.toString()); // "Hello, World!"
    case Failure(e):
      trace(e);
  });
```

### POST

Extend the quick-start server to echo POST bodies, then:

```haxe
import tink.http.Client;
import tink.http.Header;
using tink.CoreApi;

Client.fetch('http://localhost:8080', {
	method: POST,
	headers: [new HeaderField(CONTENT_TYPE, 'application/json')],
	body: '{"foo":"bar"}',
}).all()
  .handle(function(o) switch o {
    case Success(res):
      trace(res.header.statusCode);
      trace(res.body.toString());
    case Failure(e):
      trace(e);
  });
```

### Download progress

```haxe
Client.fetch('http://localhost:8080/large-file').progress()
  .handle(function(o) switch o {
    case Success(res):
      res.body.each(function(p) switch p {
        case Loading(bytes, total): trace('${bytes} / ${total}');
        case Done(chunk): trace('complete');
        case Failed(e): trace(e);
      });
    case Failure(e):
      trace(e);
  });
```
