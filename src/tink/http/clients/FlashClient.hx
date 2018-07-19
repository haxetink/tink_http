package tink.http.clients;

#if openfl
import openfl.net.*;
import openfl.events.*;
import openfl.utils.ByteArray;
#else
import flash.net.*;
import flash.events.*;
import flash.utils.ByteArray;
#end
import haxe.io.Bytes;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.streams.Stream;
import tink.Chunk;

using StringTools;
using tink.io.Source;
using tink.CoreApi;

class FlashClient implements ClientObject {
  
  var secure = false;
  
  public function new() {}
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    
    return Future.async(function(cb) {
      var loader = new URLLoader();
      loader.dataFormat = URLLoaderDataFormat.BINARY;
      
      var request = new URLRequest(req.header.url);
      request.method = req.header.method;
      request.requestHeaders = [for(h in req.header) new URLRequestHeader(h.name, h.value)];
      
      var header:ResponseHeader;
      
      function onHttpStatusEvent(e:HTTPStatusEvent) {
        inline function trim(s:String) {
          var len = s.length;
          return
            if(s.charCodeAt(len - 2) == '\r'.code && s.charCodeAt(len - 1) == '\n'.code)
              s.substr(0, len - 2);
            else
              s;
        }
        header = new ResponseHeader(
          e.status, e.status,
          [for(h in e.responseHeaders) new HeaderField(h.name, trim(h.value))]
        );
      }
      
      function onError(e:TextEvent) {
        cb(Failure(new Error(e.text)));
      }
      
      loader.addEventListener(Event.COMPLETE, function(e) {
        var bytes:Bytes = (e.target.data:ByteArray);
        if(header == null) cb(Failure(new Error('Response header not ready, please check the implementation of ' + Type.getClassName(Type.getClass(this)))));
        else cb(Success(new IncomingResponse(header, bytes)));
      });
      loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatusEvent);
      // loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onHttpStatusEvent); // TODO: enable on AIR only
      loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
      loader.addEventListener(IOErrorEvent.IO_ERROR, onError);
      // loader.addEventListener(Event.OPEN, openHandler);
      // loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
      
      req.body.all().handle(function(chunk) {
        request.data = ByteArray.fromBytes(chunk);
        loader.load(request);
      });
    });
  }
}