package tink.http;

import haxe.DynamicAccess;
import tink.io.Sink;
import tink.io.Source;
import tink.io.StreamParser;
import tink.http.Message;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.io.Worker;

#if tink_tcp
import tink.tcp.Connection;
import tink.tcp.Endpoint;
#end

#if nodejs
import js.node.http.IncomingMessage;
#end

using tink.CoreApi;
using StringTools;

@:forward
abstract Client(ClientObject) from ClientObject to ClientObject {
  
}

interface ClientObject {
  function request(req:OutgoingRequest):Future<IncomingResponse>;
}

class StdClient implements ClientObject {
  var worker:Worker;
  public function new() {}
  public function request(req:OutgoingRequest):Future<IncomingResponse> 
    return Future.async(function (cb) {
            
      var r = new haxe.Http('http:'+req.header.fullUri());
      
      function send(post) {
        var code = 200;
        r.onStatus = function (c) code = c;
        
        function headers()
          return 
            #if sys
              switch r.responseHeaders {
                case null: [];
                case v:
                  [for (name in v.keys()) 
                    new HeaderField(name, v[name])
                  ];
              }
            #else
              [];
            #end
          
        r.onError = function (msg) {
          if (code == 200) code = 500;
          worker.work(true).handle(function () {
            cb(new IncomingResponse(new ResponseHeader(code, 'error', headers()), msg));        
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        r.onData = function (data) {
          
          worker.work(true).handle(function () {
            cb(new IncomingResponse(new ResponseHeader(code, 'OK', headers()), data));
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        worker.work(function () r.request(post));
      }      
      
      for (h in req.header.fields)
        r.setHeader(h.name, h.value);
        
      switch req.header.method {
        case GET | HEAD | OPTIONS:
          send(false);
        default:
          
          //r.setPostData(
      }
    });
}

#if tink_tcp
class TcpClient implements ClientObject { 
  public function new() {}
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    
    var cnx = Connection.establish({ host: req.header.host, port: req.header.port });
    
    req.body.prepend(req.header.toString()).pipeTo(cnx.sink).handle(function (x) {
      cnx.sink.close();//TODO: implement connection reuse
    });
    
    return cnx.source.parse(new ResponseHeaderParser()).map(function (o) return switch o {
      case Success({ data: header, rest: body }):
        new IncomingResponse(header, body);
      case Failure(e):
        new IncomingResponse(new ResponseHeader(e.code, e.message, []), (e.message : Source).append(e));
    });
  }
}
#end

class NodeClient implements ClientObject {
  @:require(nodejs)
  public function new() {}
  public function request(req:OutgoingRequest):Future<IncomingResponse> 
    return 
      #if nodejs
        Future.async(function (cb) {
          var fwd = js.node.Http.request(
            {
              method: cast req.header.method,
              path: req.header.uri,
              host: req.header.host,
              port: req.header.port,
              headers: {
                var map = new DynamicAccess<String>();
                for (h in req.header.fields)
                  map[h.name] = h.value;
                map;
              },
              agent: false,
            }, 
            function (msg:IncomingMessage) cb(new IncomingResponse(
              new ResponseHeader(
                msg.statusCode,
                Std.string(msg.statusCode),
                [for (name in msg.headers.keys()) new HeaderField(name, msg.headers[name])]
              ),
              Source.ofNodeStream(msg, 'Response from ${req.header.fullUri()}')
            ))
          );
          
          function fail(e:Error)
            cb(new IncomingResponse(
              new ResponseHeader(e.code, e.message, []),
              e.message
            ));
            
          fwd.on('error', function () fail(new Error(502, 'Gateway Error')));
          
          req.body.pipeSafelyTo(
            Sink.ofNodeStream(fwd, 'Request to ${req.header.fullUri()}')
          ).handle(function (res) {
            fwd.end();
            req.body.closeSafely();
            switch res {
              case AllWritten:
              case SinkEnded(_): fail(new Error(502, 'Gateway Error'));
              case SinkFailed(e, _): fail(new Error(502, 'Gateway Error'));
            }
          });
        });
    #else
      throw 'unreachable';
    #end
}

class ResponseHeaderParser extends ByteWiseParser<ResponseHeader> {
	var header:ResponseHeader;
  var fields:Array<HeaderField>;
	var buf:StringBuf;
	var last:Int = -1;
  
	public function new() {
		this.buf = new StringBuf();
		super();
	}
  
	static var INVALID = Failed(new Error(UnprocessableEntity, 'Invalid HTTP header'));  
        
  override function read(c:Int):ParseStep<ResponseHeader> 
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
									case [protocol, status, reason]:
										this.header = new ResponseHeader(Std.parseInt(status), reason, fields = []);
										Progressed;
									default: 
										INVALID;
								}
							else {
								var s = line.indexOf(':');
								switch [line.substr(0, s), line.substr(s+1).trim()] {
									case [name, value]: 
                    fields.push(new HeaderField(name, value));//urldecode?
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