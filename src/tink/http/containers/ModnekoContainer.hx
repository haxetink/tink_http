package tink.http.containers;

import neko.Web;
import tink.http.Container;
import tink.http.Header;
import tink.http.Request;
import tink.streams.Stream;
import tink.io.Sink;
import tink.io.PipeResult;
import tink.io.PipeOptions;

using tink.CoreApi;

class ModnekoContainer implements Container {
  static public var inst(default, null):ModnekoContainer = new ModnekoContainer();
  function new() { }
  
  function getHeader() 
    return
      new IncomingRequestHeader(
        Method.ofString(Web.getMethod(), function (_) return GET),
        Web.getURI() + switch Web.getParamsString() {
          case null | '': '';
          case v: '?' + v;
        },
        HTTP1_1, //TODO: do something meaningful here,
        {
          var v = @:privateAccess Web._get_client_headers();
          var a = [];
          while( v != null ) {
            a.push(new HeaderField(new String(v[0]), new String(v[1])));
            v = cast v[2];
          }
          a;
        }
      );
      
  public function run(handler:tink.http.Handler):Future<ContainerResult> {
    return Future.async(function (cb) 
      handler.process({
        var header = getHeader();
        new IncomingRequest(
          Web.getClientIP(),
          header,
          //TODO: use Web.parseMultiPart when appropriate
          Plain(switch Web.getPostData() {
            case null: Empty.make();
            case v: v;
          })
        );
      }).handle(function (res) {
        Web.setReturnCode(res.header.statusCode);
        
        for (h in res.header)
          Web.setHeader(h.name, h.value);
          
        res.body.pipeTo(Outstream.INST, { end: true }).handle(function (o) {
          cb(Shutdown);
        });
      })
    );
  }
}

private class Outstream extends SinkBase<Noise, Noise> {
  static public var INST(default, null) = new Outstream();
  function new() {}
  override function consume<EIn>(source:Stream<Chunk, EIn>, options:PipeOptions):Future<PipeResult<EIn, Noise, Noise>>
    return source.forEach(function(chunk) {
      Sys.print(chunk);
      return Resume;
    }).map(function(o):PipeResult<EIn, Noise, Noise> return switch o {
      case Depleted: AllWritten;
      case Halted(_): throw 'unreachable';
      case Failed(e): SourceFailed(e);
    });
}