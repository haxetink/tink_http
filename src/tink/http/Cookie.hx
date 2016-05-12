package tink.http;

using DateTools;
using StringTools;
using Std;

@:forward
abstract Cookie(CookieObject) from CookieObject {
	
	public inline function new(name:String, value:String, ?expires:Date, ?domain:String, ?path:String, secure = false, httpOnly = false)
		this = {
			name: name,
			value: value,
			expires: expires,
			domain: domain,
			path: path,
			secure: secure,
			httpOnly: httpOnly,
		}
	
	public static function parse(s:String):Array<Cookie> {
		return [
			for(pair in s.split('; ')) {
				var v = pair.split('=');
				{
					name: v[0],
					value: v[1],
				}
			}
		];
	}
	
	@:to
	public function toString():String {
		var buf = new StringBuf();
		buf.add(this.name);
		if(this.value != null) buf.add('=${this.value}');
		if(this.expires != null) buf.add('; expires=${formatDate(this.expires)}');
		if(this.domain != null) buf.add('; domain=${this.domain}');
		if(this.path != null) buf.add('; path=${this.path}');
		if(this.secure) buf.add('; secure');
		if(this.httpOnly) buf.add('; httponly');
		return buf.toString();
	}
	
	function formatDate(date:Date) {
		var timezoneOffset = 
			#if php
				untyped __php__("intval(date('Z', {0}->__t));", date);
			#else
				Date.fromString('1970-01-01 00:00:00').getTime();
			#end
		var d = date.delta(timezoneOffset);
		
		var day = switch d.getDay() {
			case 0: 'Sun';
			case 1: 'Mon';
			case 2: 'Tue';
			case 3: 'Wed';
			case 4: 'Thu';
			case 5: 'Fri';
			case 6: 'Sat';
			default: throw 'assert';
		}
		var date = d.getDate().string().lpad('0', 2);
		var month = switch d.getMonth() {
			case 0: 'Jan';
			case 1: 'Feb';
			case 2: 'Mar';
			case 3: 'Apr';
			case 4: 'May';
			case 5: 'Jun';
			case 6: 'Jul';
			case 7: 'Aug';
			case 8: 'Sep';
			case 9: 'Oct';
			case 10: 'Nov';
			case 11: 'Dec';
			default: throw 'assert';
		}
		var year = d.getFullYear();
		var hour = d.getHours().string().lpad('0', 2);
		var minute = d.getMinutes().string().lpad('0', 2);
		var second = d.getSeconds().string().lpad('0', 2);
		return '$day, $date-$month-$year $hour:$minute:$second GMT';
	}
}

typedef CookieObject = {
	name:String,
	value:String,
	?expires:Date,
	?domain:String,
	?path:String,
	?secure:Bool,
	?httpOnly:Bool,
}