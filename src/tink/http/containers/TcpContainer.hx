package tink.http.containers;

import tink.http.Container;
import tink.http.Handler;
import tink.http.Request;
import tink.http.Response;

using tink.io.Source;
using tink.CoreApi;


class TcpContainer implements Container {
  static public function wrap(handler:Handler):tink.tcp.Handler {
    return function (i:tink.tcp.Incoming):Future<tink.tcp.Outgoing> {
      return i.stream.parse(IncomingRequestHeader.parser())
        .next(function (r) {
          var req = new IncomingRequest(i.from.host, r.a, Plain(r.b));
          return handler.process(req);
        })
        .recover(OutgoingResponse.reportError)
        .map(function (res) return {
          stream: res.body.prepend(res.header.toString()),
          allowHalfOpen: true,
        });
    }
  }
  var port:Promise<tink.tcp.OpenPort>;

  
  @:require(tink_tcp)
  public function new(port:Void->Promise<tink.tcp.OpenPort>) {
    this.port = Future.async(function (cb) {
      port().handle(cb);
    }, true);
  }
  
  public function run(handler:Handler):Future<ContainerResult> 
    return port.next(function (p) 
      return 
        if (p.setHandler(wrap(handler))) Running({ 
          shutdown: p.shutdown, 
          failures: Signal.trigger()
        })
        else Shutdown
    ).map(function (o) return switch o {
      case Success(v): v;
      case Failure(e): Failed(e);
    });
}
