package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.http.Message;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.io.IdealSink.BlackHole;

import haxe.io.BytesOutput;
import tink.io.*;
using StringTools;

using tink.CoreApi;

interface Container {
  function run(application:Application):Void;
}

#if nodejs
class NodeContainer implements Container {
  
  public var server(default, null):js.node.http.Server;
  var port:Int;
  
  public function new(port) {
    this.port = port;
  }
  
  static public function toNodeHandler(handler:IncomingRequest->Future<OutgoingResponse>)
    return 
      function (req:js.node.http.IncomingMessage, res:js.node.http.ServerResponse)
        handler(
          new IncomingRequest(
            req.socket.remoteAddress, 
            new IncomingRequestHeader(cast req.method, req.url, req.httpVersion, [for (i in 0...Std.int(req.rawHeaders.length / 2)) new HeaderField(req.rawHeaders[2 * i], req.rawHeaders[2 * i +1])]), 
            Source.ofNodeStream('Incoming HTTP message from ${req.socket.remoteAddress}', req))
        ).handle(function (out) {
          res.writeHead(out.header.statusCode, out.header.reason, cast [for (h in out.header.fields) [(h.name : String), h.value]]);//TODO: readable status code
          out.body.pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${req.socket.remoteAddress}', res)).handle(function (x) {
            res.end();
          });
        });
  
  
  public function run(application:Application) {
    server = js.node.Http.createServer(toNodeHandler(application.serve));
    application.done.handle(function () { 
      server.close();
    });
    server.listen(port);
    server.on('error', function (e) application.onError(Error.reporter('Failed to bind port $port')(e)));
  }
}
#end

#if (php || neko)
private typedef Cgi = 
  #if neko
    neko.Web;
  #else
    php.Web;
  #end
 
class CgiContainer implements Container {
  function new() { }
  
  function getRequest() {
    return new IncomingRequest(
      Cgi.getClientIP(),
      new IncomingRequestHeader(
        cast Cgi.getMethod(),
        Cgi.getURI(),
        'HTTP/1.1',
        [for (h in Cgi.getClientHeaders()) new HeaderField(h.header, h.value)]
      ),
      (Cgi.getPostData() : IdealSource)
    );
  }
  
  
  public function run(application:Application) {
      
    function doRun() 
      application.serve(getRequest()).handle(function (response) {
        Cgi.setReturnCode(response.header.statusCode);
        for (h in response.header.fields)
          Cgi.setHeader(h.name, h.value);
        var out = new BytesOutput();
        response.body.pipeTo(Sink.ofOutput('buf', out)).handle(function (x) {
          Sys.print(out.getBytes().toString());
        });          
      });
    
    
    #if neko
      #if tink_runloop
        Cgi.cacheModule(function () { @:privateAccess tink.RunLoop.current.spin(doRun); } );//this is not exactly pretty, but it should do the job for now
      #else
        Cgi.cacheModule(doRun);
      #end
    #end
    doRun();
  }
  static public var instance(default, null):Container = new CgiContainer(); 
}
#end
class TcpContainer implements Container {
  
  var port:Int;
  var maxConcurrent:Int;
  @:require(tink_tcp)
  public function new(port:Int, ?maxConcurrent:Int = 1 << 16) {
    this.port = port;
    this.maxConcurrent = maxConcurrent;
  }
  
  public function run(application:Application) {
    #if tink_tcp
    tink.tcp.Server.bind(port).handle(function (o) switch o {
      case Success(server):
        
        application.done.handle(server.close);
        var pending = new List();
        var current = 0;
        
        function serve(cnx:tink.tcp.Connection, next:Void->Void)
          cnx.source.parse(IncomingRequestHeader.parser()).handle(function (o) switch o {
            case Success({ data: header, rest: body }):
              
              switch header.byName('content-length') {
                case Success(v):
                  body = body.limit(Std.parseInt(v));
                default:
              }
              
              application.serve(new IncomingRequest(cnx.peer.host, header, body)).handle(function (res) {
                
                res.body.prepend(res.header.toString()).pipeTo(cnx.sink, { end: true }).handle(function (r) {
                  next(); 
                  switch r {
                    case SinkFailed(e) | SourceFailed(e): application.onError(e);
                    case SinkEnded: application.onError(new Error('${cnx.peer} hung up before the whole body was written'));
                    default:
                  }
                });
                
              });
            case Failure(e):  
              application.onError(e);
              cnx.close();
              next();
          });          
        
        server.connected.handle(function (cnx) {
          //serve(cnx, function () { } );
          //return;
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
        application.onError(e);
    });
    #end
  }
}
