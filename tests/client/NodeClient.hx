package client;

class NodeClient {

	#if neko
	
	public static function compile(args) {
		ProcessTools.install('node');
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-lib', 'hxnodejs',
			'-js', 'bin/node/runner.js'
		]));
	}
	
	public static function run()
		return ProcessTools.streamAll('node', ['bin/node/runner.js']).exitCode() == 0;
		
	#else
	
	public static function getClients() {
		var clients:Array<Client> = [];
		return [
			{
				name: 'Node client',
				client: new tink.http.Client.NodeClient()
			}
		];
	}
	
	#end
  
}