package tink.http;

import haxe.io.Bytes;
import tink.http.Request.IncomingRequest;
import tink.io.Sink;
import tink.io.Source;
import tink.io.IdealSource;
import tink.http.Message;
import tink.http.Header;
import haxe.ds.Option;
import tink.streams.Stream;
import tink.streams.StreamStep;
using tink.CoreApi;
using Lambda;

class Multipart {
  
  public var boundary(default, null):String;
  public var body(default, null):Source;
  
  public function new(chunks:Array<MultipartChunk>, ?boundary:String) {
    if(boundary == null) boundary = [for(i in 0...20) String.fromCharCode(Std.random(26) + 65)].join(''); // just a random A-Z string
    this.boundary = boundary;
    
    body = chunks.fold(
      function(chunk, prev:Source) return prev.append('--$boundary\r\n').append(chunk).append('\r\n'),
      Empty.instance
    ).append('--$boundary--\r\n');
  }
  
  static function getChunk(s:Source, delim:Bytes):Surprise<Option<{ chunk:MultipartChunk, rest:Source }>, Error> {
    var split = s.split(delim);
    return
      split.a.parse(new HeaderParser(function (line, fields) {
        return
          Success(if (line == '--') null
          else {
            fields.push(HeaderField.ofString(line));
            new Header(fields);
          });
      })) 
        >> 
          function (o:{ data: Header, rest: Source }) 
            return 
              if (o.data == null) None
              else Some({ 
                chunk: new Message(o.data, o.rest),
                rest: split.b,
              });
            
  }
  
  static public function check(r:IncomingRequest):Option<Stream<MultipartChunk>> {
    
    return switch [r.body, r.header.contentType()] {
      case [Plain(src), Success( { type: 'multipart', extension: _['boundary'] => boundary } )]:
        Some(
          if (boundary != null)
            parseSource(src, boundary);
          else
            Stream.failure(new Error(UnprocessableEntity, 'No multipart boundary given'))
        );
      default:
        None;
    }
  }
  
  static public function parseSource(s:Source, delim:String):Stream<MultipartChunk> {
        
    s = s.split(Bytes.ofString('--$delim')).b;//TODO: make sure it's on its newline
    
    var delim = Bytes.ofString('\r\n--$delim');

    return Stream.generate(function ():Future<StreamStep<MultipartChunk>> {
      return getChunk(s, delim).map(function (o) return switch o {
        case Success(None): 
          End;
        case Success(Some( { chunk: chunk, rest: rest } )): 
          s = rest; 
          Data(chunk);
        case Failure(e):
          Fail(e);
      });
    });
  }
}

@:forward
abstract MultipartChunk(Message<Header, Source>) from Message<Header, Source> {
  @:to
  public inline function asSource():Source {
    return (this.header.fields.join('\r\n'):Source).append('\r\n\r\n').append(this.body);
  }
}