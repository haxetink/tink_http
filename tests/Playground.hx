package;

import tink.http.Client.*;

using tink.CoreApi;

class Playground {
	static function main() {
		fetch('https://github.com/haxetink/tink_http/archive/master.zip').progress()
			.handle(function(o) switch o {
				case Success(res):
					res.body.bind(null, function(progress) trace(progress.value, Std.string(progress.total)));
					res.body.result().handle(function(o) trace(o.sure().length));
				case Failure(e):
					trace(e);
			});
	}
}