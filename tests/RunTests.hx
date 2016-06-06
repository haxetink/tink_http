package;

import haxe.PosInfos;
import haxe.io.StringInput;
import sys.io.Process;
import tink.core.Future;
import tink.core.Noise;
import tink.http.Container;
import tink.http.Client;
import tink.http.Header.HeaderField;
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
      function roundtrip(method:Method, uri:String = '/', ?fields:Array<HeaderField>, body:String = '') {
        ret.push(Future.async(function (cb) {
          
          fields = switch fields {
            case null: [];
            case v: v.copy();
          }
          
          var req = new OutgoingRequest(new OutgoingRequestHeader(method, host, uri, fields), body);
          switch body.length {
            case 0:
            case v: 
              switch req.header.get('content-length') {
                case []:
                  fields.push(new HeaderField('content-length', Std.string(v)));
                default:
              }
          }
          c.request(req).handle(function (res) {
            res.body.all().handle(function (o) {
              var raw = o.sure().toString();
              trace(raw);
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
      roundtrip(GET, '/?foo=bar&foo=2');
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
    if (new Process('haxe', ['build-php.hxml']).exitCode() != 0)
      throw 'failed to build PHP';
    var server = new Process('php', ['-S', '127.0.0.1:8000', 'testphp/index.php']);
    var i = 0;
    while (i < 20) {
      try {
        var socket = new sys.net.Socket();
        socket.connect(new sys.net.Host('127.0.0.1'), 8000);
        socket.close();
        break;
      } catch(e: Dynamic) {
        Sys.sleep(.1);
        i++;
        continue;
      }
    }
    var done = f(new Host('127.0.0.1', 8000));
    var h = new haxe.Http('http://127.0.0.1:8000/multipart');
    var s = 'hello world';
    
    h.fileTransfer('test', 'test.txt', new StringInput(s), s.length, "text/plain");
    h.setParameter('foo', 'bar');
    h.onError = function (error) throw error;
    h.onData = function (data) {
      var data:Data = haxe.Json.parse(data);
      var a:Array<{ name:String }> = haxe.Json.parse(data.body);
      var map = [for (x in a) x.name => true];
      assertEquals(map['test'], true);
      assertEquals(map['foo'], true);
    };
    
    h.request(true);
    
    ret.push(done);
    done.handle(function () {
      server.kill();
    });
    #end 

    #if neko
    //TODO: test actual mod_neko too
    Sys.command('haxe', ['build-neko.hxml']);
    var cwd = Sys.getCwd();
    Sys.setCwd('testneko');
    var server = new Process('nekotools', ['server', '-p', '8000', '-rewrite']);
    Sys.setCwd(cwd);
    
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