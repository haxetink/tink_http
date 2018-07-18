package tink.http.clients;

#if openfl
import openfl.net.*;
#else
import flash.net.*;
#end

// TODO: this is completely untested
class SecureFlashSocketClient extends FlashSocketClient {
  public function new() {
    super();
    secure = true;
  }
  
  override function getSocket():Socket
    #if openfl
      throw 'not implemented';
    #else
     return new SecureSocket();
    #end
}