package tink.http;

import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

typedef Application = {
  function serve(request:IncomingRequest):Future<OutgoingResponse>;
  function onError(e:Error):Void;
}