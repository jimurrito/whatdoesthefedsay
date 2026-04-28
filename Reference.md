# WhatDoesTheFedSay — Script Reference

## Overview

This PowerShell script automates fetching the Federal Reserve's current effective interest rate and committing it as a JSON file to a GitHub repository. It does this through two external systems: the **Federal Reserve website** and the **GitHub Git Data API**.

---

## Step 1 — Fetch the Fed H.15 Release Page

**Type:** HTTP GET  
**Target:** `https://www.federalreserve.gov/releases/h15/`

```powershell
(Invoke-WebRequest $fedUrl).Content
```

**Why:** The Federal Reserve publishes its H.15 Selected Interest Rates release as a public HTML page. This step pulls the raw HTML so the rate and effective date can be scraped from it. No authentication is required — this is a public government data source.

---

## Step 2 — Parse Date and Rate from HTML

No API call — pure string manipulation.

The script filters lines containing `col5` (the HTML column class used for the rate data), then splits on `>` and `<` to extract the date segments and the rate value (separated by `&nbsp;`).

**Why:** The Fed page is not a JSON API, so the data must be parsed directly out of HTML markup. The `col5` selector targets the specific table column that holds the effective rate.

---

## Step 3 — Generate a Random Seed

No API call — uses `Get-Random`.

A 9-digit integer is generated to serve as a nonce, used later as part of the commit message. This ensures each commit has a unique identifier even if the rate hasn't changed.

---

## Step 4 — Build the JSON Payload

No API call — constructs an in-memory object and serializes it to JSON.

The payload contains:
- `rate` — the parsed interest rate
- `date` — the effective date
- `seed` — the random nonce
- `source` — the originating Fed URL

**Why:** This structured payload is what gets written to the repository file (`rate.html`), providing a machine-readable record of the latest rate with traceability back to the source.

---

## GitHub API Calls

All GitHub calls share the same headers:

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <token>` |
| `X-GitHub-Api-Version` | `2022-11-28` |
| `User-Agent` | `WhatDoesTheFedSay` |
| `Content-Type` | `application/json` |

**Base URL:** `https://api.github.com/repos/jimurrito/whatdoesthefedsay`

---

## Step 6 — Get the HEAD Commit SHA

**Method:** GET  
**Endpoint:** `/branches/main`  
**Returns:** `commit.sha`

**Why:** Before creating any new Git objects, the script needs to know the current tip of the `main` branch. The HEAD commit SHA is used as the parent when creating the new commit, and as `base_tree` when building the new tree. This ensures the new commit slots cleanly on top of the existing history rather than creating an orphan.

---

## Step 7 — Create a Blob

**Method:** POST  
**Endpoint:** `/git/blobs`  
**Body:**
```json
{
  "content": "<base64-encoded JSON payload>",
  "encoding": "base64"
}
```
**Returns:** `sha` (the blob SHA)

**Why:** In Git's object model, a blob is the raw file content. The GitHub Git Data API requires file content to be uploaded as a blob object before it can be referenced in a tree. The payload is base64-encoded to safely transmit binary-safe content over JSON.

---

## Step 8 — Create a Tree

**Method:** POST  
**Endpoint:** `/git/trees`  
**Body:**
```json
{
  "base_tree": "<HEAD commit SHA>",
  "tree": [
    {
      "path": "rate.html",
      "mode": "100644",
      "type": "blob",
      "sha": "<blob SHA>"
    }
  ]
}
```
**Returns:** `sha` (the tree SHA)

**Why:** A Git tree maps file paths to blob objects — it's essentially a directory snapshot. By passing `base_tree`, the new tree inherits all existing files and only overrides `rate.html` with the new blob. Mode `100644` means a regular (non-executable) file.

> **Note:** The file is named `rate.html` but contains JSON. This is likely intentional for serving the file directly via GitHub Pages or a static host without content-type restrictions.

---

## Step 9 — Create a Commit

**Method:** POST  
**Endpoint:** `/git/commits`  
**Body:**
```json
{
  "message": "<date> - <seed>",
  "parents": ["<HEAD commit SHA>"],
  "tree": "<tree SHA>"
}
```
**Returns:** `sha` (the new commit SHA)

**Why:** A commit object wraps a tree with a message, author metadata, and a pointer to the parent commit. Using the date and seed as the commit message gives each commit a human-readable timestamp and a unique identifier at a glance, without requiring any additional tooling.

---

## Step 10 — Update the Branch Ref

**Method:** PATCH  
**Endpoint:** `/git/refs/heads/main`  
**Body:**
```json
{
  "sha": "<new commit SHA>"
}
```

**Why:** Creating a commit object alone doesn't move the branch — it just adds the object to Git's object store. This PATCH call fast-forwards the `main` branch ref to point at the new commit, making it the new HEAD and publishing the change to the repository.

---

## Data Flow Summary

```
Fed Website (HTML)
      │
      ▼
 Parse rate + date
      │
      ▼
 Build JSON payload
      │
      ├─── GET /branches/main ──────────► HEAD SHA
      │
      ├─── POST /git/blobs ─────────────► Blob SHA
      │         (payload content)
      │
      ├─── POST /git/trees ─────────────► Tree SHA
      │         (blob SHA + HEAD SHA)
      │
      ├─── POST /git/commits ───────────► Commit SHA
      │         (tree SHA + HEAD SHA)
      │
      └─── PATCH /git/refs/heads/main ──► Branch updated
                (commit SHA)
```



