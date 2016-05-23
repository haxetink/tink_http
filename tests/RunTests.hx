package;

import tink.http.Container;
import tink.http.Client;
import tink.http.Multipart;
import tink.http.containers.*;

class RunTests {

  static function main() {
    DummyServer.handleRequest;
    #if interp
    
    #elseif php
    untyped __call__('exec', 'haxe build-php.hxml');
    //Sys.command('haxe', ['build-php.hxml']);
    #elseif (neko || java || cpp)
    var c = new TcpClient();
    var s = new TcpContainer(2000);
    #elseif nodejs
    var c = new NodeClient();
    var s = new NodeContainer(2000);
    #end
  }
  
}