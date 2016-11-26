package suites;

import tink.http.Method;
import TestSuite.Target;
import tink.http.Multipart;

using buddy.Should;

class TestBody extends TestSuite {
  
  static var utf8 = "काचं शक्नोम्यत्तुम् । नोपहिनस्ति माम् ॥";
  static var boundary = '----tink_http';
  static var multipart = [
    '--'+boundary,
    'Content-Disposition: form-data; name="a"',
    '',
    'b',
    '--'+boundary,
    'Content-Disposition: form-data; name="c"',
    '',
    'd',
    '--'+boundary+'--'
  ].join('\n');

  public function new() {
    function test(target: Target) {
      
      function request(data: ClientRequest)
        return target.client.request(data).flatMap(response);
      
      describe('client ${target.name}', {
        
        it('server should return body', function(done)
          request({url: '/', method: POST, body: 'hello'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.body.content.should.be('hello');
            done();
          })
        );
        
        it('server should return utf-8 body', function(done)
          request({url: '/', method: POST, body: utf8}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.body.content.should.be(utf8);
            done();
          })
        );
        
        it('server should return application/x-www-form-urlencoded body', function(done)
          request({
            url: '/', method: POST, 
            headers: [
              'content-type' => 'application/x-www-form-urlencoded'
            ],
            body: 'a=123&b='+utf8
          }).handle(function(res) {
            res.data.should.not.be(null);
            res.data.body.content.should.be('a=123&b='+utf8);
            done();
          })
        );
        
        it('server should return multipart/form-data body', function(done)
          request({
            url: '/', method: POST, 
            headers: [
              'content-type' => 'multipart/form-data; boundary='+boundary
            ],
            body: multipart
          }).handle(function(res) {
            res.data.should.not.be(null);
            switch res.data.body.type {
              case 'plain':
                res.data.body.content.should.be(multipart);
              case 'parsed':
                var expected = [
                  {name: 'a', value: 'b'},
                  {name: 'c', value: 'd'}
                ];
                switch deepequal.DeepEqual.compare(expected, res.data.body.parts) {
                  case Failure(f): fail(f.message);
                  default:
                }
              default: return fail();
            }
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