package;

import tink.http.*;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestChunked {
	public function new() {}
	
	public function encode() {
		var source:IdealSource = '123';
		var encoded = Chunked.encode(source);
		encoded.all().handle(function(c) asserts.assert(c.toString() == '3\r\n123\r\n0\r\n'));
		source = source.append(source).append(source);
		var encoded = Chunked.encode(source);
		encoded.all().handle(function(c) asserts.assert(c.toString() == '3\r\n123\r\n3\r\n123\r\n3\r\n123\r\n0\r\n'));
		var source:IdealSource = '1234567890';
		var encoded = Chunked.encode(source);
		encoded.all().handle(function(c) asserts.assert(c.toString() == 'A\r\n1234567890\r\n0\r\n'));
		return asserts.done();
	}
	
	public function decode() {
		var source:IdealSource = '3\r\n123\r\n0\r\n';
		var decoded = Chunked.decode(source);
		decoded.all().handle(
			function(c) {
				var s = c.sure().toString();
				asserts.assert(c.sure().toString() == '123');
			}
		);
		var source:IdealSource = '3\r\n123\r\n3\r\n123\r\n3\r\n123\r\n0\r\n';
		var decoded = Chunked.decode(source);
		decoded.all().handle(function(c) asserts.assert(c.sure().toString() == '123123123'));
		var source:IdealSource = 'A\r\n1234567890\r\n0\r\n';
		var decoded = Chunked.decode(source);
		decoded.all().handle(function(c) asserts.assert(c.sure().toString() == '1234567890'));
		return asserts.done();
	}
}