package tink.http;

import tink.streams.Stream;
import tink.io.StreamParser;
import tink.io.Transformer;
import tink.Chunk;
import tink.chunk.*;

using StringTools;
using tink.CoreApi;
using tink.io.Source;

class Chunked {
	static var _encoder:ChunkedEncoder<Dynamic>;
	static var _decoder:ChunkedDecoder<Dynamic>;
	
	public static function encoder<Q>():ChunkedEncoder<Q> {
		if(_encoder == null) _encoder = new ChunkedEncoder();
		return cast _encoder;
	}
	
	public static function decoder<Q>():ChunkedDecoder<Q> {
		if(_decoder == null) _decoder = new ChunkedDecoder();
		return cast _decoder;
	}
	
	public static inline function encode<Q>(source:Source<Q>):Source<Q>
		return encoder().transform(source);
		
	public static inline function decode<Q>(source:Source<Q>):RealSource
		return decoder().transform(source);
}

class ChunkedEncoder<Q> implements Transformer<Q, Q> {
	public function new() {}
	
	public function transform(source:Source<Q>):Source<Q> {
		return source.chunked()
			.map((chunk:Chunk) -> '${chunk.length.hex()}\r\n' & chunk & '\r\n')
			.append(Stream.single(Chunk.ofString('0\r\n\r\n')));
	}
}

class ChunkedDecoder<Q> implements Transformer<Q, Error> {
	public function new() {}
	
	public function transform(source:Source<Q>):RealSource {
		return (
			(source:RealSource).parseStream(new ChunkedParser())
				.map(v -> v != null /* TODO: figure out where does these nulls come from */ ? v : Chunk.EMPTY)
			:Stream<Chunk, Error>
		);
	}
}

class ChunkedParser implements StreamParserObject<Chunk> {
	
	static final LINEBREAK:Seekable = '\r\n';
	var lastChunkSize:Int = -1;
	var chunkSize:Int;
	var remaining:Int;
	
	public function new() {
		reset();
	}
	
	function reset() {
		lastChunkSize = chunkSize;
		chunkSize = -1;
	}
	
	public function progress(cursor:ChunkCursor):ParseStep<Chunk> {
		return
			if(chunkSize < 0) {
				switch cursor.seek(LINEBREAK) {
					case Some(v): remaining = chunkSize = Std.parseInt('0x$v');
					case None: // do nothing
				}
				Progressed;
			} else {
				final length = min(cursor.length, remaining);
				final data = cursor.sweep(length);
				remaining -= length;
				if(remaining == 0) {
					if(cursor.currentByte == '\r'.code && cursor.next() && cursor.currentByte == '\n'.code) {
						cursor.next();
						reset();
						Done(data);
					} else {
						Failed(new Error('Invalid encoding, expected line break'));
					}
				} else {
					Done(data);
				}
			}
	}
	
	public function eof(rest:ChunkCursor):Outcome<Chunk, Error> {
		return chunkSize == -1 && lastChunkSize == 0 ? Success(Chunk.EMPTY) : Failure(new Error('Unexpected end of input'));
	}
	
	inline static function min(a:Int, b:Int):Int {
		return a > b ? b : a;
	}
}