package tink.http.clients;

class SecureCurlClient extends CurlClient {
  public function new(?curl) {
    super(curl);
    protocol = 'https';
  }
}
