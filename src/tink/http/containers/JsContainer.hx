package tink.http.containers;

import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.io.IdealSource;

using tink.CoreApi;

class JsContainer implements Container {
  public function new() {}
  
  public function run(handler:Handler) {
    var running = true;
    return Future.sync(Running(new JsContainerServer(handler)));
  }
}

class JsContainerServer {
  
  public var failures(default, null):Signal<ContainerFailure>;
  var running:Bool;
  var handler:Handler;
  
  public function new(handler) {
    this.handler = handler;
    failures = new SignalTrigger();
    running = true;
  }
  
  public function serve(req:IncomingRequest) {
    if(!running) return Future.sync(new OutgoingResponse(
      new ResponseHeader(502, 'Gateway Error', []),
      Empty.instance
    ));
    return handler.process(req);
  }
  
  public function shutdown(hard:Bool) {
    running = false;
    return Future.sync(Noise);
  }
}