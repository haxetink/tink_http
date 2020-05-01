package ;

import tink.io.Sink;
using tink.CoreApi;

import tink.io.Sink;
import tink.http.Chunked;
import tink.Chunk;
import tink.streams.Stream;
import tink.http.Fetch;

@:asserts
@:timeout(2000) 
class ChunkedEncoding{
  public function new(){}
  public function make_request(){
    var assertion = Future.trigger();
    var res = Fetch.fetch(
      "http://anglesharp.azurewebsites.net/Chunked",
      //"https://api.github.com",
      {
        headers : [
          new tink.http.Header.HeaderField('user-agent',
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2852.87 Safari/537.36"
          )
        ]
      }
    );
    res.all().handle(
      function(x){switch(x){
        case Success(x) : 
          asserts.assert(true,"returned result");
        default         : 
          trace(x);
          asserts.assert(false,"botched");
      }
    });
    return asserts.done();
  }  
  
  @:note('0b1kn00b','turns out I was wrong about azure using `\r\n`. Are you sure that `seek` works properly on multiple bytes?')
  @:timeout(10000)
  @:asserts
  public function generate_data(){
    //"http://anglesharp.azurewebsites.net/Chunked"
    var aligned_chunk       = "7f\r\n<!DOCTYPE html>\r\n<html lang=en>\r\n<head>\r\n<meta charset='utf-8'>\r\n<title>Chunked transfer encoding test</title>\r\n</head>\r\n<body>\r\n";
    var unaligned_chunk     = "27\r\n<h1>Chunked transfer encoding test</h1>\r\n31\r\n<h5>This is a chunked response ";
    var odd_bit             = "after 100 ms.</h5>\r\n";
    var last_bit            = "82\r\n<h5>This is a chunked response after 1 second. The server should not close the stream before all chunks are sent to a client.</h5>\r\ne\r\n</body></html>\r\n0\r\n";
    
    var signal              = Signal.trigger();
    var stream              = new SignalStream(signal.asSignal());

    var parts               = [aligned_chunk,unaligned_chunk,odd_bit,last_bit];
    var chunks              = parts.map(function(x){ return Chunk.ofString(x); });

    var parsed              = Chunked.decode(stream);

    for(chunk in chunks){
      signal.trigger(Data(chunk));
    }
    signal.trigger(Data(Chunk.ofString("\r\n")));
    signal.trigger(End);
  
    var res                 = "";
  
    var result              = parsed.pipeTo(Sink.BLACKHOLE);
        result.handle(
          function(v){
            asserts.assert(true,"how to get the data from the maze of types");
          }
        );
    
    return asserts.done();
  }
}
import tink.http.Chunked;
import tink.Chunk;
import tink.streams.Stream;
import tink.http.Fetch;

@:asserts
@:timeout(2000) 
class ChunkedEncoding{
  public function new(){}
  public function make_request(){
    var assertion = Future.trigger();
    var res = Fetch.fetch(
      "http://anglesharp.azurewebsites.net/Chunked",
      //"https://api.github.com",
      {
        headers : [
          new tink.http.Header.HeaderField('user-agent',
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2852.87 Safari/537.36"
          )
        ]
      }
    );
    res.all().handle(
      function(x){switch(x){
        case Success(x) : 
          asserts.assert(true,"returned result");
        default         : 
          trace(x);
          asserts.assert(false,"botched");
      }
    });
    return asserts.done();
  }  
  
  @:note('0b1kn00b','turns out I was wrong about azure using `\r\n`. Are you sure that `seek` works properly on multiple bytes?')
  @:timeout(10000)
  @:asserts
  public function generate_data(){
    //"http://anglesharp.azurewebsites.net/Chunked"
    var aligned_chunk       = "7f\r\n<!DOCTYPE html>\r\n<html lang=en>\r\n<head>\r\n<meta charset='utf-8'>\r\n<title>Chunked transfer encoding test</title>\r\n</head>\r\n<body>\r\n";
    var unaligned_chunk     = "27\r\n<h1>Chunked transfer encoding test</h1>\r\n31\r\n<h5>This is a chunked response ";
    var odd_bit             = "after 100 ms.</h5>\r\n";
    var last_bit            = "82\r\n<h5>This is a chunked response after 1 second. The server should not close the stream before all chunks are sent to a client.</h5>\r\ne\r\n</body></html>\r\n0\r\n";
    
    var signal              = Signal.trigger();
    var stream              = new SignalStream(signal.asSignal());

    var parts               = [aligned_chunk,unaligned_chunk,odd_bit,last_bit];
    var chunks              = parts.map(function(x){ return Chunk.ofString(x); });

    var parsed              = Chunked.decode(stream);

    for(chunk in chunks){
      signal.trigger(Data(chunk));
    }
    signal.trigger(Data(Chunk.ofString("\r\n")));
    signal.trigger(End);
  
    var res                 = "";
  
    var result              = parsed.pipeTo(Sink.BLACKHOLE);
        result.handle(
          function(v){
            asserts.assert(true,"how to get the data from the maze of types");
          }
        );
    
    return asserts.done();
  }
}