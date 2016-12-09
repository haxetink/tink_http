package tink.http;

typedef MiddlewareFunction = Handler->Handler;

@:forward
abstract Middleware(MiddlewareObject) from MiddlewareObject to MiddlewareObject {
  @:from
  public static inline function ofFunc(f:MiddlewareFunction):Middleware
    return new SimpleMiddleware(f);
}

class SimpleMiddleware implements MiddlewareObject {
  var f:MiddlewareFunction;
  
  public function new(f)
    this.f = f;
    
  public function apply(handler:Handler):Handler
    return f(handler);
}

interface MiddlewareObject {
	function apply(handler:Handler):Handler;
}