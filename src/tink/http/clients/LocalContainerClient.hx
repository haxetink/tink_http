package tink.http.clients;

import tink.http.Client;
import tink.http.Header;
import tink.http.Response;
import tink.http.Request;

using tink.CoreApi;

@:access(tink.http.containers.LocalContainer)
class LocalContainerClient implements ClientObject {
  
  var container:tink.http.containers.LocalContainer;
  public function new(container) {
    this.container = container;
  }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
      return container.serve(new IncomingRequest(
        '127.0.0.1',
        new IncomingRequestHeader(req.header.method, req.header.url.pathWithQuery, 'HTTP/1.1', @:privateAccess req.header.fields),
        Plain(cast req.body)
      )).next(
        function(res:OutgoingResponse) return new IncomingResponse(
          res.header,
          cast res.body
        )
      );
    }
    
}