package;

import sys.io.Process;
import tink.io.Source;
import tink.io.Sink;

class ProcessTools {

	public static function compile(args) {
		var process = new Process('haxe', args);
		streamOut(process);
		streamErr(process);
		if (process.exitCode() != 0)
			throw 'Failed to compile';
	}
	
	public static function passThrough(cmd, args): Bool {
		var process = new Process(cmd, args);
		streamOut(process);
		streamErr(process);
		return process.exitCode() == 0;
	} 
	
	public static function install(target): Bool {
		var process = new sys.io.Process('haxelib', ['run', 'travix', target]);
		streamErr(process);
		return process.exitCode() == 0;
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