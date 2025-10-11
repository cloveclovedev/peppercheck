interface Env {
	SUPABASE_PROJECT_ID: string;
}

const METHODS_WITHOUT_BODY = new Set(["GET", "HEAD", "OPTIONS"]);

export default {
	async fetch(request, env): Promise<Response> {
		const projectId = env.SUPABASE_PROJECT_ID;

		if (!projectId) {
			return new Response("SUPABASE_PROJECT_ID is not configured", { status: 500 });
		}

		const incomingUrl = new URL(request.url);
		const targetUrl = new URL(request.url);
		targetUrl.protocol = "https:";
		// localhost で wrangler dev を使うとポート 8787 が付いたままになるのでクリアする
		targetUrl.port = "";
		targetUrl.hostname = `${projectId}.supabase.co`;

		const headers = new Headers(request.headers);
		headers.set("x-forwarded-host", incomingUrl.host);
		headers.set("x-forwarded-proto", incomingUrl.protocol.replace(":", ""));

		const init: RequestInit = {
			method: request.method,
			headers,
			redirect: "manual",
		};

		if (!METHODS_WITHOUT_BODY.has(request.method.toUpperCase())) {
			init.body = request.body;
		}

		try {
			return await fetch(new Request(targetUrl.toString(), init));
		} catch (error) {
			console.error("Upstream fetch failed", error);
			return new Response("Upstream request failed", { status: 502 });
		}
	},
} satisfies ExportedHandler<Env>;
