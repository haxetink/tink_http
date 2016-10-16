import haxe.macro.Context;
import haxe.macro.Expr;

class Env {

  public static macro function getDefine(key: String, required: Bool = false): Expr {
    var value = Context.definedValue(key);
    if (required && value == null)
      Context.error('Undefined env: '+key, Context.currentPos());
    return macro $v{value};
  }
    
}