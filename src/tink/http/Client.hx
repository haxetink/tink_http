package tink.http;

import haxe.extern.Rest;
import tink.http.Request;
import tink.http.Response;
import tink.http.Fetch;

#if haxe4 
  import Std.downcast;
#elseif haxe3
  import Std.instance as downcast;
#end

using tink.CoreApi;

@:forward
abstract Client(ClientObject) from ClientObject to ClientObject {
  public static inline function fetch(url:Url, ?options:FetchOptions):FetchResponse {
    return Fetch.fetch(url, options);
  }

  public inline function augment(pre:Array<Preprocessor>, post:Array<Postprocessor>)
    return CustomClient.create(this, pre, post);
}

interface ClientObject {
  /**
   *  Performs an HTTP(s) request
   *  @param req - The HTTP request
   *  @return The HTTP response
   */
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}

private typedef Preprocessor = Next<OutgoingRequest, OutgoingRequest>;
private typedef Postprocessor = Next<IncomingResponse, IncomingResponse>;

private class CustomClient implements ClientObject {
  
  var preprocessors:Array<Preprocessor>;
  var postprocessors:Array<Postprocessor>;
  var real:ClientObject;

  function new(preprocessors, postprocessors, real) {
    this.preprocessors = preprocessors;
    this.postprocessors = postprocessors;
    this.real = real;
  }

  function pipe<A>(value:A, transforms:Array<Next<A, A>>, ?index:Int = 0):Promise<A>
    return 
      if (index < transforms.length) 
        transforms[index](value)
          .next(pipe.bind(_, transforms, index + 1))
      else
        value;

  public function request(req) 
    return 
      pipe(req, preprocessors).next(real.request).next(pipe.bind(_, postprocessors));

  static public function create(c:ClientObject, preprocessors, postprocessors)
    return switch downcast(c, CustomClient) {
      case null: new CustomClient(preprocessors, postprocessors, c);
      case v: new CustomClient(preprocessors.concat(v.preprocessors), v.postprocessors.concat(postprocessors), v.real);
    }
}