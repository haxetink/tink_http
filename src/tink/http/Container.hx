package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.http.Message;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.io.IdealSink.BlackHole;

import haxe.io.BytesOutput;
import tink.io.*;

using StringTools;
using tink.CoreApi;

interface Container {
  function run(handler:Handler):Future<ContainerResult>;
}

enum ContainerResult {
  Running(running:RunningState);
  Failed(e:Error);
  Done;
}

typedef RunningState = {
  var failures(default, null):Signal<ContainerFailure>;
  function shutdown(hard:Bool):Future<Noise>;
}

typedef ContainerFailure = { 
  var error(default, null):Error;
  var request(default, null):IncomingRequest;
  var response(default, null):OutgoingResponse;  
};