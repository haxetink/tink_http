package tink.http.containers;

import tink.core.Future;
import tink.http.Container;
import tink.http.Handler;
import tink.http.Header;
import tink.http.Method;
import tink.http.Request;

using tink.CoreApi;

class PhpContainer implements Container {
  static function getServerVar(key:String):String {
    return untyped __php__("$_SERVER[$key]");
  }
  static public var inst(default, null):PhpContainer = new PhpContainer();
  function new() {}
  
  public function run(handler:Handler):Future<ContainerResult> 
    return Future.async(function (cb) 
      handler.process(new IncomingRequest(
        getServerVar('REMOTE_ADDR'),
        new IncomingRequestHeader(
          Method.ofString(getServerVar('REQUEST_METHOD'), function (_) return GET),
          getServerVar('REQUEST_URI'),
          '1.1', //TODO: do something meaningful here,
          {
            var headers = php.Lib.hashOfAssociativeArray(untyped __call__('getallheaders'));
            [for (name in headers.keys())
              new HeaderField(name, headers[name])  
            ];
          }
        ),
        (untyped __call__('file_get_contents', 'php://input') : String)
      )).handle(function (res) {
        untyped __call__('http_response_code', res.header.statusCode);
        for (h in res.header.fields)
          untyped __call__('header', h.name, h.value);
        res.body.all().handle(function (o) {
          Sys.print(o.sure().getData());
          cb(Done);
        });
      })
    );
}