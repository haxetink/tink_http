package tink.http;

import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

interface Container {
  /**
   *  Start the Container
   *  @param handler - The HTTP handler (see `Handler`)
   *  @return ContainerResult: For non-persistent containers like modneko & php, it will be Shutdown. For persistent containers such as nodejs, it will be Running
   */
  function run(handler:Handler):Future<ContainerResult>;
}

enum ContainerResult {
  Running(running:RunningState);
  Failed(e:Error);
  Shutdown;
}

typedef RunningState = {
  var failures(default, null):Signal<ContainerFailure>;
  function shutdown(hard:Bool):Promise<Bool>;
}

typedef ContainerFailure = { 
  var error(default, null):Error;
  var request(default, null):IncomingRequest;
  var response(default, null):OutgoingResponse;  
};