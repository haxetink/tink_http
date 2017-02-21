package tink.http;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

interface Container {
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