package tink.http;

import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

typedef HandlerFunction = IncomingRequest->Future<OutgoingResponse>;

abstract Handler(HandlerFunction) from HandlerFunction to HandlerFunction {
  
  public inline function process(req) 
    return this(req);
    
}