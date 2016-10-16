import tink.http.Header.HeaderField;
import tink.http.Method;
import tink.http.Request;
import tink.url.Host;

typedef RequestData = {
  ?method: Method,
  url: String,
  ?headers: Map<String, String>,
  ?body: String
}

abstract ClientRequest(RequestData) {
  inline function new(data: RequestData) {
    if (data.body == null) data.body = '';
    if (data.method == null) data.method = Method.GET;
    this = data;
  }
  
  @:from public static function fromData(data: RequestData)
    return new ClientRequest(data);
    
  function fields()
    return switch this.headers {
      case null: [];
      case v: [
        for (key in this.headers.keys())
          new HeaderField(key, this.headers.get(key))
      ];
    }
  
  @:to public function toOutgoing(): OutgoingRequest {
    return 
      new OutgoingRequest(
        new OutgoingRequestHeader(
          this.method, 
          new Host('127.0.0.1', Std.parseInt(Env.getDefine('port'))), 
          this.url, fields()
        ), 
        this.body
      );
  }
}