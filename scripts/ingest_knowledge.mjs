#!/usr/bin/env node
/**
 * Admin-only ingestion script for the Dhakker assistant's approved-source
 * knowledge registry (`knowledge_documents` / `knowledge_chunks` in
 * Firestore — see `assistant-proxy/worker.js`'s `retrieveKnowledge()` doc
 * comment for the retrieval side of this pipeline).
 *
 * This repo intentionally ships NO religious source content. This script
 * only writes whatever you point it at — it never invents/fabricates
 * content. Only ever run it against source files that a real editorial/
 * scholarly review process has actually approved.
 *
 * ── Input format ────────────────────────────────────────────────────────
 * A JSON array of objects, one per knowledge chunk:
 * [
 *   {
 *     "documentId": "stable-id-for-the-source-document",
 *     "title": "Human-readable title",
 *     "authority": "The approving authority/scholar/institution",
 *     "url": "https://... (optional)",
 *     "language": "en",              // one of ar/en/ur/tr/id/fr
 *     "section": "e.g. tawaf-basics", // optional
 *     "content": "The approved chunk text shown to the model.",
 *     "keywords": ["tawaf", "circuits", "kaaba"]
 *   },
 *   ...
 * ]
 *
 * ── Usage ────────────────────────────────────────────────────────────────
 *   export FIREBASE_PROJECT_ID=your-project-id
 *   export FIREBASE_ADMIN_TOKEN=$(gcloud auth print-access-token)   # or a
 *     # Firebase Auth ID token for an account with write access under
 *     # firestore.rules' admin-only rule for these two collections
 *   node scripts/ingest_knowledge.mjs path/to/approved-chunks.json
 *
 * The script is idempotent: each chunk's Firestore document ID is derived
 * from `documentId` + `section`, so re-running with the same input updates
 * the same documents rather than duplicating them.
 *
 * This performs a plain Firestore REST `PATCH` (upsert) against
 * `knowledge_chunks`, and a companion upsert into `knowledge_documents`
 * keyed by `documentId` with the document-level metadata (title, authority,
 * url, language). It requires network access to
 * firestore.googleapis.com and a token authorized to write under
 * `firestore.rules`' admin-only rule for these collections — it is NOT run
 * automatically by any CI/deploy step.
 */

import { readFileSync } from "node:fs";

const projectId = process.env.FIREBASE_PROJECT_ID;
const token = process.env.FIREBASE_ADMIN_TOKEN;
const inputPath = process.argv[2];

if (!projectId || !token) {
  console.error("Set FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN in the environment.");
  process.exit(1);
}
if (!inputPath) {
  console.error("Usage: node scripts/ingest_knowledge.mjs path/to/approved-chunks.json");
  process.exit(1);
}

const chunks = JSON.parse(readFileSync(inputPath, "utf8"));
if (!Array.isArray(chunks)) {
  console.error("Input file must be a JSON array of chunk objects.");
  process.exit(1);
}

const REQUIRED = ["documentId", "title", "authority", "language", "content", "keywords"];

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (Array.isArray(v)) {
      fields[k] = { arrayValue: { values: v.map((s) => ({ stringValue: String(s) })) } };
    } else {
      fields[k] = { stringValue: String(v ?? "") };
    }
  }
  return fields;
}

async function upsert(collection, docId, fields) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/` +
    `${collection}/${encodeURIComponent(docId)}`;
  const resp = await fetch(url, {
    method: "PATCH",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ fields }),
  });
  if (!resp.ok) {
    throw new Error(`Failed to upsert ${collection}/${docId}: ${resp.status} ${await resp.text()}`);
  }
}

let count = 0;
for (const chunk of chunks) {
  for (const field of REQUIRED) {
    if (!chunk[field]) throw new Error(`Chunk missing required field "${field}": ${JSON.stringify(chunk)}`);
  }
  const chunkDocId = `${chunk.documentId}__${chunk.section || "default"}`;
  await upsert("knowledge_chunks", chunkDocId, toFirestoreFields(chunk));
  await upsert("knowledge_documents", chunk.documentId, toFirestoreFields({
    documentId: chunk.documentId,
    title: chunk.title,
    authority: chunk.authority,
    url: chunk.url || "",
    language: chunk.language,
  }));
  count++;
  console.log(`Ingested: ${chunkDocId}`);
}

console.log(`Done. Ingested ${count} chunk(s).`);
