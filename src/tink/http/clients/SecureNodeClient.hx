package tink.http.clients;

import haxe.DynamicAccess;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

class SecureNodeClient extends NodeClient {
  override function request(req:OutgoingRequest):Promise<IncomingResponse> {
    var options:js.node.Https.HttpsRequestOptions = {
      method: cast req.header.method,
      path: req.header.url.pathWithQuery,
      host: req.header.url.host.name,
      port: req.header.url.host.port,
      headers: cast {
        var map = new DynamicAccess<String>();
        for (h in req.header)
          map[h.name] = h.value;
        map;
      },
      agent: false,
    }
    return nodeRequest(js.node.Https, options, req);
  }
}