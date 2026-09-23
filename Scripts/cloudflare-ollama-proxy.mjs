#!/usr/bin/env node
import http from "node:http";

const accountID = String(process.env.KRALI_CF_ACCOUNT_ID || "").trim();
const apiToken = String(process.env.KRALI_CF_API_TOKEN || "").trim();
const mainModel =
  String(process.env.KRALI_CF_MAIN_MODEL || "@cf/zai-org/glm-4.7-flash").trim();
const jsonModel =
  String(process.env.KRALI_CF_JSON_MODEL || "@cf/meta/llama-3.3-70b-instruct-fp8-fast").trim();
const port = Number(process.env.KRALI_CF_PROXY_PORT || "11435");

function fail(message, code = 1) {
  process.stderr.write(message + "\n");
  process.exit(code);
}

if (process.argv.includes("--self-test")) {
  const sample = {
    type: "function",
    function: {
      name: "read_file",
      description: "Read a file",
      parameters: {
        type: "object",
        properties: { path: { type: "string" } },
        required: ["path"],
      },
    },
  };
  const converted = toCloudflareTool(sample);
  const ok =
    converted.name === "read_file" &&
    converted.parameters?.required?.[0] === "path" &&
    chooseModel({ format: { type: "object" } }) === jsonModel &&
    chooseModel({}) === mainModel;
  process.stdout.write(ok ? "cloudflare_proxy_self_test_ok\n" : "cloudflare_proxy_self_test_failed\n");
  process.exit(ok ? 0 : 2);
}

if (!accountID || !apiToken) {
  fail("Cloudflare Workers AI account/token eksik.", 40);
}
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  fail("Cloudflare proxy port geçersiz.", 41);
}

function chooseModel(body = {}) {
  return body.format ? jsonModel : mainModel;
}

function toCloudflareTool(tool = {}) {
  const fn = tool?.function && typeof tool.function === "object"
    ? tool.function
    : tool;
  return {
    name: String(fn.name || ""),
    description: String(fn.description || ""),
    parameters:
      fn.parameters && typeof fn.parameters === "object"
        ? fn.parameters
        : { type: "object", properties: {} },
  };
}

function normalizeArguments(value) {
  if (value && typeof value === "object") return value;
  if (typeof value !== "string") return {};
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function toOllamaToolCall(item = {}) {
  const fn = item?.function && typeof item.function === "object"
    ? item.function
    : item;
  return {
    function: {
      name: String(fn.name || ""),
      arguments: normalizeArguments(fn.arguments),
    },
  };
}

function ollamaResponse(body, model, result) {
  const rawResponse = result?.response;
  const content =
    typeof rawResponse === "string"
      ? rawResponse
      : rawResponse == null
        ? ""
        : JSON.stringify(rawResponse);

  const toolCalls = Array.isArray(result?.tool_calls)
    ? result.tool_calls.map(toOllamaToolCall)
    : [];

  return {
    model: String(body?.model || "cloudflare"),
    created_at: new Date().toISOString(),
    message: {
      role: "assistant",
      content,
      ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
    },
    done: true,
    provider: "cloudflare-workers-ai",
    remote_model: model,
    usage: result?.usage || null,
  };
}

async function cloudflareChat(body) {
  const model = chooseModel(body);

  if (
    Array.isArray(body?.messages) &&
    body.messages.length === 0 &&
    body.keep_alive === 0
  ) {
    return {
      status: 200,
      payload: ollamaResponse(body, model, { response: "" }),
    };
  }

  const requestBody = {
    messages: Array.isArray(body?.messages) ? body.messages : [],
    stream: false,
    temperature:
      Number.isFinite(Number(body?.options?.temperature))
        ? Number(body.options.temperature)
        : 0.1,
  };

  if (Array.isArray(body?.tools) && body.tools.length) {
    requestBody.tools = body.tools.map(toCloudflareTool);
  }

  const predict = Number(body?.options?.num_predict);
  if (Number.isFinite(predict) && predict > 0) {
    requestBody.max_tokens = Math.min(4096, Math.max(64, Math.trunc(predict)));
  }

  if (body?.format && typeof body.format === "object") {
    requestBody.response_format = {
      type: "json_schema",
      json_schema: body.format,
    };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120000);

  try {
    const response = await fetch(
      "https://api.cloudflare.com/client/v4/accounts/" +
        encodeURIComponent(accountID) +
        "/ai/run/" +
        model,
      {
        method: "POST",
        headers: {
          authorization: "Bearer " + apiToken,
          "content-type": "application/json",
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      }
    );

    const payload = await response.json().catch(() => ({}));

    if (!response.ok || payload?.success === false) {
      return {
        status: response.status || 502,
        payload: {
          error: "Cloudflare Workers AI request failed",
          provider_status: response.status,
          errors: Array.isArray(payload?.errors)
            ? payload.errors.slice(0, 4)
            : [],
        },
      };
    }

    return {
      status: 200,
      payload: ollamaResponse(body, model, payload?.result || {}),
    };
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "AbortError";
    return {
      status: timedOut ? 504 : 502,
      payload: {
        error: timedOut
          ? "Cloudflare Workers AI request timed out"
          : "Cloudflare Workers AI transport failed",
      },
    };
  } finally {
    clearTimeout(timer);
  }
}

function sendJSON(res, status, value) {
  const data = Buffer.from(JSON.stringify(value));
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": String(data.length),
    "cache-control": "no-store",
  });
  res.end(data);
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/api/version") {
    sendJSON(res, 200, { version: "cloudflare-workers-ai-proxy-v1" });
    return;
  }

  if (req.method === "GET" && req.url === "/api/tags") {
    sendJSON(res, 200, {
      models: [
        { name: "cloudflare-main", model: mainModel },
        { name: "cloudflare-json", model: jsonModel },
      ],
    });
    return;
  }

  if (req.method === "GET" && req.url === "/api/ps") {
    sendJSON(res, 200, { models: [] });
    return;
  }

  if (req.method !== "POST" || req.url !== "/api/chat") {
    sendJSON(res, 404, { error: "not_found" });
    return;
  }

  let raw = "";
  req.setEncoding("utf8");
  req.on("data", (chunk) => {
    raw += chunk;
    if (raw.length > 2_000_000) {
      req.destroy();
    }
  });
  req.on("end", async () => {
    let body;
    try {
      body = JSON.parse(raw || "{}");
    } catch {
      sendJSON(res, 400, { error: "invalid_json" });
      return;
    }
    const result = await cloudflareChat(body);
    sendJSON(res, result.status, result.payload);
  });
});

server.listen(port, "127.0.0.1", () => {
  process.stdout.write(
    "cloudflare_proxy_ready|127.0.0.1:" +
      port +
      "|main=" +
      mainModel +
      "|json=" +
      jsonModel +
      "\n"
  );
});
