package;

import tink.http.Handler;
import tink.http.Request;
import tink.http.containers.NodeContainer2;
import tink.http.clients.NodeClient2;
import tink.http.Container;
import tink.http.Response;
import tink.io.Source;
import tink.http.StructuredBody;
import tink.streams.Stream;
import tink.http.Header;
using tink.io.Source;
using tink.CoreApi;

class Test {
	static function main() {
		function handleRunningState(state:RunningState) {
			state.failures.handle(f -> {
				trace(f);
			});
		}
		#if client
		trace('In this demo, the client multiplexes two bi-directional streams to the server over one HTTP connection.');
		var agent = new NodeClient2("https://localhost:8080", {
			ca: [js.node.Fs.readFileSync('localhost-cert.pem')]
		});
		var requestStream = Signal.trigger();
		var id = 0;
		function client() {
			agent.request(new OutgoingRequest(new OutgoingRequestHeader(GET, "/", "HTTP/2", [new HeaderField("tink-stream-id", id++)]),
				new SignalStream(requestStream)))
				.next(r -> {
					r.body.chunked().forEach(c -> {
						trace('Client received: $c');
						Resume;
					}).eager();
				})
				.eager();
		}
		client();
		client();
		var rl = js.node.Readline.createInterface({
			input: js.Node.process.stdin,
			output: js.Node.process.stdout
		});
		function loop()
			rl.question("Message: ", res -> {
				var closing = res == "close";
				requestStream.trigger(Data(tink.Chunk.ofString(res)));
				if (closing) {
					requestStream.trigger(End);
					rl.close();
				} else
					loop();
			});
		loop();
		#elseif server
		var container = new NodeContainer2(8080);
		function server() {
			container.runSecure({
				cert: js.node.Fs.readFileSync('./localhost-cert.pem'),
				key: js.node.Fs.readFileSync('./localhost-privkey.pem'),
			}, (req:IncomingRequest) -> {
				var id = req.header.get("tink-stream-id").join(';');
				trace('Incoming stream: $id');
					var outStream:IdealSource = switch req.body {
						case Plain(source):
							var ret = source.chunked().map((s:tink.Chunk) -> {
								var payload = tink.Chunk.ofString('Response to $id: $s');
								trace('sending $payload');
								Promise.resolve(payload);
							}).idealize(e -> [tink.Chunk.ofString('Error: $e')].iterator());
							cast ret;
						case Parsed(parts):
							var ret = parts.map(part -> switch part.value {
								case Value(text): tink.Chunk.ofString('${part.name}: $text');
								default: tink.Chunk.ofString('error');
							}).iterator();
							ret;
					}
					outStream.split(tink.Chunk.ofString('close')).after.chunked().forEach(c -> Resume).next(_->Noise).handle(() -> {
						trace('Done with stream $id');
					});
					Future.sync(OutgoingResponse.ofStream(outStream));
				}).next(r -> {
				switch r {
					case Running(running):
						handleRunningState(running);
					case Failed(e):
						trace(e);
					case Shutdown:
						trace("Shutdown");
				}
				Noise;
			}).eager();
		}
		server();
		#end
	}
}
