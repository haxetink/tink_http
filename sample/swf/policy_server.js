/*
A simple Flash socket policy server for NodeJS. Request must be, and response is, null-terminated, according to Adobe spec.
*/

var file = process.argv[2] || 'flashpolicy.xml',
	host = process.argv[3] || 'localhost',
	port = process.argv[4] || 843,
	poli;

var fsps = require('net').createServer(function (stream) {
	stream.setEncoding('utf8');
	stream.setTimeout(3000); // 3s
	stream.on('connect', function () {
		console.log('Got connection from ' + stream.remoteAddress + '.');
	});
	stream.on('data', function (data) {
		if (data == '<policy-file-request/>\0') {
			console.log('Good request. Sending file to ' + stream.remoteAddress + '.')
			stream.end(poli + '\0');
		} else {
			console.log('Bad request from ' + stream.remoteAddress + '.');
			stream.end();
		}
	});
	stream.on('end', function () {
		stream.end();
	});
	stream.on('timeout', function () {
		console.log('Request from ' + stream.remoteAddress + ' timed out.');
		stream.end();
	});
});

require('fs').readFile(file, 'utf8', function (err, p) {
	if (err) throw err;
	fsps.listen(port, host);
	// process.setgid('nobody');
	// process.setuid('nobody');
	poli = p;
	console.log('Flash socket policy server running at ' + host + ':' + port + ' and serving ' + file);
});