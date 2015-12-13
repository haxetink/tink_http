package tink.http;

import tink.core.Pair;
using StringTools;

class KeyValue {
  static public function parseMap(s, ?sep:String = '&', ?set:String = '=', ?pos:Int = 0) 
    return [for (p in parse(s, sep, set, pos)) p.a => p.b]; 
  
  static function trimmedSub(s:String, start:Int, end:Int) {
    while (s.fastCodeAt(start) <= 32)
      start++;
    while (s.fastCodeAt(end) <= 32)
      start--;
    return s.substring(start, end);
  }
    
  static public function parse(s:String, ?sep:String = '&', ?set:String = '=', ?pos:Int = 0):Iterator<Pair<String, Null<String>>> {
    return {
      hasNext: function () return pos < s.length,
      next: function () {
        var next = s.indexOf(sep, pos);
        
        if (next == -1)
          next = s.length;
        
        var split = s.indexOf(set, pos);
        var start = pos;
          
        pos = next + sep.length;
        
        return 
          if (split == -1 || split > next)
            new Pair(trimmedSub(s, start, next), null);
          else
            new Pair(trimmedSub(s, start, split), trimmedSub(s, split + set.length, next));
      }
    }
  }
}