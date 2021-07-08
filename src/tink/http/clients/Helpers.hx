package tink.http.clients;

import tink.Url;

using tink.CoreApi;

class Helpers {
	public static function checkScheme(url:Url) {
		return switch url.scheme {
			case null: Some(missingSchemeError(url));
			case 'http' | 'https': None;
			case v: Some(invalidSchemeError(v));
		}
	}
	public static inline function missingSchemeError(url:Url) {
		return new Error(BadRequest, 'Missing Scheme (expected http/https) in URL: ${url.toString()}');
	}
	public static inline function invalidSchemeError(url:Url) {
		return new Error(BadRequest, 'Invalid Scheme "${url.scheme}" (expected http/https) in URL: ${url.toString()}');
	}
}