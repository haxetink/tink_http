package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.http.Message;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

import haxe.io.BytesOutput;
import tink.io.*;
using StringTools;

using tink.CoreApi;

interface Container {
  function run(application:Application):Void;
}

#if nodejs
class NodeContainer implements Container {
  
  var port:Int;
  
  public function new(port) {
    this.port = port;
  }
  
  public function run(application:Application) {
    var server = js.node.Http.createServer(function (req:js.node.http.IncomingMessage, res:js.node.http.ServerResponse) {
      application.serve(
        new IncomingRequest(
          req.socket.remoteAddress, 
          new IncomingRequestHeader(cast req.method, req.url, req.httpVersion, [for (name in req.headers.keys()) new HeaderField(name, req.headers[name])]), 
          Source.ofNodeStream(req, 'Incoming HTTP message from ${req.socket.remoteAddress}'))
      ).handle(function (out) {
        res.writeHead(out.header.statusCode, Std.string(out.header.statusCode), cast [for (h in out.header.fields) [(h.name : String), h.value]]);//TODO: readable status code
        out.body.pipeTo(Sink.ofNodeStream(res, 'Outgoing HTTP response to ${req.socket.remoteAddress}')).handle(function (x) {
          res.end();
        });
      });
    });
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

@:require(tink_tcp)
class TcpContainer implements Container {
  #if tink_tcp
  var port:Int;
  var maxConcurrent:Int;
  public function new(port:Int, ?maxConcurrent:Int = 256) {
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
          
        function serve(cnx:tink.tcp.Connection, next)
          cnx.source.parse(IncomingRequestHeader.parser()).handle(function (o) switch o {
            case Success( { data: header, rest: body } ):
              
              switch header.byName('content-length') {
                case Success(v):
                  body = body.limit(Std.parseInt(v));
                default:
              }
              
              application.serve(new IncomingRequest(cnx.peer.host, header, body)).handle(function (res) {
                
                res.body.prepend(res.header.toString()).pipeTo(cnx.sink.idealize(application.onError)).handle(function (result) switch result {
                  case AllWritten:
                    cnx.close();
                    next();
                  case SourceFailed(_):
                    //this is only here because currently there's no easy way to append ideal sources
                });
                
              });
            case Failure(e):  
              application.onError(e);
              cnx.close();
              next();
          });          
        
        server.connected.handle(function (cnx) {
          //cnx.source.pipeTo(Sink.stdout);
          //IncomingRequest.parse(cnx.peer, cnx.source).handle(function (x) trace(x));
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
  #else
  public function run(_) { }
  #end 
}