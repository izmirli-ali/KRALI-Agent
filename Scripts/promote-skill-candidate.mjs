import fs from "node:fs";
import path from "node:path";

const candidateFile =
  process.env.KRALI_SKILL_CANDIDATE_FILE ||
  process.argv[2] ||
  "";
const libraryFile =
  process.env.KRALI_SKILL_LIBRARY_FILE ||
  process.argv[3] ||
  "";
const runtimeVerified =
  (process.env.KRALI_SKILL_RUNTIME_VERIFIED || "0") === "1";
const runtimeSummary =
  process.env.KRALI_SKILL_RUNTIME_SUMMARY || "";

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

if (!candidateFile || !libraryFile) {
  fail("Skill promotion için candidate/library yolu eksik.", 2);
}

if (!runtimeVerified) {
  fail(
    "Skill promoted edilmedi: gerçek runtime postcondition doğrulaması gerekli.",
    3
  );
}

let candidate;
try {
  candidate = JSON.parse(
    fs.readFileSync(candidateFile, "utf8")
  );
} catch {
  fail("Skill candidate okunamadı.", 4);
}

if (
  candidate?.validation?.build_passed !== true ||
  candidate?.validation?.regression_passed !== true
) {
  fail("Skill promoted edilmedi: build/regression kanıtı eksik.", 5);
}

candidate.state = "promoted";
candidate.validation.runtime_postcondition_verified = true;
candidate.validation.runtime_validation_summary =
  runtimeSummary || "Runtime postcondition verified.";
candidate.updated_at = new Date().toISOString();

let library = {
  schema_version: 1,
  skills: [],
};

if (fs.existsSync(libraryFile)) {
  try {
    const loaded = JSON.parse(
      fs.readFileSync(libraryFile, "utf8")
    );

    if (loaded && Array.isArray(loaded.skills)) {
      library = loaded;
    }
  } catch {}
}

const index = library.skills.findIndex(
  (item) => item?.id === candidate.id
);

if (index >= 0) {
  library.skills[index] = candidate;
} else {
  library.skills.push(candidate);
}

library.skills = library.skills
  .filter((item) => item?.state === "promoted")
  .sort((a, b) =>
    String(b.updated_at || "").localeCompare(
      String(a.updated_at || "")
    )
  );

fs.mkdirSync(path.dirname(libraryFile), { recursive: true });
fs.writeFileSync(
  libraryFile,
  JSON.stringify(library, null, 2) + "\n",
  "utf8"
);

console.log(
  "skill_promoted|" +
    String(candidate.id || "") +
    "|" +
    libraryFile
);
