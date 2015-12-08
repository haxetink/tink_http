package tink.http;

import haxe.io.BytesBuffer;
import tink.http.Message;
import tink.http.Request;
import tink.http.Response;
import tink.tcp.Server;

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
        new IncomingRequest(cast req.method, req.url, new RequestHeaders([]), Source.ofNodeStream(req, 'Incoming HTTP message from ${req.socket.remoteAddress}'))
      ).handle(function (out) {
        res.writeHead(out.status, 'ok');
        out.body.pipeTo(Sink.ofNodeStream(res, 'Outgoing HTTP response to ${req.socket.remoteAddress}')).handle(function (x) {
          res.end();
        });
      });
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
      new IncomingRequestHeader(
        cast Cgi.getMethod(),
        Cgi.getURI(),
        'HTTP/1.1',
        [for (h in Cgi.getClientHeaders()) new MessageHeaderField(h.header, h.value)]
      ),
      (Cgi.getPostData() : IdealSource)
    );
  }
  
  
  public function run(application:Application) {
    haxe.Log.trace = function (v:Dynamic, ?pos)
      Cgi.logMessage('${pos.className}@${pos.lineNumber}: $v');
      
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

#if neko
class TcpContainer implements Container {
  
  var port:Int;
  
  public function new(port:Int) {
    this.port = port;
  }
  
  public function run(application:Application) {
    Server.bind(port).handle(function (o) switch o {
      case Success(server):
        
        application.done.handle(server.close);
        
        server.connected.handle(function (cnx) {
          
          cnx.source.parse(IncomingRequestHeader.parser()).handle(function (o) switch o {
            case Success( { data: header, rest: body } ):
              
              application.serve(new IncomingRequest(header, body)).handle(function (res) {
                
                res.body.prepend(res.header.toString()).pipeTo(cnx.sink.idealize(application.onError)).handle(function (result) switch result {
                  case AllWritten:
                    cnx.close();
                  case SourceFailed(e):
                    e.throwSelf();//this is only here because there's no easy way to append ideal sources
                });
              });
            case Failure(e):  
              application.onError(e);
              cnx.close();
          });
          
        });
      case Failure(e):
        application.onError(e);
    });
  }
}

#end