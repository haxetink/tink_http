package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;

using tink.io.Source;
using tink.CoreApi;
using StringTools;

class PhpClient implements ClientObject {
  public function new() {}
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future #if (tink_core >= "2") .irreversible #else .async #end(function(cb) {
      req.body.all().handle(function(chunk) {
        var options = php.Lib.associativeArrayOfObject({
          http: php.Lib.associativeArrayOfObject({
            // protocol_version: // TODO: req does not define the version?
            header: [for(h in req.header) h.toString()].join('\r\n') + '\r\n',
            method: req.header.method,
            content: chunk.toBytes().getData().toString(),
          }),
        });
        
        var context = #if haxe4 php.Syntax.code('stream_context_create({0})', options) #else untyped __call__('stream_context_create', options) #end;
        var url:String = req.header.url;
        //var result = @:privateAccess new sys.io.FileInput(untyped __call__('fopen', url, 'rb', false, context));
        var result = @:privateAccess new sys.io.FileInput(
          #if haxe4  php.Global.fopen( #else untyped __call__('fopen', #end url, 'rb', false, context));
        
        var rawHeaders:Array<String> = cast php.Lib.toHaxeArray(#if haxe4 php.Syntax.code #else untyped __php__ #end("$http_response_header"));
        
        // http://php.net/manual/en/reserved.variables.httpresponseheader.php#122362
        // $http_response_header includes all the "history" headers in case of redirected response
        var i = rawHeaders.length;
        while(i-- >= 0) if(rawHeaders[i].startsWith('HTTP/')) break;
        rawHeaders = rawHeaders.slice(i);
        
        // construct the header object
        var head = rawHeaders[0].split(' ');
        var headers =  [for(i in 1...rawHeaders.length) {
          var line = rawHeaders[i];
          var index = line.indexOf(': ');
          var name = line.substr(0, index);
            new HeaderField(
            name,
            line.substr(index + 2)
            );
        }];
        
        var header = new ResponseHeader(Std.parseInt(head[1]), head.slice(2).join(' '),  headers);
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