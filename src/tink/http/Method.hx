package tink.http;

@:enum abstract Method(String) {
  var GET = 'GET';
  var HEAD = 'HEAD';
  var OPTIONS = 'OPTIONS';
  
  var POST = 'POST';
  var PUT = 'PUT';
  var PATCH = 'PATCH';
  var DELETE = 'DELETE';
}