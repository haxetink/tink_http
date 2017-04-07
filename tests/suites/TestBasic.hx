package suites;

import tink.http.Method;
import TestSuite.Target;

using buddy.Should;

class TestBasic extends TestSuite {

  public function new() {
    function test(target: Target) {
      
      function request(data: ClientRequest)
        return target.client.request(data).flatMap(response);
      
      describe('client ${target.name}', {
        
        it('server should set the http method', function(done)
          request({url: '/'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.method.should.be(Method.GET);
            done();
          })
        );
        
        it('server should set the ip', function(done)
          request({url: '/'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.ip.should.endWith('127.0.0.1');
            done();
          })
        );
        
        it('server should set the url', function(done)
          request({url: '/uri/path?query=a&param=b'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.uri.should.be('/uri/path?query=a&param=b');
            done();
          })
        );
        
        it('server should set headers', function(done)
          request({
            url: '/uri/path?query=a&param=b', 
            headers: [
              'x-header-a' => 'a',
              'x-header-b' => '123'
            ]
          }).handle(function(res) {
            res.data.should.not.be(null);
            var headers = res.data.headers.map(function (pair)
              return '${pair.name}: ${pair.value}'
            );
            headers.should.contain('x-header-a: a');
            headers.should.contain('x-header-b: 123');
            done();
          })
        );
      
      });
    }
    
    describe('tink_http',
      for (target in clients) test(target)
    );
  }
    
}