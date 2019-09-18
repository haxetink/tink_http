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

  public inline function augment(pipeline:Processors):Client
    return CustomClient.create(this, pipeline.before, pipeline.after);
}

interface ClientObject {
  /**
   *  Performs an HTTP(s) request
   *  @param req - The HTTP request
   *  @return The HTTP response
   */
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}

typedef Processors = { 
  @:optional var before(default, never):Array<Preprocessor>;
  @:optional var after(default, never):Array<Postprocessor>;
}

typedef Preprocessor = Next<OutgoingRequest, OutgoingRequest>;
typedef Postprocessor = OutgoingRequest->Next<IncomingResponse, IncomingResponse>;

private class CustomClient implements ClientObject {
  
  var preprocessors:Array<Preprocessor>;
  var postprocessors:Array<Postprocessor>;
  var real:ClientObject;

  function new(preprocessors, postprocessors, real) {
    this.preprocessors = preprocessors;
    this.postprocessors = postprocessors;
    this.real = real;
  }

  function pipe<A>(value:A, transforms:Null<Array<Next<A, A>>>, ?index:Int = 0):Promise<A>
    return 
      if (transforms != null && index < transforms.length) 
        transforms[index](value)
          .next(pipe.bind(_, transforms, index + 1))
      else
        value;

  public function request(req) 
    return 
      pipe(req, preprocessors)
        .next(function (req) 
          return real.request(req)
            .next(pipe.bind(_, postprocessors == null ? null : [for (p in postprocessors) p(req)]))
        );

  static function concat<A>(a:Null<Array<A>>, b:Null<Array<A>>):Null<Array<A>>
    return switch [a, b] {
      case [null, v] | [v, null]: v;
      default: a.concat(b);
    }

  static public function create(c:ClientObject, preprocessors, postprocessors)
    return switch downcast(c, CustomClient) {
      case null: new CustomClient(preprocessors, postprocessors, c);
      case v: new CustomClient(concat(preprocessors, v.preprocessors), concat(v.postprocessors, postprocessors), v.real);
    }
}