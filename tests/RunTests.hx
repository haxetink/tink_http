package;

import haxe.PosInfos;
import sys.io.Process;
import tink.core.Future;
import tink.core.Noise;
import tink.http.Container;
import tink.http.Client;
import tink.http.Method;
import tink.http.Multipart;
import tink.http.Request;
import tink.http.containers.*;
import tink.io.IdealSource;
import tink.url.Host;
import DummyServer;

using tink.CoreApi;

class RunTests {
  static function assertEquals<A>(expected:A, found:A, ?pos) 
    if (expected != found)
      throw Error.withData('expected $expected but found $found', [expected, found], pos);
  
  static function performTest(host:Host, clients:Array<Client>):Future<Noise> {    
    var ret = [];
    
    for (c in clients) {
      function roundtrip(method:Method, uri:String = '/', ?fields, body:String = '') {
        ret.push(Future.async(function (cb) {
          if (fields == null)
            fields = [];
          var req = new OutgoingRequest(new OutgoingRequestHeader(method, host, uri, fields), body);
          
          c.request(req).handle(function (res) {
            res.body.all().handle(function (o) {
              var raw = o.sure().toString();
              var data:Data = haxe.Json.parse(raw);
              assertEquals((method:String), data.method);
              assertEquals(uri, data.uri);
              assertEquals(body, data.body);
              cb(Noise);
            });
          });
        }));
      }
        
      roundtrip(GET);
      roundtrip(POST, '/', 'hello there!');
    }
    
    return Future.ofMany(ret).map(function (_) return Noise);
  }
  
  static function onContainer(c:Container, f:Void->Future<Noise>) 
    return Future.async(function (cb) {
      c.run(DummyServer.handleRequest).handle(function (r) switch r {
        case Running(server):
          f().handle(function () server.shutdown(true).handle(function () cb(Noise)));
        case v: 
          throw 'unexpected $v';
      });
    });
  
  static function onServer(f:Host->Future<Noise>) {
    var ret = [];
    #if php
    untyped __call__('exec', 'haxe build-php.hxml');
    var server = new Process('php', ['-S', '127.0.0.1:8000', 'testphp/index.php']);
    ret.push(Future.async(function (cb) { } ));
    var done = f(new Host('localhost', 8000));
    ret.push(done);
    done.handle(function () {
      server.kill();
    });
    #end 
    #if (neko || java || cpp)
    ret.push(onContainer(new TcpContainer(2000), f.bind(new Host('localhost', 2000))));
    #end
    
    #if nodejs
    ret.push(onContainer(new NodeContainer(3000), f.bind(new Host('localhost', 3000))));
    #end
    return Future.ofMany(ret);
  }
  static function getClients() {
    var clients:Array<Client> = [];
    
    #if php
      clients.push(new StdClient());
    #end
    
    #if (neko || java || cpp)
      clients.push(new TcpClient());
    #end
    
    #if nodejs
      clients.push(new NodeClient());
    #end
    return clients;
  }
  static function main() {
    onServer(performTest.bind(_, getClients())).handle(function () {
      Sys.exit(0);//Just in case
    });
  }
  
}