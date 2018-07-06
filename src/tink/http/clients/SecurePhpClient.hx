package tink.http.clients;

class SecurePhpClient extends PhpClient {
  public function new() {
    super();
    protocol = 'https';
  }
}