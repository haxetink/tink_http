const puppeteer = require("puppeteer");
const handler = require("serve-handler");
const http = require("http");
const url = "http://localhost:8912/run.html";

const server = http.createServer((request, response) => {
	return handler(request, response, { public: __dirname });
});

server.listen(8912, async () => {
	const browser = await puppeteer.launch({
		headless: true,
		devtools: true,
		ignoreHTTPSErrors: true,
		args: [
			"--no-sandbox",
			"--disable-setuid-sandbox",
			"--disable-web-security",
			"--disable-features=IsolateOrigins",
			"--disable-site-isolation-trials",
			"--ignore-certificate-errors",
		],
	});
	const page = await browser.newPage();
	page.on("console", (msg) => console.log(msg.text()));
	page.on("pageerror", (err) => console.log(err));
	await Promise.all([
		page.exposeFunction("travixPrint", (s) => process.stdout.write(s)),
		page.exposeFunction("travixPrintln", (s) => process.stdout.write(s + "\n")),
		page.exposeFunction("travixExit", (code) => process.exit(code)),
		page.exposeFunction("travixThrow", (e) => {
			console.error("Uncaught error: ", e);
			process.exit(1);
		}),
	]);
	await page.evaluateOnNewDocument(() =>
		console.log(window.navigator.userAgent)
	);
	await page.goto(url);
});
