package tink.http.clients;

using tink.CoreApi;

class Helpers {
	public static function checkScheme(s:String) {
		return switch s {
			case null: Some(missingSchemeError());
			case 'http' | 'https': None;
			case v: Some(invalidSchemeError(v));
		}
	}
	public static inline function missingSchemeError() {
		return new Error(BadRequest, 'Missing Scheme (expected http/https)');
	}
	public static inline function invalidSchemeError(v) {
		return new Error(BadRequest, 'Invalid Scheme "$v" (expected http/https)');
	}
}