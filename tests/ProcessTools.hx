package;

import haxe.io.Input;
import sys.io.Process;
import tink.io.Source;
import tink.io.Sink;
import neko.vm.Thread;
import haxe.io.Eof;

class ProcessTools {
	
	static var counter = 0;
	
	public static function compile(args) {
		var travis = Sys.getEnv('TRAVIS') == 'true';
		if (travis) Sys.println('travis_fold:start:compile-$target.$counter');
		if (Sys.command('haxe', args) != 0) throw 'Could not compile';
		if (travis) Sys.println('travis_fold:end:compile-$target.$counter');
		counter++;
	}
	
	public static function install(target) {
		Sys.command('haxelib', ['run', 'travix', target]);
	}
	
	public static function streamAll(cmd, args): Process {
		var process = new Process(cmd, args);
		stream(process.stderr);
		stream(process.stdout);
		return process;
	}
	
	static function stream(input: Input) {
		var stdout = Sys.stdout();
		Thread.create(function()
			while(true) try stdout.writeByte(input.readByte()) catch(e: Eof) break
		);
	}
	
}