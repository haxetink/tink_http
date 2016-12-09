package tink.http;

import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

typedef HandlerFunction = IncomingRequest->Future<OutgoingResponse>;

@:forward
abstract Handler(HandlerObject) from HandlerObject to HandlerObject {
  
  public inline function applyMiddleware(m:Middleware)
    return m.apply(this);
  
  @:from
  public static inline function ofFunc(f:HandlerFunction):Handler
    return new SimpleHandler(f);
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