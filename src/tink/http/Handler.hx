package tink.http;

import tink.http.Request;
import tink.http.Response;
import tink.io.*;
#if nodejs
import js.node.http.*;
#end

using tink.CoreApi;

typedef HandlerFunction = IncomingRequest->Future<OutgoingResponse>;

@:forward
abstract Handler(HandlerObject) from HandlerObject to HandlerObject {
  
  #if tink_http_middleware
  public inline function applyMiddleware(m:Middleware)
    return m.apply(this);
  #end
  
  @:from
  public static inline function ofFunc(f:HandlerFunction):Handler
    return new SimpleHandler(f);
  
  #if nodejs
  public function toNodeHandler(?options:{?body:IncomingMessage->IncomingRequestBody}) {
    var body =
      switch options {
        case null | {body: null}: function(msg:IncomingMessage) return Plain(Source.ofNodeStream('Incoming HTTP message from ${msg.socket.remoteAddress}', msg));
        case _: options.body;
      }
    return 
      function (req:IncomingMessage, res:ServerResponse)
        this.process(
          new IncomingRequest(
            req.socket.remoteAddress, 
            IncomingRequestHeader.fromIncomingMessage(req),
            body(req)
        )).handle(function (out) {
          var headers = new Map();
          for(h in out.header) {
            if(!headers.exists(h.name)) headers[h.name] = [];
            headers[h.name].push(h.value);
          }
          for(name in headers.keys())
            res.setHeader(name, headers[name]);
          res.writeHead(out.header.statusCode, out.header.reason);//TODO: readable status code
          out.body.pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${req.socket.remoteAddress}', res)).handle(function (x) {
            res.end();
          });
        });
  }
  #end
}

class SimpleHandler implements HandlerObject {
  var f:HandlerFunction;
  
  public function new(f)
    this.f = f;
    
  public function process(req:IncomingRequest):Future<OutgoingResponse>
    return f(req);
}

interface HandlerObject {
  function process(req:IncomingRequest):Future<OutgoingResponse>;
}