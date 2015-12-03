package tink.http;

import haxe.io.BytesBuffer;
import tink.http.Message;
import tink.http.Request;
import tink.http.Response;
import tink.tcp.Server;
import tink.io.StreamParser;

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
      new RequestHeader(
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
  var server:Server;
  
  public function new(port:Int) {
    this.port = port;
  }
  
  public function run(application:Application) {
    Server.bind(port).handle(function (o) switch o {
      case Success(server):
        server.connected.handle(function (cnx) {
          
          cnx.source.parse(new RequestHeaderParser()).handle(function (o) switch o {
            case Success( { data: header, rest: body } ):
              application.serve(new IncomingRequest(header, body)).handle(function (res) {
                var buf = new BytesBuffer();
                function line(?line:String) {
                  if (line != null)
                    buf.addString(line);
                  buf.addByte('\r'.code);
                  buf.addByte('\n'.code);
                }
                line('HTTP/1.1 ${res.header.statusCode} ${res.header.reason}');
                for (h in res.header.fields)
                  line(h.name+': ' + h.value);
                line();
                
                res.body.prepend(buf.getBytes()).pipeTo(cnx.sink).handle(function (result) switch result.status {
                  case AllWritten:
                    cnx.close();
                  case SinkEnded(_):
                    application.onError(new Error('remote end hung up unexpectedly'));
                    cnx.close();
                  case SinkFailed(e, _):
                    application.onError(e);
                    cnx.close();
                  case SourceFailed(e):
                    e.throwSelf();
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

private class RequestHeaderParser extends ByteWiseParser<RequestHeader> {
	var header:RequestHeader;
  var fields:Array<MessageHeaderField>;
	var buf:StringBuf;
	var last:Int = -1;
  
	public function new() {
		this.buf = new StringBuf();
		super();
	}
  
	static var INVALID = Failed(new Error(UnprocessableEntity, 'Invalid HTTP header'));  
        
  override function read(c:Int):ParseStep<RequestHeader> 
    return
			switch [last, c] {
				case [_, -1]:
					
					if (header == null)
            Progressed;
          else
            Done(header);
					
				case ['\r'.code, '\n'.code]:
					
					var line = buf.toString();
					buf = new StringBuf();
					last = -1;
					
					switch line {
						case '':
              if (header == null)
                INVALID;
              else
                Done(header);
						default:
							if (header == null)
								switch line.split(' ') {
									case [method, url, protocol]:
										this.header = new RequestHeader(cast method, url, protocol, fields = []);
										Progressed;
									default: 
										INVALID;
								}
							else {
								var s = line.indexOf(':');
								switch [line.substr(0, s), line.substr(s+1).trim()] {
									case [name, value]: 
                    fields.push(new MessageHeaderField(name, value));//urldecode?
								}
								Progressed;
							}
					}
						
				case ['\r'.code, '\r'.code]:
					
					buf.addChar(last);
					Progressed;
					
				case ['\r'.code, other]:
					
					buf.addChar(last);
					buf.addChar(other);
					last = -1;
					Progressed;
					
				case [_, '\r'.code]:
					
					last = '\r'.code;
					Progressed;
					
				case [_, other]:
					
					last = other;
					buf.addChar(other);
					Progressed;
			}
  
}
#end