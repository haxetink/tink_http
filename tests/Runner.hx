package;

import tink.http.Header.HeaderField;
import tink.http.Method;
import tink.http.Multipart;
import tink.http.Request;
import tink.io.IdealSource;
import tink.url.Host;

using buddy.Should;
using tink.CoreApi;

@colorize
class Runner extends buddy.SingleSuite {
    public function new() {
		var clients = Client.getClients();
        describe('tink_http', {
			
			it('should respond', function (done) {
				roundtrip(clients[0], GET).handle(function(res) {
					res.body.all().handle(function (o) {
						var raw: String = o.sure().toString();
						raw.should.be('ok');
						done();
					});
				});
			});
			
        });
    }
	
	function roundtrip(client, method:Method, uri:String = '/', ?fields:Array<HeaderField>, body:String = '') {
		fields = switch fields {
			case null: [];
			case v: v.copy();
		}

		var req = new OutgoingRequest(new OutgoingRequestHeader(method, new Host('127.0.0.1', 8000), uri, fields), body);
		switch body.length {
			case 0:
			case v: 
				switch req.header.get('content-length') {
					case []:
						fields.push(new HeaderField('content-length', Std.string(v)));
					default:
				}
		}
		return client.request(req);
    }
}