package tink.http.containers;

#if haxe4
import php.SuperGlobal;
import php.Global;
import php.Syntax;
#end

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
   return #if haxe4
       Syntax.code("$_SERVER[{0}]", key);
       #else
       untyped __php__("$_SERVER[{0}]", key);
       #end
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
        if ( #if haxe4  php.Global.function_exists('getallheaders') #else untyped __call__('function_exists', 'getallheaders') #end){
       
        var raw =  php.Lib.hashOfAssociativeArray( #if haxe4 php.Global.getallheaders() #else untyped __call__('getallheaders') #end );
        
          [for (name in raw.keys()) new HeaderField(name, raw[name])];
        } else {
          
          var h = php.Lib.hashOfAssociativeArray(#if haxe4 SuperGlobal._SERVER #else untyped __php__("$_SERVER") #end);
          
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
          Parsed(  getParts( #if haxe4   SuperGlobal._POST #else untyped __php__("$_POST") #end, Value)
            .concat(getParts(#if haxe4 SuperGlobal._FILES #else untyped __php__("$_FILES") #end, function (v:NativeArray) {
              
            
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
                        
                        if ( #if haxe4 untyped Global.rename(tmpName, path) #else untyped __call__('rename', tmpName, path) #end)
                        
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
        
          Plain( (#if haxe4 Global.file_get_contents( #else untyped __call__('file_get_contents',#end 'php://input') : String) );
          
          
      }
    );
  }
  
  public function run(handler:Handler):Future<ContainerResult> 
    return Future.async(function (cb) 
      handler.process(
        getRequest()
      ).handle(function (res) {
        #if haxe4
        Syntax.code('http_response_code({0})',res.header.statusCode);
        #else
        untyped __call__('http_response_code', res.header.statusCode);
        #end
        for (h in res.header)
        #if haxe4
          Global.header(h.name + ': ' + h.value);
         #else
          untyped __call__('header', h.name + ': ' + h.value);
          #end
        var out = Sink.ofOutput('output buffer', @:privateAccess new sys.io.FileOutput( #if haxe4 php.Global.fopen( #else untyped __call__('fopen',  #end'php://output', "w") ));
       
        res.body.pipeTo(out, { end: true }).handle(function (o) {
          cb(Shutdown);
        });
      })
    );
}
