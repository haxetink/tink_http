package tink.http.clients;

import tink.Url;
import tink.http.Chunked;
import tink.http.Header;
import tink.http.Method;
import tink.http.Request;
import tink.http.Response;

using tink.io.Source;
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

	/**
	 * For socket clients that do not reuse connections yet:
	 * ensure `Connection: close` and inject `Host` when missing.
	 */
	public static function addSocketHeaders(req:OutgoingRequest):Outcome<OutgoingRequest, Error> {
		function addHeaders(headers:Array<HeaderField>)
			req = new OutgoingRequest(req.header.concat(headers), req.body);

		switch req.header.byName('connection') {
			case Success((_:String).toLowerCase() => 'close'):
				// ok
			case Success(v):
				return Failure(new Error('Only "Connection: Close" is supported. But specified as "$v"'));
			case Failure(_):
				addHeaders([new HeaderField('connection', 'close')]);
		}

		switch req.header.byName('host') {
			case Success(_): // ok
			case Failure(_):
				final url = req.header.url;
				final defaultPort = url.scheme == 'https' ? 443 : 80;
				final host = switch url.host.port {
					case null: url.host.name;
					case p if(p == defaultPort): url.host.name;
					case p: '${url.host.name}:$p';
				}
				addHeaders([new HeaderField('host', host)]);
		}

		return Success(req);
	}

	/**
	 * Frame a raw HTTP/1.1 response body per RFC 9112 §6.3.
	 *
	 * 1. HEAD → empty body (ignore Content-Length / Transfer-Encoding for body bytes)
	 * 2. 1xx, 204, 304 → empty body
	 * 3. Transfer-Encoding contains `chunked` → Chunked.decode
	 * 4. Content-Length present → limit(len)
	 * 5. else → read until connection closes
	 */
	public static function frameResponseBody(method:Method, header:ResponseHeader, body:RealSource):RealSource {
		if(method == HEAD)
			return Source.EMPTY;

		final code = header.statusCode.toInt();
		if((code >= 100 && code <= 199) || code == 204 || code == 304)
			return Source.EMPTY;

		return switch header.byName(TRANSFER_ENCODING) {
			case Success((_:String).toLowerCase().split(',').map(StringTools.trim) => encodings) if(encodings.indexOf('chunked') != -1):
				Chunked.decode(body);
			case _:
				switch header.getContentLength() {
					case Success(len): body.limit(len);
					case Failure(_): body; // no framing info: read until the connection closes
				}
		}
	}
}
