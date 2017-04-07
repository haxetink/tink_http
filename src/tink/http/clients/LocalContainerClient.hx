package tink.http.clients;

@:access(tink.http.containers.LocalContainer)
class LocalContainerClient implements ClientObject {
  
  var container:tink.http.containers.LocalContainer;
  public function new(container) {
    this.container = container;
  }
  
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
      return container.serve(new IncomingRequest(
        '127.0.0.1',
        new IncomingRequestHeader(req.header.method, req.header.uri, 'HTTP/1.1', req.header.fields),
        Plain(req.body)
      )) >>
      function(res:OutgoingResponse) return new IncomingResponse(
        res.header,
        res.body
      );
    }
    
}