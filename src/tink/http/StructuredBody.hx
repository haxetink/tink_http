package tink.http;

import tink.io.Source;
import tink.core.Named;
using tink.CoreApi;

typedef StructuredBody = Array<Named<BodyPart>>;

enum BodyPart {
  Value(v:String);
  File(handle:UploadedFile);
}

typedef UploadedFile = {
  
  var fileName(default, null):String;
  var mimeType(default, null):String;
  var size(default, null):Int;
  
  function read():Source;
  function saveTo(path:String):Surprise<Noise, Error>;
}