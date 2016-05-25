package;

import haxe.io.Bytes;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

typedef Data = {
  uri:String,
  ip:String,
  method:String,
  headers:Array<{ name:String, value:String }>,
  body:String
}

class DummyServer {
  
  static public function handleRequest(req:IncomingRequest):Future<OutgoingResponse> 
    return 
      if (req.header.uri == '/close') {
        Sys.exit(0);
        null;
      }
      else switch req.body {
        case Plain(src):
          src.all().map(function (o) return switch o {
            case Success(body):
              
              var data:Data = {
                uri: req.header.uri.toString(),
                ip: req.clientIp,
                method: req.header.method,
                headers: [for (h in req.header.fields) { name: h.name, value: h.value } ], 
                body: body.toString(),
              };
              OutgoingResponse.blob(Bytes.ofString(haxe.Json.stringify(data)), 'application/json');
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
  
}