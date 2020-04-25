package ;

using tink.CoreApi;
import tink.http.Fetch;

import tink.http.clients.SocketClientChunkedEncoding;

@:asserts
@:timeout(10000) 
class ChunkedEncoding{
  public function new(){}
  public function make_request(){
    var assertion = Future.trigger();
    var res = Fetch.fetch(
      "https://api.github.com",
      //"http://anglesharp.azurewebsites.net/Chunked"
      {
        headers : [
          new tink.http.Header.HeaderField('user-agent',
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2852.87 Safari/537.36"
          )
        ]
      }
    );
    res.progress().handle(
      (x) -> switch(x){
        case Success(s) :
          trace(s.body);
        case Failure(e) : 
          trace(e);
      }
    );
    res.all().handle(
      (x) -> switch(x){
        case Success(x) : 
          assertion.trigger(asserts.assert(true,"returned result"));null;
        default         : 
          assertion.trigger(asserts.assert(false));null;
      }
    );
    return assertion.asFuture();
  }  
}