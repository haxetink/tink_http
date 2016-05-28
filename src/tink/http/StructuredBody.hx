package tink.http;

import tink.io.Source;
using tink.CoreApi;

typedef StructuredBody = Array<BodyPart>;

typedef BodyPart = {
  var name(default, null):String;
  var value(default, null):ParsedParam;
}

enum ParsedParam {
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