package tink.http.containers;

import haxe.crypto.Base64;
import haxe.DynamicAccess;
import tink.http.Method;
import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import #if haxe4 js.lib.Error #else js.Error #end as JsError;

using tink.io.Source;
using tink.CoreApi;

/**
 *  Setup: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-set-up-simple-proxy.html#api-gateway-simple-proxy-for-lambda-output-format
 *  
 *  TL;DR; Create API gateway with:
 *    - Method: ANY
 *    - Resourcep path; /{proxy+}
 *    - Integration type: lambda function
 *    - Use Lambda Proxy integration: checked
 *  
 *  Usage:
 *  ```
 *  class Server {
 *    static function main() {
 *      // handler function will be exposed as the name specified
 *      // note that the container must be created synchronously in the main function
 *      var container = new AwsLambdaNodeContainer('index'); 
 *      container.run(function(req) return Future.sync(('Done':OutgoingResponse))).eager();
 *    }
 *  }
 *  ```
 */
class AwsLambdaNodeContainer implements Container {
  
  var name:String;
  var isBinary:ResponseHeader->Bool;
  
  public function new(name:String, ?isBinary) {
    this.name = name;
    this.isBinary = isBinary == null ? function(_) return false : isBinary;
  }
  
  inline function getRequest(event:LambdaEvent):IncomingRequest {
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
      Reflect.setField(
        js.Node.exports,
        name,
        function(event:LambdaEvent, context:Dynamic, callback:JsError->LambdaResponse->Void) {
          context.callbackWaitsForEmptyEventLoop = false;
          handler.process(getRequest(event)).handle(function(res) {
            var binary = isBinary(res.header);
            res.body.all().handle(function(chunk) {
              var res:LambdaResponse = {
                statusCode: res.header.statusCode,
                headers: {
                  var headers = new DynamicAccess();
                  for(h in res.header) headers.set(h.name, h.value);
                  headers;
                },
                isBase64Encoded: binary,
                body: binary ? Base64.encode(chunk) : chunk.toString(),
              };
              callback(null, res);
              cb(Shutdown);
            });
          });
        }
      );
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