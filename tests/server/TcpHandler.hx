package server;

class TcpHandler {

	public static function main() {
		#if is_server
		var container = new tink.http.containers.TcpContainer(Std.parseInt(Sys.args()[0]));
		container.run(DummyServer.handleRequest).handle(function (r) switch r {
			case Running(server):
				trace('running');
			case v: 
				throw 'unexpected $v';
		});
		#end
	}
	
}