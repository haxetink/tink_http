package tink.http.clients;

class SecureJsClient extends JsClient {
  override function request(req:OutgoingRequest):Future<IncomingResponse> {
    return jsRequest(req, switch req.header.host {
        case null: ''; // TODO: js.Browser.window.location?
        case v: 'https://$v';
    });
  }
}