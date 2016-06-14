package client;

class JavaClient {

	#if neko
	
	public static function compile(args) {
		ProcessTools.install('java');
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-lib', 'tink_tcp',
			'-lib', 'hxjava',
			'-java', 'bin/java'
		]));
	}
	
	public static function run()
		return ProcessTools.passThrough('java', ['-jar', 'bin/java/Runner.jar']);
		
	#else
	
	public static function getClients() {
		var clients:Array<Client> = [];
		return [new tink.http.Client.TcpClient()];
	}
	
	#end
  
}