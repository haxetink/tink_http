package;

/**
	Configurable httpbin base URLs for tests.
	Override with -D httpbin_url / -D httpbin_secure_url / -D httpbin_ca
	(defaults remain http(s)://httpbin.io).
**/
class HttpbinConfig {
	public static final url:String = {
		final v = Env.getDefine('httpbin_url');
		v == null ? 'http://httpbin.io' : v;
	};

	public static final secureUrl:String = {
		final v = Env.getDefine('httpbin_secure_url');
		v == null ? 'https://httpbin.io' : v;
	};

	/** Optional path to a PEM CA used to trust local https httpbin (mbedtls / sys.ssl). */
	public static final caPath:Null<String> = Env.getDefine('httpbin_ca');

	#if (sys && !php && !java && !jvm && !python && !cs && !lua)
	/** Install mkcert/local CA for sys.ssl.Socket on neko/cpp/hl/interp. */
	public static function bootstrapSslCa():Void {
		if (caPath == null) return;
		sys.ssl.Socket.DEFAULT_CA = sys.ssl.Certificate.loadFile(caPath);
		sys.ssl.Socket.DEFAULT_VERIFY_CERT = true;
	}
	#else
	public static function bootstrapSslCa():Void {}
	#end
}
