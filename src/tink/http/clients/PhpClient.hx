package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;

using tink.io.Source;
using tink.CoreApi;

class PhpClient implements ClientObject {
  var protocol:String = 'http';
  public function new() {}
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.async(function(cb) {
      req.body.all().handle(function(chunk) {
        var options = php.Lib.associativeArrayOfObject({
          http: php.Lib.associativeArrayOfObject({
            // protocol_version: // TODO: req does not define the version?
            header: [for(h in req.header) h.toString()].join('\r\n') + '\r\n',
            method: req.header.method,
            content: chunk.toBytes().getData()
          }),
        });
        var context = untyped __call__('stream_context_create', options);
        var url = '$protocol:' + req.header.url;
        var result = @:privateAccess new sys.io.FileInput(untyped __call__('fopen', url, 'rb', false, context));
        var headers:IdealSource = php.Lib.toHaxeArray(untyped __php__("$http_response_header")).join('\r\n') + '\r\n';
        headers.parse(ResponseHeader.parser()).handle(function(o) switch o {
          case Success(parsed):
            cb(Success(new IncomingResponse(parsed.a, result.readAll())));
          case Failure(e):
            cb(Failure(e));
        });
      });
    });
  }
}