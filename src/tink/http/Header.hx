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
    
    var parsed = (s:HeaderValue).parse();
    var value = parsed[0].value;
    switch value.indexOf('/') {
      case -1:
        ret.type = value;
      case pos:
        ret.type = value.substring(0, pos);
        ret.subtype = value.substring(pos + 1);
    }
    ret.extension = parsed[0].extensions;
    
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
        Failure(new Error(UnprocessableEntity, 'No $name header found'));
      case [v]:
        Success(v);
      case v: 
        Failure(new Error(UnprocessableEntity, 'Multiple entries for $name header'));
    }
    
  public function contentType() 
    return byName('content-type').map(ContentType.ofString);
    
  public inline function iterator()
    return fields.iterator();
}

abstract HeaderValue(String) from String to String {
        
  public function getExtension():Map<String, String>
    return parse()[0].extensions;
      
  public function parse()
    return parseWith(function(_, params) return [for(p in params) p.name => switch p.value.toString() {
      case quoted if (quoted.charCodeAt(0) == '"'.code): quoted.substr(1, quoted.length - 2);//TODO: find out how exactly escaping and what not works
      case v: v;
    }]);
    
  public function parseWith<T>(parseExtension:String->Iterator<QueryStringParam>->T)
    return [for(v in this.split(',')) {
      v = v.trim();
      var i = switch v.indexOf(';') {
        case -1: v.length;
        case i: i;
      }
      var value = v.substr(0, i);
      {
        value: value,
        extensions: parseExtension(value, Query.parseString(v, ';', i + 1)),
      }
    }];
  
  static var DAYS = 'Sun,Mon,Tue,Wen,Thu,Fri,Sat'.split(',');
  static var MONTHS = 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'.split(',');
  @:from static public function ofDate(d:Date):HeaderValue
    return DateTools.format(d, DAYS[d.getDay()] + ", %d " + MONTHS[d.getMonth()] + " %Y %H:%M:%S GMT");
  
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
      addPair("expires=", (options.expires:HeaderValue));
    
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
