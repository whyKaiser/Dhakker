// Mechanical asset packaging only; never contacts Firebase or changes text.
import assert from "node:assert/strict";
import { readFile, writeFile, mkdir, copyFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { sha256, validateMp3, BUCKET } from "./publish-algieba-audio.mjs";
const root = fileURLToPath(new URL("../", import.meta.url));
const source = resolve(root, "review/algieba-final-2026-09-10");
const manifest = JSON.parse(await readFile(resolve(source, "manifest.json"), "utf8"));
assert.equal(manifest.records.length, 53);
assert.equal(manifest.published, true);
const out = resolve(root, "assets/audio/duas");
await mkdir(out, { recursive: true });
const paths = {};
for (const record of manifest.records) {
  assert.match(record.audioSha256, /^[a-f0-9]{64}$/u);
  assert.match(record.file, /^[a-zA-Z0-9_-]+\.mp3$/u);
  const bytes = await readFile(resolve(source, record.file));
  assert.equal(sha256(bytes), record.audioSha256);
  validateMp3(bytes);
  const asset = `${record.audioSha256}.mp3`;
  await copyFile(resolve(source, record.file), resolve(out, asset));
  paths[`/v0/b/${BUCKET}/o/audio/duas/algieba-${record.audioSha256}.mp3`] = asset;
}
await writeFile(resolve(out, "manifest.json"), JSON.stringify({ version: 1, paths }, null, 2));
const lines = ["# أدعية Algieba — النسخة الأبطأ المصححة", "", "53 سجلًا، 52 تسجيلًا فريدًا. نص العرض الأصلي لم يتغير.", "",
  "اعتمد المستخدم عينة البقرة 201 وسرعتها. بقية التسجيلات اجتازت الفحص التقني، ولم تُعتمد جميعها بالسماع البشري بعد.", "",
  "التوليد بصوت Google Algieba، وليس تسجيل مؤدٍّ بشري. زيدت الوقفات الموجودة فقط؛ لا توجد وقفة مصطنعة داخل كلمة.", ""];
for (const r of manifest.records) lines.push(`## ${r.title}`, "", `[تشغيل](${r.file}) — ${r.durationSeconds.toFixed(1)} ثانية`, "", r.canonicalText, "", "نص النطق:", r.speechText, "");
await writeFile(resolve(source, "LISTENING_REVIEW.md"), lines.join("\n"));
console.log(JSON.stringify({ records: 53, uniqueAssets: Object.keys(paths).length,
  bytes: manifest.records.reduce((n, r) => n + r.bytes, 0), audioTokensInBundle: false }));
