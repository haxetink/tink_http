package tink.http.containers;

import haxe.crypto.Base64;
import haxe.DynamicAccess;
import tink.http.Method;
import tink.http.Container;
import tink.http.Request;
import tink.http.Header;

using tink.io.Source;
using tink.CoreApi;

/**
 *  Setup: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-set-up-simple-proxy.html#api-gateway-simple-proxy-for-lambda-output-format
 *  
 *  Usage:
 *  ```
 *  class Server {
 *    @:expose('handler')
 *    static function handler(event, context, callback) {
 *      var container = new AwsLambdaNodeContainer(event, context, callback);
 *      container.run(function(req) return Future.sync(('Done':OutgoingResponse))).eager();
 *    }
 *  }
 *  ```
 */
class AwsLambdaNodeContainer implements Container {
  
  var event:LambdaEvent;
  var context:Dynamic;
  var callback:js.Error->LambdaResponse->Void;
  
  public function new(event, context, callback) {
    this.event = event;
    this.context = context;
    this.callback = callback;
  }
  
  inline function getRequest():IncomingRequest {
    return new IncomingRequest(
      event.requestContext.sourceIp,
      new IncomingRequestHeader(
        event.httpMethod,
        event.path + (event.queryStringParameters == null ? '' : '?' + [for(key in event.queryStringParameters.keys()) '$key=' + event.queryStringParameters.get(key)].join('&')),
        HTTP1_1,
        [for(key in event.headers.keys()) new HeaderField(key, event.headers.get(key))]
      ),
      Plain(
        if(event.body == null)
          Source.EMPTY
        else if(event.isBase64Encoded)
          Base64.decode(event.body)
        else
          event.body
      )
    );
  }
  
  public function run(handler:Handler) 
    return Future.async(function (cb) {
      handler.process(getRequest()).handle(function(res) {
        res.body.all().handle(function(chunk) {
          callback(null, {
            statusCode: res.header.statusCode,
            headers: {
              var headers = new DynamicAccess();
              for(h in res.header) headers.set(h.name, h.value);
              headers;
            },
            body: chunk.toString(), // TODO: need to distinguish binary/plain-text body?
            isBase64Encoded: false,
          });
          cb(Shutdown);
        });
      });
    });
}


private typedef LambdaEvent = {
  httpMethod:Method,
  path:String,
  queryStringParameters:DynamicAccess<String>,
  headers:DynamicAccess<String>,
  body:String,
  isBase64Encoded:Bool,
  requestContext: {
    sourceIp:String,
  },
}

private typedef LambdaResponse = {
  statusCode:Int,
  headers:DynamicAccess<String>,
  body:String,
  isBase64Encoded:Bool,
}