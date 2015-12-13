package tink.http;

import haxe.io.Bytes;
import tink.io.Sink;
import tink.io.Source;
import tink.http.Message;
import haxe.ds.Option;
import tink.streams.Stream;
import tink.streams.StreamStep;
using tink.CoreApi;

class Multipart {
  static function getChunk(s:Source, delim:Bytes):Surprise<Option<{ chunk:MultipartChunk, rest:Source }>, Error> {
    var split = s.split(delim);
    return
      split.first.parse(new HeaderParser(function (line, fields) {
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
                rest: split.then,
              });
            
  }
  static function parse(s:Source, delim:String):Stream<MultipartChunk> {
    var delim = Bytes.ofString('\r\n--$delim');
    
    s = s.split(delim).then;
    
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

typedef MultipartChunk = Message<Header, Source>;