package tink.http;

import tink.streams.RealStream;
import tink.streams.Stream;
import tink.streams.IdealStream;
import tink.io.StreamParser;
import tink.io.Source;

using tink.CoreApi;

typedef Sse = {
  final data:String;
  @:optional public final id:String;
  @:optional public final event:String;
  @:optional public final retry:Int;
}

class SseStream {
  static public function encode(events:IdealStream<Sse>):IdealSource {
    return events.map((e:Sse) -> {
      final parts = [];

      if (e.id != null) parts.push('id: ${e.id}');
      if (e.event != null) parts.push('event: ${e.event}');
      if (e.retry != null) parts.push('retry: ${e.retry}');

      for (line in e.data.split('\n')) 
        parts.push('data: $line');

      (parts.join('\n') + '\n\n':Chunk);
    });
  }

  static public function decode(source:RealSource):RealStream<Sse> {
    return
      StreamParser.parseStream(source, new Splitter('\n\n'))
        .filter((c:Option<Chunk>) -> c != None)
        .map((c:Option<Chunk>) -> {
          var id = null,
              event = "message",
              retry = null,
              data = [];

          for (l in c.sure().toString().split('\n'))
            switch l.indexOf(':') {
              case -1: 
              case pos:
                final field = l.substring(0, pos);
                final value = l.substring(pos + if (l.charAt(pos + 1) == ' ') 2 else 1);
                
                switch field {
                  case 'id': id = value;
                  case 'event': event = value;
                  case 'retry': retry = Std.parseInt(value);
                  case 'data': data.push(value);
                  case _:
                }
            }

          ({ id: id, event: event, retry: retry, data: if (data.length == 0) null else data.join('\n') }:Sse);
        })
        .filter((sse:Sse) -> sse.data != null);
  }
}