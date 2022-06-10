package tink.http.clients;

import haxe.io.Bytes;
import js.Browser;
import js.html.Headers;
import js.lib.HaxeIterator;
import js.lib.Int8Array;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;
using tink.io.Source;

class JsFetchClient implements ClientObject {
	final options: JsFetchClientOptions;

	public function new(?options: JsFetchClientOptions)
		this.options = options != null ? options : {};

	public function request(req: OutgoingRequest): Promise<IncomingResponse> {
		return switch req.header.url.scheme {
			case "http" | "https" #if !nodejs | null #end:
				final requestBody = switch req.header.method {
					case GET | HEAD | OPTIONS: Promise.resolve(null);
					default: req.body.all().next(chunk -> new Int8Array(chunk.toBytes().getData()));
				}

				final requestHeaders = new Headers();
				for (header in req.header) requestHeaders.append(header.name, header.value);

				var responseHeader: ResponseHeader;
				requestBody
					.next(body -> Browser.self.fetch(req.header.url, js.lib.Object.assign({}, options, {
						body: body,
						headers: requestHeaders,
						method: req.header.method
					})))
					.next(response -> {
						final headers = [for (entry in new HaxeIterator(response.headers.entries())) new HeaderField((entry[0]:String).toString(), (entry[1]:String).toString())];
						responseHeader = new ResponseHeader(response.status, response.statusText, headers);
						response.arrayBuffer();
					})
					.next(arrayBuffer -> new IncomingResponse(responseHeader, switch arrayBuffer {
						case null: Source.EMPTY;
						default: Bytes.ofData(arrayBuffer);
					}));

			default:
				Promise.reject(Helpers.missingSchemeError(req.header.url));
		}
	}
}

typedef JsFetchClientOptions = {
	?cache: js.html.RequestCache,
	?credentials: js.html.RequestCredentials,
	?mode: js.html.RequestMode,
	?referrerPolicy: js.html.ReferrerPolicy
}
