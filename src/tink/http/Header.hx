package tink.http;

import tink.io.StreamParser;

using tink.CoreApi;
using StringTools;

class ContentType {
  public var type(default, null):String = '*';
  public var subtype(default, null):String = '*';
  public var extension(default, null):Null<Map<String, String>>;
  
  function new() { 
    extension = new Map();
  }
  
  static public function ofString(s:String) {
    var ret = new ContentType();
    
    inline function setType(max)
      switch s.indexOf('/') {
        case -1:
          ret.type = s;
        case pos:
          ret.type = s.substring(0, pos);
          ret.subtype = s.substring(pos + 1, max);
      }
      
    switch s.indexOf(';') {
      case -1: 
        setType(s.length);
      case pos: 
        setType(pos);
        for (p in KeyValue.parse(s, ';', pos + 1))
          ret.extension[p.a] = p.b;
    }
    
    return ret;
  }
}

class Header {
  public var fields(default, null):Array<HeaderField>;
  
  public function new(fields)
    this.fields = fields;
    
  public function get(name:HeaderName)
    return [for (f in fields) if (f.name == name) f.value];
  
  public function byName(name:HeaderName)
    return switch get(name) {
      case []:
        Failure(new Error(BadRequest, 'No $name header found'));
      case [v]:
        Success(v);
      case v: 
        Failure(new Error(BadRequest, 'Multiple entries for $name header'));
    }
    
  public function contentType() 
    return byName('content-type').map(ContentType.ofString);
}

abstract HeaderValue(String) from String to String {
        
  public function getExtension():Map<String, String>
    return 
      switch this.indexOf(';') {
        case -1: new Map();
        case v: [for (p in KeyValue.parse(this, ';', v + 1)) p.a => switch p.b.charAt(0) {
          case '"': p.b.substr(1, p.b.length -2);//TODO: find out how exactly escaping and what not works
          case v: v;
        }];
      }
      
  @:from static public function ofInt(i:Int):HeaderValue
    return Std.string(i);
}

abstract HeaderName(String) to String {
  
  inline function new(s) this = s;
  
  @:from static function ofString(s:String)
    return new HeaderName(s.toLowerCase());
}

class HeaderField {
  
  public var name(default, null):HeaderName;
  public var value(default, null):HeaderValue;
  
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
        new HeaderField(s, null);
      case v: 
        new HeaderField(s.substr(0, v), s.substr(v + 1).trim()); //urldecode?
    }
}

class HeaderParser<T> extends ByteWiseParser<T> {
	var header:T;
  var fields:Array<HeaderField>;
	var buf:StringBuf;
	var last:Int = -1;
  
  var makeHeader:String->Array<HeaderField>->Outcome<T, Error>;
  
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
          
          nextLine();

				case ['\r'.code, '\n'.code]:
					
					nextLine();
						
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
      
    function nextLine() {
      var line = buf.toString();
      buf = new StringBuf();
      last = -1;
      
      return
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
              fields.push(HeaderField.ofString(line));
              Progressed;
            }
        }      
    }
  
}