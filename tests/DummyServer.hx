import haxe.io.Bytes;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.io.Buffer;
import tink.io.Sink;
import haxe.io.BytesOutput;
import tink.io.Worker;
import tink.http.StructuredBody;
import haxe.Json;

using tink.CoreApi;

enum ParsedRequestBody {
  Plain(body: String);
  Parsed(parts: StructuredBody);
  None;
}

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
    main(port, handleRequest);
  }
  
  static public function handleRequest(req: IncomingRequest): Future<OutgoingResponse> {
    if (req.header.uri == '/close') {
      Sys.println('>> Closing server');
      Sys.exit(0);
      return null;
    }
    
    if (req.header.uri == '/active')
      return Future.sync(('ok': OutgoingResponse));
      
    return parseBody(req)
      .recover(function (e) return Future.sync(None))
      .map(function (body) {
        var data: Data = {
          uri: req.header.uri.toString(),
          ip: req.clientIp,
          method: req.header.method,
          headers: [for (h in req.header.fields) { name: h.name, value: h.value } ], 
          body: switch body {
            case Plain(body): {type: 'plain', content: body};
            case Parsed(parts): {type: 'parsed', parts: [
              for (part in parts) {
                name: part.name,
                value: switch part.value {
                  case Value(s): s;
                  case File(u): u.fileName + '=' + u.mimeType;
                }
              }
            ]};
            case None: {type: 'none'};
          }
        }
        return 
          OutgoingResponse.blob(
            Bytes.ofString(Json.stringify(data)), 
            'application/json'
          );
    });
    
  }
  
  static function parseBody(req: IncomingRequest): Promise<ParsedRequestBody> {
    if (req.header.method == GET)
      return None;
    return switch req.body {
      case Plain(src):
        src.all().map(function (o) return switch o {
          case Success(body): Success(Plain(body.toString()));
          case Failure(e): Failure(e);
        });
      case Parsed(parts):
        Parsed(parts);
    }
  }
  
}