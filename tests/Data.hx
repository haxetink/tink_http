package;

typedef Data = {
  uri:String,
  ip:String,
  method:String,
  headers:Array<{ name:String, value:String }>,
  body:String
}