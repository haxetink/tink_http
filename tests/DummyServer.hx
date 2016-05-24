package;

import haxe.io.Bytes;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

class DummyServer {
  
  static public function handleRequest(req:IncomingRequest):Future<OutgoingResponse> 
    return 
      if (req.header.uri == '/close') {
        Sys.exit(0);
        null;
      }
      else
        req.body.all().map(function (o) return switch o {
          case Success(body):
            OutgoingResponse.blob(Bytes.ofString(haxe.Json.stringify({
              uri: req.header.uri.toString(),
              ip: req.clientIp,
              method: req.header.method,
              headers: [for (h in req.header.fields) { name: h.name, value: h.value } ], 
              body: body.toString(),
            })), 'application/json');
          case Failure(e):
            new OutgoingResponse(
              new ResponseHeader(e.code, e.message, [new HeaderField('content-type', 'application/json')]),
              haxe.Json.stringify( {
                error: true,
                code: e.code, 
                message: e.message
              })
            );
        });
  
}