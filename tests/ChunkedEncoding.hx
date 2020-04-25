package ;

using tink.CoreApi;
import tink.http.Fetch;


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
    res.all().handle(
      function(x){switch(x){
        case Success(x) : 
          asserts.assert(true,"returned result");
        default         : 
          asserts.assert(false,"botched");
      }
    });
    return asserts.done();
  }  
}