package tink.http.containers;

import tink.http.Container;
import tink.http.Handler;
import tink.http.Request;
import tink.http.Response;
//import tink.tcp.Connection;

//using tink.io.StreamParser;
using tink.io.Source;
using tink.io.Sink;
using tink.CoreApi;

typedef Connection = {
  var local(default, never):tink.tcp.Endpoint;
  var remote(default, never):tink.tcp.Endpoint;
  var stream(default, never):RealSource;
}
typedef TcpHandler = Connection->Future<IdealSource>;

typedef TcpPort = {
  function setHandler(handler:TcpHandler):Void;
}

class TcpContainer implements Container {
  
  var port:Int;
  var maxConcurrent:Int;
  var onInvalidRequest:Null<Error->Connection->Void>;
  
  @:require(tink_tcp)
  public function new(port:Int, maxConcurrent:Int = 1 << 16, ?onInvalidRequest) {
    this.port = port;
    this.maxConcurrent = maxConcurrent;
    this.onInvalidRequest = onInvalidRequest;
  }
  
  public function run(handler:Handler):Future<ContainerResult> {
    return Future.async(function (cb) {
      var handler:TcpHandler = function (incoming:Connection) {
        return incoming.stream.parse(IncomingRequestHeader.parser())
          .next(function (r) {
            trace(r);
            var req = new IncomingRequest(incoming.remote.host, r.a, Plain(r.b));
            return handler.process(req);
          })
          .recover(OutgoingResponse.reportError)
          .map(function (res) return res.body.prepend(res.header.toString()));
      }
      js.node.Net.createServer(function (cnx) {
        handler({
          remote: { host: 'localhost', port: 123 },
          local: { host: 'localhost', port: port },
          stream: Source.ofNodeStream('', cnx),
        }).handle(function (res) {
          res.pipeTo(Sink.ofNodeStream('', cnx), { end: true }).handle(function (o) {
            cnx.destroy();
          });
        });
      }).listen(port);
      #if tink_tcp_
      tink.tcp.Server.bind(port).handle(function (o) switch o {
        case Success(server):
          
          var failures = Signal.trigger();
          
          cb(Running({
            shutdown: function (hard:Bool) {
              if (!hard)
                trace('Warning: soft shutdown not implemented');//TODO: implement soft shutdown
              server.close();
              return Future.sync(Noise);
            },
            failures: failures,
          }));
          
          var pending = new List();
          var current = 0;
          
          function serve(cnx:Connection, ?next:Void->Void)
            cnx.source.parse(IncomingRequestHeader.parser()).handle(function (o) switch o {
              case Parsed(header, body):
                // switch header.byName('content-length') {
                //   case Success(v):
                //     body = body.limit(Std.parseInt(v));
                //   default:
                // }
                
                var req = new IncomingRequest(cnx.peer.host, header, Plain(body));
                
                handler.process(req).handle(function (res) {
                  
                  function fail(e)
                    failures.trigger({
                      error: e,
                      request: req,
                      response: res,
                    });
                  
                  res.body.prepend(res.header.toString()).pipeTo(cnx.sink, { end: true }).handle(function (r) {

                    if (next != null)
                      next(); 

                    switch r {
                      case SinkFailed(e, _): fail(e);
                      case SinkEnded(_, _): fail(new Error('${cnx.peer} hung up before the whole body was written'));
                      default:
                    }
                  });
                  
                });
              case Invalid(e, _) | Broke(e):  
                
                switch onInvalidRequest {
                  case null:
                  case v: v(e, cnx);
                }
                
                cnx.close();
                if (next != null)
                  next();
            });          
          
          server.connected.handle(function (cnx) {
            if (maxConcurrent <= 0) {
              serve(cnx);
              return;
            }
            pending.add(cnx);
            
            function next() 
              switch pending.pop() {
                case null:
                  current--;
                case cnx:
                  serve(cnx, next);
              }
              
            if (current < maxConcurrent) {
              current++;
              next();
            }
            
          });
        case Failure(e):
          cb(Failed(e));
      });
      #end
    });
  }
}
