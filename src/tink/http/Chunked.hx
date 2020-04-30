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
			.map(function(chunk:tink.Chunk) return '${chunk.length.hex()}\r\n' & chunk & '\r\n')
			.append([Chunk.ofString('0\r\n')].iterator());
	}
}

class ChunkedDecoder<Q> implements Transformer<Q, Error> {
	public function new() {}
	
	public function transform(source:Source<Q>):RealSource {
		return (
			(source:RealSource).parseStream(new ChunkedParser())
				.map(
					function(v) {
						return v == null ? Chunk.EMPTY : v;
					}
				)
			:Stream<Chunk, Error>
		);
	}
}

@:access(tink.chunk) class ChunkedParser implements StreamParserObject<Chunk> {
	
	static var LINEBREAK:Seekable = '\r\n';
	
	var chunkSize:Int;
	
	public function new() {
		reset();
	}
	
	function reset()
		chunkSize = -1;
	
	private function consume(cursor:ChunkCursor){
		cursor.moveTo(this.chunkSize);
		var res = cursor.left();
		// trace('pull: $res');
		cursor.moveBy(2);//remove crlf
		cursor.prune();
		reset();
		return res;
	}
	public function progress(cursor:ChunkCursor):ParseStep<Chunk> {
		//trace('cursor.length ${cursor.length} size: $chunkSize');
		return
			if(chunkSize < 0) {
				// trace('...');
				switch cursor.seek(LINEBREAK) {
					case Some(v): 
						// trace('peeking: $v');
						chunkSize = Std.parseInt('0x$v');
						// trace('pulling: $chunkSize from ${cursor.length}');
						if(cursor.length >= (chunkSize + 2) ){
							if(chunkSize == 0){
								switch(cursor.seek(LINEBREAK,{withoutPruning:true})){
									case Some( _.toString() => "") : Done(Chunk.EMPTY);	
									default 			: Progress;
								}
							}else{
								//trace('consume');
								Done(consume(cursor));
							}
						}
					case None: 
				}
				Progressed;
			} else if(chunkSize == 0) {
				if(cursor.length == 0){
					Done(Chunk.EMPTY);
				}else{
					Progressed;
				}
			} else {
				// trace('len = ${cursor.length} size = $chunkSize');
				if(cursor.length >= chunkSize + 2 ){
					Done(consume(cursor));
				}
				else Progressed;
			}
	}
	
	public function eof(rest:ChunkCursor):Outcome<Chunk, Error> {
		return chunkSize == 0 ? Success(Chunk.EMPTY) : Failure(new Error('Unexpected end of input'));
	}
}