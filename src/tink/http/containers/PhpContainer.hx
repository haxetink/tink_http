package tink.http.containers;

import php.NativeArray;
import sys.io.File;
import tink.core.Future;
import tink.core.Named;
import tink.http.Container;
import tink.http.Handler;
import tink.http.Header;
import tink.http.Method;
import tink.http.StructuredBody;
import tink.http.Request;
import tink.io.Sink;
import tink.io.Source;

using tink.CoreApi;

class PhpContainer implements Container {
  static function getServerVar(key:String):String {
    return untyped __php__("$_SERVER[$key]");
  }
  static public var inst(default, null):PhpContainer = new PhpContainer();
  
  function new() { }
 
  static function getParts<In>(a:NativeArray, process:In->BodyPart):StructuredBody {
    var map = php.Lib.hashOfAssociativeArray(a);
    var ret = [];
    for (name in map.keys()) 
      switch process(map[name]) {
        case null: 
        case v: ret.push(new Named(
          name,
          process(map[name])
        ));
      }
    return ret;
  }
  
  function getRequest() {    
    var header = new IncomingRequestHeader(
      Method.ofString(getServerVar('REQUEST_METHOD'), function (_) return GET),
      getServerVar('REQUEST_URI'),
      '1.1', //TODO: do something meaningful here,
      {
        var raw = php.Lib.hashOfAssociativeArray(untyped __call__('getallheaders'));
        [for (name in raw.keys())
          new HeaderField(name, raw[name])  
        ];
      }
    );
    
    return new IncomingRequest(
      getServerVar('REMOTE_ADDR'), 
      header,
      switch header.contentType() {
        case Success({ type: 'multipart', subtype: 'form-data' }) if (header.method == POST):
          Parsed(
            getParts(untyped __php__("$_POST"), Value)
            .concat(getParts(untyped __php__("$_FILES"), function (v:NativeArray) {
              //return Value(cast v);
              inline function prop<A>(name:String):A
                return untyped v[name];
                
              var tmpName = prop('tmp_name');            
              var name = prop('name');            
              
              return
                switch (prop('error') : Int) {
                  case 0: 
                    var streamName = 'uploaded file "$name" in temporary location "$tmpName"';
                    File({
                      fileName: name,
                      size: prop('size'),
                      mimeType: prop('type'),
                      read: function () return Source.ofInput(
                        name, 
                        sys.io.File.read(tmpName, true)
                      ),
                      saveTo: function (path:String) return Future.sync(
                        if (untyped __call__('rename', tmpName, path))
                          Success(Noise)
                        else
                          Failure(new Error('Failed to save $streamName to $path'))
                      )
                    });
                  default: null;
                }
            })) 
          );
        default: 
          Plain((untyped __call__('file_get_contents', 'php://input') : String));
      }
    );
  }
  
  public function run(handler:Handler):Future<ContainerResult> 
    return Future.async(function (cb) 
      handler.process(
        getRequest()
      ).handle(function (res) {
        untyped __call__('http_response_code', res.header.statusCode);
        for (h in res.header.fields)
          untyped __call__('header', h.name + ': ' + h.value);
          
        var out = Sink.ofOutput('output buffer', @:privateAccess new sys.io.FileOutput(untyped __call__('fopen', 'php://output', "w")));
        res.body.pipeTo(out, { end: true }).handle(function (o) {
          cb(Done);
        });
      })
    );
}
