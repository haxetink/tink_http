package;

import sys.io.Process;
import tink.io.Source;
import tink.io.Sink;

class ProcessTools {

	public static function compile(args) {
		return Sys.command('haxe', args);
	}
	
	public static function passThrough(cmd, args): Bool {
		var process = new Process(cmd, args);
		streamOut(process);
		streamErr(process);
		return process.exitCode() == 0;
	} 
	
	public static function install(target): Bool {
		Sys.command('haxelib', ['run', 'travix', target]);
		return true;
	}
	
	public static function streamAll(cmd, args): Process {
		var process = new Process(cmd, args);
		streamOut(process);
		streamErr(process);
		return process;
	}
	
	static function streamOut(process) {
		Source.ofInput('process stdout', process.stdout).pipeTo(Sink.stdout);
	}
	
	static function streamErr(process) {
		Source.ofInput('process stderr', process.stderr).pipeTo(Sink.stdout);
	}
	
}