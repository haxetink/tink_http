package ;

import haxe.io.Bytes;
import haxe.Json;
import tink.unit.*;
import tink.unit.Assert.*;
import tink.testrunner.*;
import tink.http.Fetch;
import tink.http.Fetch.fetch;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;

using haxe.Json;
using tink.CoreApi;

@:timeout(15000)
class FetchTest {
  
  var client:ClientType;
  
  public function new(?client:ClientType) {
    this.client = client;
  }
  
  public function get() return testStatus('http://httpbin.io/');
  public function post() return testData('http://httpbin.io/post', POST);
  public function delete() return testData('http://httpbin.io/delete', DELETE);
  public function patch() return testData('http://httpbin.io/patch', PATCH);
  public function put() return testData('http://httpbin.io/put', PUT);
  
  
  // TODO: re-enable when issue resolved: https://github.com/postmanlabs/httpbin/issues/617
  // #if !cpp // TODO: investigate
  // public function redirect() return testStatus('http://httpbin.io/redirect/5');
  // #end
  
  #if(!python && !cs && !interp && !lua)
  public function secureGet() return testStatus('https://httpbin.io/');
  public function securePost() return testData('https://httpbin.io/post', POST);
  public function secureDelete() return testData('https://httpbin.io/delete', DELETE);
  public function securePatch() return testData('https://httpbin.io/patch', PATCH);
  public function securePut() return testData('https://httpbin.io/put', PUT);
  
  // TODO: re-enable when issue resolved: https://github.com/postmanlabs/httpbin/issues/617
  // #if !cpp // TODO: investigate
  // public function secureRedirect() return testStatus('https://httpbin.io/redirect/5');
  // #end
  #end
  
  public function headers(buffer:AssertionBuffer) {
    var name = 'my-sample-header';
    var value = 'foobar';
    return fetch('http://httpbin.io/headers', {
      headers:[
        // {name: name, value: value},
        new HeaderField(name, value),
      ],
      client: client,
    }).all().next(
      function(res) {
          buffer.assert(res.header.statusCode == 200);
          buffer.assert(Type.enumEq(objectToHeader(res.body.toString().parse().headers).byName(name), Success(value)));
          return buffer.done();
      });
  }
  
  function testStatus(url:String, status = 200) {
    return fetch(url, {client: client}).all().next(function(res) {
      return assert(res.header.statusCode == status);
    });
  }
  
  function testData(url:String, method:Method) {
    var body = 'Hello, World!';
    return fetch(url, {
      method: method,
      headers:[
        // {name: 'content-type', value: 'text/plain'},
        // {name: 'content-length', value: Std.string(body.length)},
        new HeaderField('content-type', 'text/plain'),
        new HeaderField('content-length', Std.string(body.length)),
      ],
      body: body,
      client: client,
    }).all().next(function(res):Array<Assertion> {
      return [
        assert(res.header.statusCode == 200),
        assert(res.body.toString().parse().data == body),
      ];
    });
  }
  
  function objectToHeader(obj:Dynamic) {
    return new Header([for(key in Reflect.fields(obj))
      new HeaderField(key, Reflect.field(obj, key))]);
  }
  
}