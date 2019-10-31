package tink.http.clients;

class SecureFlashClient extends FlashClient {
	public function new() {
		super();
		secure = true;
	}
}