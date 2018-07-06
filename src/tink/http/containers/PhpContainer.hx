package tink.http.containers;

import php.NativeArray;
import sys.io.File;
import tink.http.Container;
import tink.http.Handler;
import tink.http.Header;
import tink.http.StructuredBody;
import tink.http.Request;
import tink.io.Sink;
import tink.io.Source;

using StringTools;
using tink.CoreApi;

class PhpContainer implements Container {
  inline static function getServerVar(key:String):String {
    return untyped __php__("$_SERVER[{0}]", key);
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
        if (untyped __call__('function_exists', 'getallheaders')) {
          var raw = php.Lib.hashOfAssociativeArray(untyped __call__('getallheaders'));
          [for (name in raw.keys()) new HeaderField(name, raw[name])];
        } else {
          var h = php.Lib.hashOfAssociativeArray(untyped __php__("$_SERVER"));
          var headers = [];
          inline function add(name, value) headers.push(new HeaderField(name, value));
          for(k in h.keys()) {
            var key = switch k {
              case 'CONTENT_TYPE' if(!h.exists('HTTP_CONTENT_TYPE')): 'Content-Type';
              case 'CONTENT_LENGTH' if(!h.exists('HTTP_CONTENT_LENGTH')): 'Content-Length';
              case 'CONTENT_MD5' if(!h.exists('HTTP_CONTENT_MD5')): 'Content-Md5';
              case _ if(k.substr(0,5) == "HTTP_"): k.substr(5).replace('_', '-');
              case _: continue;
            }
            add(key, h.get(k));
          }
          if(!h.exists('HTTP_AUTHORIZATION')) {
            if(h.exists('REDIRECT_HTTP_AUTHORIZATION')) {
                add('Authorization', h.get('REDIRECT_HTTP_AUTHORIZATION'));
            } else if(h.exists('PHP_AUTH_USER')) {
                var basic = h.exists('PHP_AUTH_PW') ? h.get('PHP_AUTH_PW') : '';
                add('Authorization', 'Basic ' + haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(h.get('PHP_AUTH_USER'))).toString() + ':$basic');
            } else if(h.exists('PHP_AUTH_DIGEST')) {
                add('Authorization', h.get('PHP_AUTH_DIGEST'));
            }
          }
          headers;
        }
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
        for (h in res.header)
          untyped __call__('header', h.name + ': ' + h.value);
          
        var out = Sink.ofOutput('output buffer', @:privateAccess new sys.io.FileOutput(untyped __call__('fopen', 'php://output', "w")));
        res.body.pipeTo(out, { end: true }).handle(function (o) {
          cb(Shutdown);
        });
      })
    );
}
