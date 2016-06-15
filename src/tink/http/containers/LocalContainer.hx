package tink.http.containers;

import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.io.IdealSource;

using tink.CoreApi;

class LocalContainer implements Container {
  
  var handler:Handler;
  var running:Bool;
  
  public function new() {}
  
  public function run(handler:Handler) {
    this.handler = handler;
    running = true;
    return Future.sync(Running({
      failures: new SignalTrigger(),
      shutdown: function (hard:Bool) {
        running = false;
        return Future.sync(Noise);
      }
    }));
  }
  function serve(req:IncomingRequest) {
    if(!running) return Future.sync(new OutgoingResponse(
      new ResponseHeader(503, 'Server stopped', []),
      Empty.instance
    ));
    return handler.process(req);
  }
}
