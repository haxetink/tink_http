package tink.http.containers;

import haxe.io.Bytes;
import neko.Web;
import tink.http.Container;
import tink.http.Header.HeaderField;
import tink.http.Request.IncomingRequest;
import tink.http.Request.IncomingRequestHeader;
import tink.io.Buffer;
import tink.io.IdealSource.Empty;
import tink.io.Progress;
import tink.io.Sink.SinkBase;

using tink.CoreApi;

class ModnekoContainer implements Container {
  static public var inst(default, null):ModnekoContainer = new ModnekoContainer();
  function new() {}
  public function run(handler:Handler):Future<ContainerResult> {
    return Future.async(function (cb) 
      handler.process(new IncomingRequest(
        Web.getClientIP(),
        new IncomingRequestHeader(
          Method.ofString(Web.getMethod(), function (_) return GET),
          Web.getURI() + switch Web.getParamsString() {
            case null | '': '';
            case v: '?' + v;
          },
          '1.1', //TODO: do something meaningful here,
          {
            var v = @:privateAccess Web._get_client_headers();
            var a = [];
            while( v != null ) {
              a.push(new HeaderField(new String(v[0]), new String(v[1])));
              v = cast v[2];
            }
            a;
          }
        ),
        switch Web.getPostData() {
          case null: Empty.instance;
          case v: v;
        }
      )).handle(function (res) {
        
        Web.setReturnCode(res.header.statusCode);
        
        for (h in res.header.fields)
          Web.setHeader(h.name, h.value);
          
        res.body.pipeTo(Outstream.INST, { end: true }).handle(function (o) {
          cb(Done);
        });
      })
    );
  }
}

private class Outstream extends SinkBase {
  static public var INST(default, null) = new Outstream();
  function new() {}
  function writeBytes(from:Bytes, pos:Int, len:Int):Int {
    Sys.print(from.getString(pos, len));
    return len;
  }
  
  override public function write(from:Buffer):Surprise<Progress, Error> {
    return Future.sync(from.tryWritingTo('server output', this));
  }
}