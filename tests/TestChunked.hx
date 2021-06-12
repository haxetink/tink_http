package;

import tink.http.*;
import tink.Chunk;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestChunked {
	final source:IdealSource = '123';
	
	public function new() {}
	
	@:variant(this.source, '3\r\n123\r\n0\r\n\r\n')
	@:variant(this.source.append(this.source).append(this.source), '3\r\n123\r\n3\r\n123\r\n3\r\n123\r\n0\r\n\r\n')
	@:variant('1234567890', 'A\r\n1234567890\r\n0\r\n\r\n')
	public function encode(input:IdealSource, output:String) {
		Chunked.encode(input).all()
			.next(encoded -> asserts.assert(encoded.toString() == output))
			.handle(asserts.handle);
		return asserts.done();
	}
	
	@:variant('3\r\n123\r\n0\r\n\r\n', '123')
	@:variant('3\r\n123\r\n3\r\n123\r\n3\r\n123\r\n0\r\n\r\n', '123123123')
	@:variant('A\r\n1234567890\r\n0\r\n\r\n', '1234567890')
	public function decode(input:IdealSource, output:String) {
		Chunked.decode(input).all()
			.next(decoded -> asserts.assert(decoded.toString() == output))
			.handle(asserts.handle);
		return asserts.done();
	}
	
	#if (sys || nodejs)
	public function decodeLarge() {
		Chunked.decode(sys.io.File.getBytes('tests/chunked_data.bin')).all()
			.next(decoded -> asserts.assert(decoded.length == 245084))
			.handle(asserts.handle);
		return asserts.done();
	}
	#end
	
	
}