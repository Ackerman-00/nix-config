import { readFileSync } from "node:fs";

const payload = JSON.parse(readFileSync(0, "utf8"));
const facts = [];

for (const section of payload.sections ?? []) {
  const heading = (section.heading ?? "").toLowerCase();
  const body = section.body ?? "";

  if (/deploy token/.test(heading)) {
    facts.push({
      subject: "Deploy tokens for this project",
      predicate: "states",
      object: "rotated every 90 days.",
      sectionIds: [section.id],
      graphSubjects: ["Deploy token rotation policy", "Deploy tokens"],
      confidence: 0.9
    });
  }

  if (/staging database/.test(heading)) {
    facts.push({
      subject: "The staging database host",
      predicate: "states",
      object: "`db-staging.internal`.",
      sectionIds: [section.id],
      graphSubjects: ["Staging database host", "db-staging.internal"],
      confidence: 0.9
    });
  }

  if (/ffmpeg|nvenc|media encoding/.test(heading) || /nvenc/.test(body)) {
    facts.push({
      subject: "ffmpeg",
      predicate: "must never use",
      object: "nvenc on this machine",
      sectionIds: [section.id],
      graphSubjects: ["ffmpeg", "nvenc", "AMD Vega 7", "encoder rule"],
      confidence: 0.95
    });
    facts.push({
      subject: "ffmpeg encoders to use on this machine",
      predicate: "states",
      object: "VA-API (`h264_vaapi`, `hevc_vaapi`) or CPU (`libx264`, `libx265`, `libsvtav1`)",
      sectionIds: [section.id],
      graphSubjects: ["VA-API", "libx264", "libx265", "libsvtav1"],
      confidence: 0.9
    });
    facts.push({
      subject: "The GPU",
      predicate: "states",
      object: "an AMD Vega 7",
      sectionIds: [section.id],
      graphSubjects: ["AMD Vega 7", "Ryzen 5 5600G"],
      confidence: 0.85
    });
  }

  if (/machine rule|project facts/.test(heading)) {
    facts.push({
      subject: "The ffmpeg nvenc rule",
      predicate: "applies to",
      object: "every project on this machine",
      sectionIds: [section.id],
      graphSubjects: ["machine rule", "ffmpeg", "nvenc"],
      confidence: 0.85
    });
  }
}

process.stdout.write(JSON.stringify({ events: [], facts, failures: [] }));
