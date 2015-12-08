package tink.http;

import tink.http.Message.MessageHeaderField;
import tink.io.Source;
import tink.io.StreamParser;

using tink.CoreApi;
using StringTools;

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
    
  public function get(name:String)
    return [for (f in fields) if (f.name == name) f.value];
}

class MessageHeaderField {
  
  public var name(default, null):String;
  public var value(default, null):String;
  
  public function new(name, value) {
    this.value = value;
    this.name = name;
  }
  
  public function toString() 
    return 
      if (value == null) name 
      else '$name: $value';//urlencode?
    
  static public function ofString(s:String)
    return switch s.indexOf(':') {
      case -1: 
        new MessageHeaderField(s, null);
      case v: 
        new MessageHeaderField(s.substr(0, v), s.substr(v + 1).trim()); //urldecode?
    }
}

class MessageHeaderParser<T> extends ByteWiseParser<T> {
	var header:T;
  var fields:Array<MessageHeaderField>;
	var buf:StringBuf;
	var last:Int = -1;
  
  var makeHeader:String->Array<MessageHeaderField>->Outcome<T, Error>;
  
	public function new(makeHeader) {
    super();
		this.buf = new StringBuf();
    this.makeHeader = makeHeader;
	}
  
	static var INVALID = Failed(new Error(UnprocessableEntity, 'Invalid HTTP header'));  
        
  override function read(c:Int):ParseStep<T> 
    return
			switch [last, c] {
				case [_, -1]:
					
					switch header {
            case null:
              Progressed;
            case v:
              header = null;
              Done(v);
					}

				case ['\r'.code, '\n'.code]:
					
					var line = buf.toString();
					buf = new StringBuf();
					last = -1;
					
					switch line {
						case '':
              if (header == null)
                Progressed;
              else
                Done(header);
						default:
							if (header == null)
                switch makeHeader(line, fields = []) {
                  case Success(null):
                    Done(this.header = null);
                  case Success(v): 
                    this.header = v;
                    Progressed;
                  case Failure(e):
                    Failed(e);
                }
							else {
                fields.push(MessageHeaderField.ofString(line));
								Progressed;
							}
					}
						
				case ['\r'.code, '\r'.code]:
					
					buf.addChar(last);
					Progressed;
					
				case ['\r'.code, other]:
					
					buf.addChar(last);
					buf.addChar(other);
					last = -1;
					Progressed;
					
				case [_, '\r'.code]:
					
					last = '\r'.code;
					Progressed;
					
				case [_, other]:
					
					last = other;
					buf.addChar(other);
					Progressed;
			}
  
}