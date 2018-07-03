package tink.http;

import tink.http.Request;
import tink.http.Response;
using tink.CoreApi;

@:forward
abstract Client(ClientObject) from ClientObject to ClientObject {
  
}

interface ClientObject {
  /**
   *  Performs an HTTP(s) request
   *  @param req - The HTTP request
   *  @return The HTTP response
   */
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}