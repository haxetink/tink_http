package tink.http;

class Message<H:Header, B> {
  
  public var header(default, null):H;
  public var body(default, null):B;
  
  public function new(header, body) {
    this.header = header;
    this.body = body;
  }
    
}