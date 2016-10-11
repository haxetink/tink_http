package tink.http.containers;

import python.*;
import python.Tuple;
import haxe.io.Bytes;
import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.io.IdealSource;
import tink.url.Host;

using tink.CoreApi;

class PythonContainer implements Container {
  
  var host:Host;
  
  public function new(host:Host) {
    this.host = host;
    trace(ThreadingMixIn, HTTPServer); // HACK: make sure they got imported
  }
  
  public function run(handler:Handler) {
    var server = new PythonServer(Tuple2.make(host.name, host.port), PythonHandler, handler);
    #if (tink_concurrent && concurrent)
      new tink.concurrent.Thread(server.start); // TODO: use runloop maybe?
    #else
      server.start(); // This will block
    #end
    var failures = Signal.trigger();
    return Future.sync(Running({ 
      shutdown: function (hard:Bool) {
        server.stop();
        return Future.sync(Noise);
      },
      failures: failures, //TODO: these need to be triggered
    }));
  }
}

class PythonHandler extends BaseHTTPRequestHandler {
  public function do_GET() doRequest();
  public function do_POST() doRequest();
  public function do_PUT() doRequest();
  public function do_PATCH() doRequest();
  public function do_DELETE() doRequest();
  public function do_HEAD() doRequest();
  public function do_OPTIONS() doRequest();
  
  function doRequest() {
    var contentLength = 0;
    var headerFields = [];
    for(i in headers.items()) {
      var name = i._1;
      var value = i._2;
      headerFields.push(new HeaderField(name, value));
      if(name.toLowerCase() == 'content-length') contentLength = Std.parseInt(value);
    }
    server.handler.process(new IncomingRequest(
      address_string(),
      new IncomingRequestHeader(cast command, requestline, request_version, headerFields),
      Plain(Bytes.ofData(rfile.read(contentLength)))
    )).handle(function(res) {
      send_response(res.header.statusCode, res.header.reason);
      for(f in res.header.fields) send_header(f.name, f.value);
      end_headers();
      res.body.all().handle(function(bytes) wfile.write(bytes.getData()));
    });
  }
}

class PythonServer extends ThreadingSimpleServer {
  public var handler:Handler;
  var stopped = false;
  public function new(host:Tuple2<String, Int>, handlerClass:Class<BaseHTTPRequestHandler>, handler:Handler) {
    super(host, handlerClass);
    this.handler = handler;
  }
  public function start() {
    while(true) if(stopped) break else handle_request(); // TODO: this will handle one more request after stopped, beucase handle_request is blocking
  }
  public function stop() {
    stopped = true;
  }
}

@:native('tink_http_containers_ThreadingMixIn, tink_http_containers_HTTPServer') // HACK: for multiple inheritance
extern class ThreadingSimpleServer {
  function new(host:Tuple2<String, Int>, handlerClass:Class<BaseHTTPRequestHandler>);
  function handle_request():Void;
}

@:pythonImport('socketserver', 'ThreadingMixIn')
extern class ThreadingMixIn {}

@:pythonImport('http.server', 'HTTPServer')
extern class HTTPServer {}

@:pythonImport('http.server', 'BaseHTTPRequestHandler')
extern class BaseHTTPRequestHandler {
  var server:PythonServer; // HACK
  var requestline:String;
  var command:String;
  var request_version:String;
  var headers:HTTPMessage;
  var rfile:python.lib.io.RawIOBase;
  var wfile:python.lib.io.RawIOBase;
  
  function address_string():String;
  function send_response(code:Int, ?message:String):Void;
  function send_header(name:String, value:String):Void;
  function end_headers():Void;
}

@:pythonImport('http.client', 'HTTPMessage')
extern class HTTPMessage {
  function getheader(name:String):String;
  function items():Array<Tuple2<String, String>>;
}