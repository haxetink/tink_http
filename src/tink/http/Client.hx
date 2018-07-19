package tink.http;

import tink.http.Request;
import tink.http.Response;
import tink.http.Fetch;
using tink.CoreApi;

@:forward
abstract Client(ClientObject) from ClientObject to ClientObject {
  public static inline function fetch(url:Url, ?options:FetchOptions):FetchResponse {
    return Fetch.fetch(url, options);
  }
}

interface ClientObject {
  /**
   *  Performs an HTTP(s) request
   *  @param req - The HTTP request
   *  @return The HTTP response
   */
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}

