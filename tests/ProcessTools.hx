import haxe.io.Input;
import sys.io.File;
import sys.io.Process;
import tink.io.Source;
import tink.io.Sink;
import neko.vm.Thread;
import haxe.io.Eof;

class ProcessTools {

  public static function streamAll(cmd, args): Process {
    var process = new Process(cmd, args);
    stream(process.stderr);
    stream(process.stdout);
    return process;
  }
  
  public static function travix(target: String, args: Array<String>): Process {
    File.saveContent('tests.hxml', ['-cp tests'].concat(args).join('\n'));
    return streamAll('haxelib', ['run', 'travix', target]);
  }
  
  static function stream(input: Input) {
    var stdout = Sys.stdout();
    Thread.create(function()
      while (true)
    try {
      stdout.writeByte(input.readByte());
      stdout.flush();
    } catch (e: Eof) 
      break
    );
  }
  
}