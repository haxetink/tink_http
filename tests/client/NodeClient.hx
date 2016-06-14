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
		return ProcessTools.passThrough('node', ['bin/node/runner.js']);
		
	#else
	
	public static function getClients() {
		var clients:Array<Client> = [];
		return [new tink.http.Client.NodeClient()];
	}
	
	#end
  
}