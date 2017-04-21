package tink.http.clients;

import tink.http.Request;
import tink.http.Response;
using tink.CoreApi;

class SecureJsClient extends JsClient {
  override function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return jsRequest(req);
  }
}