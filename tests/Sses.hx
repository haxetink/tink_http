import tink.streams.Stream;
import tink.streams.IdealStream;
import tink.http.Sse;
import deepequal.DeepEqual;

@:asserts
class Sses {
  public function new() {}

  @:variant([{ data: '123', event: 'foobar', id: '123' }], 'id: 123\nevent: foobar\ndata: 123\n\n')
  @:variant([{ data: '123\n456' }], 'data: 123\ndata: 456\n\n')
  public function encode(input:Array<Sse>, output:String) {
    return SseStream.encode(Stream.ofIterator(input.iterator())).all().next(
      chunk -> asserts.assert(chunk.toString() == output)
    );
  }

  @:variant('id: 123\nevent: foobar\ndata: 123\n\n', [{ id: '123', event: 'foobar', data: '123', retry: null }])
  @:variant('data: 123\n: foo\ndata: 456\n\n:bar\n\ndata: 789\n\n', [{ data: '123\n456', event: 'message', retry: null, id: null }, { data: '789', event: 'message', retry: null, id: null }])
  public function decode(input:String, output:Array<Sse>) {
    return SseStream.decode(input).collect().next(
      events -> asserts.assert(DeepEqual.compare(events, output))
    );
  }
}