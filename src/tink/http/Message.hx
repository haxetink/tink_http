package tink.http;

import tink.io.Source;

class Message<Header, Body:Source> {
  
  public var header(default, null):Header;
  public var body(default, null):Body;
  
  public function new(header, body) {
    this.header = header;
    this.body = body;
  }
  
}

class MessageHeader {
  public var fields(default, null):Array<MessageHeaderField>;
  public function new(fields)
    this.fields = fields;
}

class MessageHeaderField {
  
  public var name(default, null):String;
  public var value(default, null):String;
  
  public function new(name, value) {
    this.value = value;
    this.name = name;
  }
}