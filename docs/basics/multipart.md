# Multipart

Multipart bodies represent structured form data — text fields and file uploads. In tink_http they are modelled as a `StructuredBody`.

## Types

```haxe
typedef StructuredBody = Array<Named<BodyPart>>;

enum BodyPart {
  Value(v:String);
  File(handle:UploadedFile);
}

typedef UploadedFileBase = {
  var fileName(default, null):String;
  var mimeType(default, null):String;
  var size(default, null):Int;
  function read():RealSource;
  function saveTo(path:String):Promise<Noise>;
}
```

Create an uploaded file from bytes:

```haxe
UploadedFile.ofBlob('photo.jpg', 'image/jpeg', bytes);
```

## Plain vs Parsed request bodies

```haxe
enum IncomingRequestBody {
  Plain(source:RealSource);
  Parsed(parts:StructuredBody);
}
```

| Container | Body form | Notes |
|-----------|-----------|-------|
| `NodeContainer` | `Plain` | You parse the raw stream yourself |
| `PhpContainer`, `ModnekoContainer` | `Parsed` | Multipart is parsed automatically by the SAPI |
| `LocalContainer` | `Plain` | Same as Node for testing |

See [Server](server.md#incoming-request-bodies) for the overview.

## Reading parsed parts (PHP / Neko)

```haxe
function handler(req):Future<OutgoingResponse> {
  return switch req.body {
    case Parsed(parts):
      for (part in parts)
        switch part.value {
          case Value(v): trace(part.name, v);
          case File(file): trace(part.name, file.fileName, file.size);
        }
      Future.sync(('OK':OutgoingResponse));
    case Plain(_):
      Future.sync(new OutgoingResponse(new ResponseHeader(UnsupportedMediaType), 'Expected multipart form'));
  }
}
```

Save an uploaded file to disk:

```haxe
file.saveTo('/tmp/uploads/' + file.fileName);
```

## CGI vs streaming environments

In classical CGI environments (PHP/Neko behind Apache), the web server may buffer and parse uploads before your handler runs. This prevents worker processes from being blocked by large uploads, but means you cannot reject a request until the upload completes.

In Node.js and similar environments, the body arrives as a raw `Plain` stream. You control parsing and can stream data to another server without writing to disk first. The tradeoffs are covered in the [Server](server.md) overview.
