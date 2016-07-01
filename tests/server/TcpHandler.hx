package server;

class TcpHandler {

	public static function main() {
		@:privateAccess tink.RunLoop.create(function() {
			var container = new tink.http.containers.TcpContainer(Std.parseInt(Sys.args()[0]));
			container.run(DummyServer.handleRequest);
		});
	}
	
}