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
}

abstract FetchResponse(Promise<IncomingResponse>) to Promise<IncomingResponse> {
	public function all():Promise<Message<ResponseHeader, Chunk>>;
}
```


## Example

A simple GET request can be achived by the following code:

```haxe
tink.http.Client.fetch(url).all()
  .handle(function(o) switch o {
    case Success(res):
      trace(res.header.statusCode);
      var bytes = res.body.toBytes();
      // do whatever with the bytes
    case Failure(e):
      trace(e);
  });
```


A simple POST request with custom headers and a body:

```haxe
tink.http.Client.fetch(url, {
	method: POST,
	headers: [new HeaderField(CONTENT_TYPE, 'application/json')],
	body: '{"foo":"bar"}',
}).all()
  .handle(function(o) switch o {
    case Success(res):
      trace(res.header.statusCode);
      var bytes = res.body.toBytes();
      // do whatever with the bytes
    case Failure(e):
      trace(e);
  });
```