package tink.http.containers;

import tink.streams.Stream;
import tink.http.Container;
import tink.http.Request;
import tink.http.Response;

using tink.io.Source;
using tink.CoreApi;

class Chunked {
  static public function encode(s:IdealSource):IdealSource 
    return s.chunked().map(function (c:Chunk) return '${StringTools.hex(c.length)}\r\n' & c & '\r\n');

  static public function decode(s:RealSource):Split<Error> {
    return new Split(s, null);
  }

}

// enum SplitResult<T> {
//   Continue(consume:Chunk);
//   Done(consume:Chunk, next:T);
// }

// typedef Step<T> = ChunkCursor->SplitResult<T>;

// typedef ReadingFirst = Step<ReadingSecond>;
// typedef ReadingSecond = Step<ReadingThird>;
// typedef ReadingThird = Step<Noise>;

class Split<E> {
  
  var cursor = Chunk.EMPTY.cursor();

  public var first(default, null):Stream<Chunk, E>;
  public var second(default, null):Stream<Chunk, E>;
  
  public function new(source:Stream<Chunk, E>, sep) {

    // source.forEach(function (chunk) {
    //   cursor.shift(chunk);
    //   return switch cursor.seek(sep) {
    //     case None: Resume;
    //     case Some(v):
    //   }
    // });
  }
}

@:require('tink_tcp')
class TcpContainer implements Container {
  static public function wrap(handler:tink.http.Handler):tink.tcp.Handler {
    return function (i:tink.tcp.Incoming):Future<tink.tcp.Outgoing> {
      return IncomingRequest.parse(i.from.host, i.stream)
        .next(handler.process)
        .recover(OutgoingResponse.reportError)
        .map(function (res) return {
          stream: res.body.prepend(res.header.toString()),
          allowHalfOpen: true,
        });
    }
  }
  var port:Promise<tink.tcp.OpenPort>;

  
  @:require(tink_tcp)
  public function new(port:Void->Promise<tink.tcp.OpenPort>) {
    this.port = Future.async(function (cb) {
      port().handle(cb);
    }, true);
  }
  
  public function run(handler):Future<ContainerResult> 
    return port.next(function (p) 
      return 
        if (!p.setHandler(wrap(handler))) Running({ 
          shutdown: p.shutdown, 
          failures: Signal.trigger()
        })
        else Shutdown
    ).map(function (o) return switch o {
      case Success(v): v;
      case Failure(e): Failed(e);
    });
}
