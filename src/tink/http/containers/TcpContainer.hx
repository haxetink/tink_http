package tink.http.containers;

import tink.http.Container;
import tink.http.Handler;
import tink.http.Request;
import tink.http.Response;
import tink.tcp.Connection;

using tink.CoreApi;

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
      #if tink_tcp
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
              case Success({ data: header, rest: body }):
                
                switch header.byName('content-length') {
                  case Success(v):
                    body = body.limit(Std.parseInt(v));
                  default:
                }
                
                var req = new IncomingRequest(cnx.peer.host, header, body);
                
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
                      case SinkFailed(e) | SourceFailed(e): fail(e);
                      case SinkEnded: fail(new Error('${cnx.peer} hung up before the whole body was written'));
                      default:
                    }
                  });
                  
                });
              case Failure(e):  
                
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
