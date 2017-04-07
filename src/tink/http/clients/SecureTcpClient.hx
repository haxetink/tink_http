package tink.http.clients;

class SecureTcpClient extends TcpClient {
  public function new() {
    super();
    secure = true;
  }
}