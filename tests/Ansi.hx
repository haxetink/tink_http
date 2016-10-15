package;

@:enum
abstract AnsiColor(Int) {
  var Black = 0;
  var Red = 1;
  var Green = 2;
  var Yellow = 3;
  var Blue = 4;
  var Magenta = 5;
  var Cyan = 6;
  var White = 7;
  var Default = 9;
}

class Ansi {
  
  public static function text(color: AnsiColor, text: String)
    return '\x1B[3${color}m${text}\x1B[39m';
    
  public static function report(msg)
    Sys.println(text(Green, '>> $msg'));
    
  public static function fail(msg)
    Sys.println(text(Red, '>> Failed: $msg'));
  
}