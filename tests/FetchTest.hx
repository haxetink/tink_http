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
  
  public function testGet() return testStatus('http://httpbin.org/');
  public function testPost() return testData('http://httpbin.org/post', POST);
  public function testDelete() return testData('http://httpbin.org/delete', DELETE);
  public function testPatch() return testData('http://httpbin.org/patch', PATCH);
  public function testPut() return testData('http://httpbin.org/put', PUT);
  public function testRedirect() return testStatus('http://httpbin.org/redirect/5');
  
  #if(!python && !cs && !interp)
  public function testSecureGet() return testStatus('https://httpbin.org/');
  public function testSecurePost() return testData('https://httpbin.org/post', POST);
  public function testSecureDelete() return testData('https://httpbin.org/delete', DELETE);
  public function testSecurePatch() return testData('https://httpbin.org/patch', PATCH);
  public function testSecurePut() return testData('https://httpbin.org/put', PUT);
  public function testSecureRedirect() return testStatus('https://httpbin.org/redirect/5');
  
  public function testHeaders(buffer:AssertionBuffer) {
    var name = 'my-sample-header';
    var value = 'foobar';
    return fetch('https://httpbin.org/headers', {
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
  #end
  
  function testStatus(url:String, status = 200) {
    return fetch(url, {client: client}).next(function(res) {
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
    return new Header([for(key in Reflect.fields(obj)) new HeaderField(key, Reflect.field(obj, key))]);
  }
  
}