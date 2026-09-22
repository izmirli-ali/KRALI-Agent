const baseUrl =
  (process.env.KRALI_OLLAMA_BASE_URL ||
    "http://127.0.0.1:11434").replace(/\/$/, "");
const model =
  process.env.KRALI_CONTROLLER_PROBE_MODEL || "";
const timeoutMs = Number(
  process.env.KRALI_CONTROLLER_PROBE_TIMEOUT_MS || "30000"
);

if (!model) {
  console.error("controller_probe_missing_model");
  process.exit(2);
}

const format = {
  type: "object",
  additionalProperties: false,
  required: ["name", "arguments", "reason"],
  properties: {
    name: {
      type: "string",
      enum: ["replace_text"],
    },
    arguments: {
      type: "object",
      additionalProperties: false,
      required: ["path", "old_text", "new_text"],
      properties: {
        path: { type: "string" },
        old_text: { type: "string" },
        new_text: { type: "string" },
      },
    },
    reason: { type: "string" },
  },
};

const controller = new AbortController();
const timer = setTimeout(
  () => controller.abort(),
  timeoutMs
);
const startedAt = Date.now();

try {
  const response = await fetch(
    baseUrl + "/api/chat",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify({
        model,
        stream: false,
        keep_alive: "2m",
        format,
        messages: [
          {
            role: "system",
            content:
              "Return exactly one JSON tool decision matching the supplied schema.",
          },
          {
            role: "user",
            content:
              "Probe only. Choose replace_text for path A.swift and replace x with y. Reason: probe.",
          },
        ],
        options: {
          temperature: 0,
          num_ctx: 2048,
          num_predict: 192,
        },
      }),
    }
  );

  if (!response.ok) {
    console.error(
      "controller_probe_http|" + response.status
    );
    process.exit(3);
  }

  const payload = await response.json();
  const text =
    String(payload?.message?.content || "").trim();

  let decision;
  try {
    decision = JSON.parse(text);
  } catch {
    console.error(
      "controller_probe_invalid_json|" +
        text.replace(/\s+/g, " ").slice(0, 180)
    );
    process.exit(4);
  }

  const valid =
    decision?.name === "replace_text" &&
    decision?.arguments?.path === "A.swift" &&
    decision?.arguments?.old_text === "x" &&
    decision?.arguments?.new_text === "y";

  if (!valid) {
    console.error(
      "controller_probe_invalid_shape|" +
        text.replace(/\s+/g, " ").slice(0, 220)
    );
    process.exit(5);
  }

  process.stdout.write(
    "controller_probe_ok|" +
      model +
      "|" +
      (Date.now() - startedAt) +
      "ms\n"
  );
} catch (error) {
  const reason =
    error instanceof Error
      ? error.name + ":" + error.message
      : String(error);
  console.error(
    "controller_probe_failed|" +
      model +
      "|" +
      reason
  );
  process.exit(6);
} finally {
  clearTimeout(timer);
}
