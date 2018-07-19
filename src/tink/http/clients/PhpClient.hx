package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;

using tink.io.Source;
using tink.CoreApi;

class PhpClient implements ClientObject {
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
        var url:String = req.header.url;
        var result = @:privateAccess new sys.io.FileInput(untyped __call__('fopen', url, 'rb', false, context));
        
        var rawHeaders:Array<String> = cast php.Lib.toHaxeArray(untyped __php__("$http_response_header"));
        var head = rawHeaders[0].split(' ');
        var headers = [for(i in 1...rawHeaders.length) {
          var line = rawHeaders[i];
          var index = line.indexOf(': ');
          new HeaderField(line.substr(0, index), line.substr(index + 2));
        }];
        var header = new ResponseHeader(Std.parseInt(head[1]), head.slice(2).join(' '), headers);
        cb(Success(new IncomingResponse(header, result.readAll())));
        
        // var headers:IdealSource = php.Lib.toHaxeArray(untyped __php__("$http_response_header")).join('\r\n') + '\r\n';
        // headers.parse(ResponseHeader.parser()).handle(function(o) switch o {
        //   case Success(parsed):
        //   case Failure(e):
        //     cb(Failure(e));
        // });
      });
    });
  }
}