package;

import tink.http.*;
import tink.http.Response;
import tink.http.Header;
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
    return asserts;
  }

  @:variant('3\r\n123\r\n0\r\n\r\n', '123')
  @:variant('3\r\n123\r\n3\r\n123\r\n3\r\n123\r\n0\r\n\r\n', '123123123')
  @:variant('3\r\n123\r\n4\r\nA\r\nB\r\n3\r\n123\r\n0\r\n\r\n', '123A\r\nB123')
  @:variant('A\r\n1234567890\r\n0\r\n\r\n', '1234567890')
  @:variant('3;foo=bar\r\n123\r\n0\r\n\r\n', '123') // chunk with extension
  @:variant('3;a;b=c\r\n123\r\n0;done\r\n\r\n', '123') // multiple extensions, incl. on last chunk
  public function decode(input:IdealSource, output:String) {
    Chunked.decode(input).all()
      .next(decoded -> asserts.assert(decoded.toString() == output))
      .handle(asserts.handle);
    return asserts;
  }

  #if (sys || nodejs)
  public function decodeLarge() {
    Chunked.decode(sys.io.File.getBytes('tests/chunked_data.bin')).all()
      .next(decoded -> asserts.assert(decoded.length == 245084))
      .handle(asserts.handle);
    return asserts;
  }
  #end

  public function factoryDefault() {
    var res = OutgoingResponse.chunked('text/plain', null, source);
    asserts.assert(res.header.statusCode == OK);
    asserts.assert(res.header.byName(TRANSFER_ENCODING).sure() == 'chunked');
    asserts.assert(!res.header.getContentLength().isSuccess());
    res.body.all()
      .next(body -> Chunked.encode(source).all().next(encoded -> asserts.assert(encoded.toString() == body.toString())))
      .handle(asserts.handle);
    return asserts;
  }

  public function factoryCustomStatus() {
    var res = OutgoingResponse.chunked(Created, 'text/plain', null, source);
    asserts.assert(res.header.statusCode == Created);
    asserts.assert(res.header.byName(TRANSFER_ENCODING).sure() == 'chunked');
    return asserts.done();
  }

  public function withChunkedEncodingPreservesBlob() {
    var res = OutgoingResponse.blob('123', 'text/plain');
    var out = res.withChunkedEncoding();
    asserts.assert(!out.header.byName(TRANSFER_ENCODING).isSuccess());
    asserts.assert(out.header.getContentLength().sure() == 3);
    res.body.all()
      .next(b1 -> out.body.all().next(b2 -> asserts.assert(b1.toString() == b2.toString())))
      .handle(asserts.handle);
    return asserts;
  }

  public function withChunkedEncodingApplies() {
    var res = new OutgoingResponse(
      new ResponseHeader(OK, OK, [new HeaderField('Content-Type', 'text/plain')]),
      source
    );
    var out = res.withChunkedEncoding();
    asserts.assert(out.header.byName(TRANSFER_ENCODING).sure() == 'chunked');
    out.body.all()
      .next(body -> asserts.assert(body.toString() == '3\r\n123\r\n0\r\n\r\n'))
      .handle(asserts.handle);
    return asserts;
  }

  public function withChunkedEncodingAlreadyChunked() {
    var res = new OutgoingResponse(
      new ResponseHeader(OK, OK, [
        new HeaderField('Content-Type', 'text/plain'),
        new HeaderField(TRANSFER_ENCODING, 'chunked'),
      ]),
      Chunked.encode(source)
    );
    var out = res.withChunkedEncoding();
    asserts.assert(out.header.byName(TRANSFER_ENCODING).sure() == 'chunked');
    out.body.all()
      .next(body -> asserts.assert(body.toString() == '3\r\n123\r\n0\r\n\r\n'))
      .handle(asserts.handle);
    return asserts;
  }

  public function withChunkedEncodingNoBody() {
    for(code in [204, 304, Continue]) {
      var res = new OutgoingResponse(new ResponseHeader(code, code, []), Source.EMPTY);
      var out = res.withChunkedEncoding();
      asserts.assert(!out.header.byName(TRANSFER_ENCODING).isSuccess());
    }
    return asserts.done();
  }
}