package tink.http.clients;

import tink.http.Request;
import tink.http.Response;
using tink.CoreApi;

class SecureJsClient extends JsClient {
  public function new(?credentials) {
    super(credentials);
    secure = true;
  }
  override function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return jsRequest(req);
  }
}