package tink.http;

import tink.http.Request;
import tink.http.Response;
using tink.CoreApi;

@:forward
abstract Client(ClientObject) from ClientObject to ClientObject {
  
}

interface ClientObject {
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}