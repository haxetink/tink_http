import haxe.io.Bytes;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.http.Handler;
import tink.http.middleware.CrossOriginResourceSharing;
import tink.io.Sink;
import haxe.io.BytesOutput;
import tink.io.Worker;

using tink.CoreApi;
using tink.io.Source;

class DummyServer {
  
  public static function main() {
    var server = Env.getDefine('server', true);
    var port = Std.parseInt(Env.getDefine('port', true));
    if (!Context.servers.exists(server))
      throw 'No such server: $server';
    #if (tink_runloop || nodejs)
    Sys.println('>> Server $server listening on $port');
    #end
    var main = Context.servers.get(server);
    var handler:Handler = handleRequest;
    handler = handler.applyMiddleware(new CrossOriginResourceSharing(CorsProcessor.regex(~/.*/, true)));
    main(port, handleRequest);
  }
  
  static public function handleRequest(req:IncomingRequest):Future<OutgoingResponse> {
    if (req.header.url.path == '/close') {
      Sys.println('\n>> Closing server');
      Sys.exit(0);
      return null;
    }
    
    if (req.header.url.path == '/active')
      return Future.sync(('ok': OutgoingResponse));
    
    if (req.header.url.path == '/crossdomain.xml')
      return Future.sync(OutgoingResponse.blob(Bytes.ofString('<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" /></cross-domain-policy>'), 'text/xml'));
    
    if (req.header.url.path == '/swf')
      return Future.sync(OutgoingResponse.blob(sys.io.File.getBytes('/Users/kevin/Codes/tink_http/bin/swf/tests.swf'), 'application/x-shockwave-flash'));
      
    #if (tink_runloop || nodejs)
    Sys.print(Ansi.text(Cyan, '.'));
    #end

    var query:haxe.DynamicAccess<String> = {};
    if(req.header.url.query != null) for(p in req.header.url.query) query.set(p.name, p.value);
    
    return switch req.body {
      case Plain(src):
        src.all().map(function (o) return switch o {
          case Success(body):
            var data:Data = {
              uri: req.header.url.path,
              query: query,
              ip: req.clientIp,
              method: req.header.method,
              headers: [for (h in req.header) { name: h.name, value: h.value } ], 
              body: body
            }
            OutgoingResponse.blob(Bytes.ofString(haxe.Json.stringify(data)), 'application/json');
          case Failure(e):
            new OutgoingResponse(
            new ResponseHeader(e.code, e.message, [new HeaderField('content-type', 'application/json')]),
              haxe.Json.stringify({
                error: true,
                code: e.code, 
                message: e.message
              })
            );
        });
      case Parsed(parts):
        var data:Data = {
          uri: req.header.url.path,
          query: query,
          ip: req.clientIp,
          method: req.header.method,
          headers: [for (h in req.header) { name: h.name, value: h.value } ], 
          body: haxe.Json.stringify([for (p in parts) {
            name: p.name,
            value: switch p.value {
            case Value(s): s;
            case File(u): u.fileName + '=' + u.mimeType;
            }
          }]),
        };            
        Future.sync(OutgoingResponse.blob(Bytes.ofString(haxe.Json.stringify(data)), 'application/json'));
    }
  }
  
}