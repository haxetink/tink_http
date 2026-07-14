package;

import tink.http.*;
import tink.http.Response;
import tink.http.Header;
import tink.http.clients.Helpers;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestResponseFraming {
	public function new() {}

	// HEAD must yield an empty body even when Content-Length claims otherwise (RFC 9112 §6.3)
	public function headIgnoresContentLength() {
		var header = new ResponseHeader(OK, OK, [new HeaderField('Content-Length', '5')]);
		var source:RealSource = 'helloEXTRA';
		Helpers.frameResponseBody(HEAD, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == ''))
			.handle(asserts.handle);
		return asserts;
	}

	// HEAD must not attempt chunked decoding
	public function headIgnoresTransferEncoding() {
		var header = new ResponseHeader(OK, OK, [new HeaderField(TRANSFER_ENCODING, 'chunked')]);
		var source:RealSource = '5\r\nhello\r\n0\r\n\r\n';
		Helpers.frameResponseBody(HEAD, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == ''))
			.handle(asserts.handle);
		return asserts;
	}

	@:variant(204)
	@:variant(304)
	@:variant(100)
	@:variant(101)
	public function noBodyStatuses(code:Int) {
		var header = new ResponseHeader(code, code, [new HeaderField('Content-Length', '5')]);
		var source:RealSource = 'helloEXTRA';
		Helpers.frameResponseBody(GET, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == ''))
			.handle(asserts.handle);
		return asserts;
	}

	public function contentLengthLimitsBody() {
		var header = new ResponseHeader(OK, OK, [new HeaderField('Content-Length', '5')]);
		var source:RealSource = 'helloEXTRA';
		Helpers.frameResponseBody(GET, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == 'hello'))
			.handle(asserts.handle);
		return asserts;
	}

	// chunked Transfer-Encoding takes precedence; match is case-insensitive
	public function prefersChunkedTransferEncoding() {
		var header = new ResponseHeader(OK, OK, [
			new HeaderField('Content-Length', '999'),
			new HeaderField(TRANSFER_ENCODING, 'Chunked'),
		]);
		var source:RealSource = '5\r\nhello\r\n0\r\n\r\n';
		Helpers.frameResponseBody(GET, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == 'hello'))
			.handle(asserts.handle);
		return asserts;
	}

	public function chunkedInCommaSeparatedList() {
		var header = new ResponseHeader(OK, OK, [
			new HeaderField(TRANSFER_ENCODING, 'gzip, chunked'),
		]);
		var source:RealSource = '5\r\nhello\r\n0\r\n\r\n';
		Helpers.frameResponseBody(GET, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == 'hello'))
			.handle(asserts.handle);
		return asserts;
	}

	// without CL or TE, the remainder of the source is the body (connection close)
	public function readsUntilClose() {
		var header = new ResponseHeader(OK, OK, []);
		var source:RealSource = 'until-close';
		Helpers.frameResponseBody(GET, header, source).all()
			.next(chunk -> asserts.assert(chunk.toString() == 'until-close'))
			.handle(asserts.handle);
		return asserts;
	}
}
