package tink.http;

import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

typedef Application = {
  var done(default, never):Future<Noise>;
  function serve(request:IncomingRequest):Future<OutgoingResponse>;
  function onError(e:Error):Void;
}