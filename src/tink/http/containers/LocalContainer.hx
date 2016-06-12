package tink.http.containers;

import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.io.IdealSource;

using tink.CoreApi;

class LocalContainer implements Container {
  
  var server:LocalContainerServer;
  
  public function new() {}
  
  public function run(handler:Handler) {
    var running = true;
    server = new LocalContainerServer(handler);
    return Future.sync(Running(server));
  }
}

class LocalContainerServer {
  
  public var failures(default, null):Signal<ContainerFailure>;
  var handler:Handler;
  var running:Bool;
  
  public function new(handler) {
    this.handler = handler;
    failures = new SignalTrigger();
    running = true;
  }
  
  public function serve(req:IncomingRequest) {
    if(!running) return Future.sync(new OutgoingResponse(
      new ResponseHeader(503, 'Server stopped', []),
      Empty.instance
    ));
    return handler.process(req);
  }
  
  public function shutdown(hard:Bool) {
    running = false;
    return Future.sync(Noise);
  }
}