package tink.http;

@:enum abstract Method(String) to String {
  var GET = 'GET';
  var HEAD = 'HEAD';
  var OPTIONS = 'OPTIONS';
  
  var POST = 'POST';
  var PUT = 'PUT';
  var PATCH = 'PATCH';
  var DELETE = 'DELETE';
  
  static public function ofString(s:String, fallback:String->Method)
    return switch s.toUpperCase() {
      case 'GET': GET;
      case 'HEAD': HEAD;
      case 'OPTIONS': OPTIONS;
      case 'POST': POST;
      case 'PUT': PUT;
      case 'PATCH': PATCH;
      case 'DELETE': DELETE;
      case v: fallback(v); 
    }
}