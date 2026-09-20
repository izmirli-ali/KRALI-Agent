const baseUrl =
  process.env.KRALI_OLLAMA_BASE_URL ||
  "http://127.0.0.1:11434";
const model =
  process.env.KRALI_DEV_MODEL || "";

if (!model) {
  console.error("KRALI local tool probe: model missing");
  process.exit(2);
}

const controller = new AbortController();
const timeout = setTimeout(
  () => controller.abort(),
  Number(process.env.KRALI_LOCAL_TOOL_PROBE_TIMEOUT_MS || "90000")
);

try {
  const response = await fetch(
    baseUrl.replace(/\/$/, "") + "/api/chat",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      signal: controller.signal,
      body: JSON.stringify({
        model,
        stream: false,
        messages: [
          {
            role: "system",
            content:
              "You are a tool-call capability probe. You must call the supplied function exactly once. Do not answer with JSON or prose.",
          },
          {
            role: "user",
            content:
              "Call krali_tool_probe now.",
          },
        ],
        tools: [
          {
            type: "function",
            function: {
              name: "krali_tool_probe",
              description:
                "A no-op function used only to verify native tool calling.",
              parameters: {
                type: "object",
                properties: {},
                additionalProperties: false,
              },
            },
          },
        ],
      }),
    }
  );

  if (!response.ok) {
    console.error(
      "KRALI local tool probe HTTP " +
        response.status
    );
    process.exit(3);
  }

  const payload = await response.json();
  const calls =
    payload?.message?.tool_calls;

  const passed =
    Array.isArray(calls) &&
    calls.some(
      (call) =>
        call?.function?.name ===
        "krali_tool_probe"
    );

  if (!passed) {
    const preview =
      String(
        payload?.message?.content || ""
      )
        .replace(/\s+/g, " ")
        .slice(0, 240);

    console.error(
      "KRALI local tool probe: native tool_call görülmedi" +
        (preview
          ? " • text=" + preview
          : "")
    );
    process.exit(25);
  }

  process.stdout.write(
    "tool_call_ok|" + model + "\n"
  );
} catch (error) {
  console.error(
    "KRALI local tool probe exception: " +
      (error instanceof Error
        ? error.message
        : String(error))
  );
  process.exit(4);
} finally {
  clearTimeout(timeout);
}
