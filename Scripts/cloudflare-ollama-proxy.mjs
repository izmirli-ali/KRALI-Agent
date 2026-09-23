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

function chooseModel(body = {}) {
  return body.format ? jsonModel : mainModel;
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

function normalizeToolForOpenAI(tool = {}) {
  if (
    tool?.type === "function" &&
    tool?.function &&
    typeof tool.function === "object"
  ) {
    return {
      type: "function",
      function: {
        name: String(tool.function.name || ""),
        description: String(tool.function.description || ""),
        parameters:
          tool.function.parameters &&
          typeof tool.function.parameters === "object"
            ? tool.function.parameters
            : { type: "object", properties: {} },
      },
    };
  }

  return {
    type: "function",
    function: {
      name: String(tool?.name || ""),
      description: String(tool?.description || ""),
      parameters:
        tool?.parameters && typeof tool.parameters === "object"
          ? tool.parameters
          : { type: "object", properties: {} },
    },
  };
}

function normalizeMessagesForOpenAI(messages = []) {
  const pending = [];
  let generatedID = 0;

  return messages.map((message) => {
    const role = String(message?.role || "user");

    if (role === "assistant") {
      const calls = Array.isArray(message?.tool_calls)
        ? message.tool_calls.map((call) => {
            const fn =
              call?.function && typeof call.function === "object"
                ? call.function
                : call;
            const id =
              String(call?.id || "").trim() ||
              "call_krali_" + (++generatedID);
            const name = String(fn?.name || "");
            pending.push({ id, name });
            return {
              id,
              type: "function",
              function: {
                name,
                arguments:
                  typeof fn?.arguments === "string"
                    ? fn.arguments
                    : JSON.stringify(fn?.arguments || {}),
              },
            };
          })
        : [];

      return {
        role: "assistant",
        content:
          message?.content == null
            ? (calls.length ? null : "")
            : String(message.content),
        ...(calls.length ? { tool_calls: calls } : {}),
      };
    }

    if (role === "tool") {
      const name = String(message?.name || message?.tool_name || "");
      const explicitID = String(message?.tool_call_id || "").trim();
      let toolCallID = explicitID;

      if (!toolCallID) {
        const index = pending.findIndex(
          (item) => !name || item.name === name
        );
        if (index >= 0) {
          toolCallID = pending[index].id;
          pending.splice(index, 1);
        }
      }

      if (!toolCallID) {
        // A tool result without a matching assistant tool call is invalid
        // in OpenAI Chat Completions. Preserve evidence as user context
        // instead of emitting an invalid role=tool message.
        return {
          role: "user",
          content:
            "[KRALI tool result" +
            (name ? " • " + name : "") +
            "]\n" +
            String(message?.content || ""),
        };
      }

      return {
        role: "tool",
        tool_call_id: toolCallID,
        content: String(message?.content || ""),
      };
    }

    return {
      role,
      content: String(message?.content || ""),
    };
  });
}

function toOllamaToolCall(item = {}) {
  const fn =
    item?.function && typeof item.function === "object"
      ? item.function
      : item;

  return {
    id: String(item?.id || ""),
    type: "function",
    function: {
      name: String(fn?.name || ""),
      arguments: normalizeArguments(fn?.arguments),
    },
  };
}

function ollamaResponseFromChatCompletion(body, model, payload) {
  const choice =
    Array.isArray(payload?.choices) && payload.choices.length
      ? payload.choices[0]
      : null;
  const message = choice?.message || {};
  const toolCalls = Array.isArray(message?.tool_calls)
    ? message.tool_calls.map(toOllamaToolCall)
    : [];

  return {
    model: String(body?.model || "cloudflare"),
    created_at: new Date().toISOString(),
    message: {
      role: "assistant",
      content:
        typeof message?.content === "string"
          ? message.content
          : message?.content == null
            ? ""
            : JSON.stringify(message.content),
      ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
    },
    done: true,
    provider: "cloudflare-workers-ai",
    remote_model: model,
    usage: payload?.usage || null,
  };
}

function sanitizedProviderError(payload) {
  const error = payload?.error;
  if (typeof error === "string") return error.slice(0, 800);
  if (error && typeof error === "object") {
    return JSON.stringify({
      type: error.type,
      code: error.code,
      message: error.message,
    }).slice(0, 800);
  }
  if (Array.isArray(payload?.errors)) {
    return JSON.stringify(
      payload.errors.slice(0, 3).map((item) => ({
        code: item?.code,
        message: item?.message,
      }))
    ).slice(0, 800);
  }
  return "unknown_provider_error";
}

if (process.argv.includes("--self-test")) {
  const sampleTool = {
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
  const sampleMessages = normalizeMessagesForOpenAI([
    {
      role: "assistant",
      content: "",
      tool_calls: [
        {
          id: "call_test_1",
          function: {
            name: "read_file",
            arguments: { path: "README.md" },
          },
        },
      ],
    },
    {
      role: "tool",
      name: "read_file",
      content: "{\"ok\":true}",
    },
  ]);
  const tool = normalizeToolForOpenAI(sampleTool);
  const ok =
    tool.type === "function" &&
    tool.function.name === "read_file" &&
    tool.function.parameters?.required?.[0] === "path" &&
    sampleMessages[0]?.tool_calls?.[0]?.id === "call_test_1" &&
    sampleMessages[1]?.tool_call_id === "call_test_1" &&
    chooseModel({ format: { type: "object" } }) === jsonModel &&
    chooseModel({}) === mainModel;

  process.stdout.write(
    ok
      ? "cloudflare_proxy_self_test_ok\n"
      : "cloudflare_proxy_self_test_failed\n"
  );
  process.exit(ok ? 0 : 2);
}

if (!accountID || !apiToken) {
  fail("Cloudflare Workers AI account/token eksik.", 40);
}
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  fail("Cloudflare proxy port geçersiz.", 41);
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
      payload: {
        model: String(body?.model || "cloudflare"),
        message: { role: "assistant", content: "" },
        done: true,
        provider: "cloudflare-workers-ai",
        remote_model: model,
      },
    };
  }

  const requestBody = {
    model,
    messages: normalizeMessagesForOpenAI(
      Array.isArray(body?.messages) ? body.messages : []
    ),
    stream: false,
    temperature:
      Number.isFinite(Number(body?.options?.temperature))
        ? Number(body.options.temperature)
        : 0.1,
  };

  if (Array.isArray(body?.tools) && body.tools.length) {
    requestBody.tools = body.tools.map(normalizeToolForOpenAI);
    requestBody.tool_choice = "auto";
  }

  const predict = Number(body?.options?.num_predict);
  if (Number.isFinite(predict) && predict > 0) {
    requestBody.max_completion_tokens = Math.min(
      4096,
      Math.max(64, Math.trunc(predict))
    );
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
        "/ai/v1/chat/completions",
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

    if (!response.ok) {
      const safeError = sanitizedProviderError(payload);
      process.stderr.write(
        "cloudflare_provider_error|status=" +
          response.status +
          "|model=" +
          model +
          "|detail=" +
          safeError +
          "\n"
      );
      return {
        status: response.status || 502,
        payload: {
          error: "Cloudflare Workers AI request failed",
          provider_status: response.status,
          detail: safeError,
        },
      };
    }

    return {
      status: 200,
      payload: ollamaResponseFromChatCompletion(
        body,
        model,
        payload
      ),
    };
  } catch (error) {
    const timedOut =
      error instanceof Error &&
      error.name === "AbortError";

    process.stderr.write(
      "cloudflare_provider_transport|" +
        (timedOut ? "timeout" : "failed") +
        "|model=" +
        model +
        "\n"
    );

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
    sendJSON(res, 200, {
      version: "cloudflare-workers-ai-proxy-v2",
    });
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
      "|transport=openai-chat-completions\n"
  );
});
