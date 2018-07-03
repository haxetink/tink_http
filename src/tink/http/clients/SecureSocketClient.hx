package tink.http.clients;

class SecureSocketClient extends SocketClient {
  public function new(?worker) {
    super(worker);
    secure = true;
  }
}