package tink.http;

import haxe.io.Bytes;
import tink.http.Request.IncomingRequest;
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
  
  //static public function getBoundary(h:Header)
    //return switch h.contentType() {
      
    //}
  
  static public function check(r:IncomingRequest):Option<Stream<MultipartChunk>> {
    
    return switch r.header.contentType() {
      case Success( { type: 'multipart', extension: _['boundary'] => boundary } ):
        Some(
          if (boundary != null)
            parseSource(r.body, boundary);
          else
            Stream.failure(new Error(UnprocessableEntity, 'No multipart boundary given'))
        );
      default:
        None;
    }
  }
  
  static public function parseSource(s:Source, delim:String):Stream<MultipartChunk> {
        
    s = s.split(Bytes.ofString('--$delim')).then;//TODO: make sure it's on its newline
    
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

typedef MultipartChunk = Message<Header, Source>;