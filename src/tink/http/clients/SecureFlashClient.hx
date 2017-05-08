package tink.http.clients;

import flash.net.*;

// TODO: this is completely untested
class SecureFlashClient extends FlashClient {
  public function new() {
    super();
    secure = true;
  }
  
  override function getSocket()
    return new SecureSocket();
}