package tink.http;

import tink.core.Named.NamedWith;
import tink.http.Header.HeaderField;
import tink.io.StreamParser;
import tink.url.Query;

using tink.CoreApi;
using StringTools;

class ContentType {
  public var fullType(get, never):String;
    inline function get_fullType()
      return '$type/$subtype';
      
  public var type(default, null):String = '*';
  public var subtype(default, null):String = '*';
  public var extension(default, null):Map<String, String>;
  
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
        for (p in Query.parseString(s, ';', pos + 1))
          ret.extension[p.name] = p.value;
    }
    
    return ret;
  }
}

class Header {
  public var fields(default, null):Array<HeaderField>;
  
  public function new(?fields)
    this.fields = switch fields {
      case null: [];
      case v: v;
    }
    
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
    return [for(e in parse()[0].extensions) e.name => e.value];
      
  public function parse() {
    var result = [];
    for(v in this.split(',')) {
      v = v.trim();
      switch v.indexOf(';') {
        case -1:
          result.push({value: v, extensions: []});
        case i:
          result.push({value: v.substr(0, i), extensions: [for(p in Query.parseString(v, ';', i+1)) {
            if(p.value.charCodeAt(0) == '"'.code) @:privateAccess p.value = p.value.substr(1, p.value.length - 2); //TODO: find out how exactly escaping and what not works
            p;
          }]});
      }
    }
    return result;
  }
  
  @:from static public function ofInt(i:Int):HeaderValue
    return Std.string(i);
}

abstract HeaderName(String) to String {
  
  inline function new(s) this = s;
  
  @:from static function ofString(s:String)
    return new HeaderName(s.toLowerCase());
}

class HeaderField extends NamedWith<HeaderName, HeaderValue> {
  
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
    
  /**
   * Constructs a Set-Cookie header. Please note that cookies are HttpOnly by default. 
   * You can opt out of that behavior by setting `options.scriptable` to true.
   */  
  static public function setCookie(key:String, value:String, ?options: { ?expires: Date, ?domain: String, ?path: String, ?secure: Bool, ?scriptable: Bool}) {
    
    if (options == null) 
      options = { };
      
    var buf = new StringBuf();
    
    inline function addPair(name, value) {
      if(value == null) return;
      buf.add("; ");
      buf.add(name);
      buf.add(value);
    }
    
    buf.add(key.urlEncode() + '=' + value.urlEncode());
    
    if (options.expires != null) 
      addPair("expires=", DateTools.format(options.expires, "%a, %d-%b-%Y %H:%M:%S GMT"));
    
    addPair("domain=", options.domain);
    addPair("path=", options.path);
    
    if (options.secure) addPair("secure", "");
    if (options.scriptable != true) addPair("HttpOnly", "");
    
    return new HeaderField('Set-Cookie', buf.toString());
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