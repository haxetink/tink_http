package;

import sys.io.Process;
import tink.core.Future;
import tink.core.Noise;
import tink.http.Container;
import tink.http.Client;
import tink.http.Multipart;
import tink.http.Request;
import tink.http.containers.*;
import tink.url.Host;

class RunTests {
  
  static function performTest(host:Host, clients:Array<Client>):Future<Noise> {
    var ret = Future.ofMany([
      for (c in clients)
        c.request(new OutgoingRequest(
          new OutgoingRequestHeader(GET, host, '/'),
          ''
        )).flatMap(function (res) return res.body.all())
    ]);
    ret.handle(function (x) {
      trace('$host: '+Std.string(x));
    });
    ret = Future.async(function (cb) { } );
    return ret.map(function (_) return Noise);
  }
  
  static function onContainer(c:Container, f:Void->Future<Noise>) 
    return Future.async(function (cb) {
      c.run(DummyServer.handleRequest).handle(function (r) switch r {
        case Running(server):
          trace('server running');
          f().handle(function () server.shutdown(true).handle(function () cb(Noise)));
        case v: 
          throw 'unexpected $v';
      });
    });
  
  static function onServer(f:Host->Future<Noise>) {
    var ret = [];
    #if php
    untyped __call__('exec', 'haxe build-php.hxml');
    var server = new Process('php', ['-S', 'localhost:8000', 'testphp/index.php']);
    var done = f(new Host('localhost', 8000));
    ret.push(done);
    done.handle(function () {
      server.kill();
    });
    #end 
    #if (neko || java || cpp || nodejs)
    ret.push(onContainer(new TcpContainer(2000), f.bind(new Host('localhost', 2000))));
    #end
    
    #if nodejs
    //ret.push(onContainer(new NodeContainer(3000), f.bind(new Host('localhost', 3000))));
    #end
    return Future.ofMany(ret);
  }
  static function getClients() {
    var clients:Array<Client> = [];
    //clients.push(new StdClient());
    #if (neko || java || cpp || nodejs)
      clients.push(new TcpClient());
    #end
    
    #if nodejs
      //clients.push(new NodeClient());
    #end
    return clients;
  }
  static function main() {
    onServer(performTest.bind(_, getClients()));
  }
  
}