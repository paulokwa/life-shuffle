# Troubleshooting Log

This file records technical problems, confusing fixes, failed approaches, and useful debugging notes.

Use it so future AI agents do not repeat the same mistakes.

## Format

### YYYY-MM-DD — Issue title

- **Context**:
- **Symptoms**:
- **Cause**:
- **Fix**:
- **Files affected**:
- **Prevention / future note**:

---

## 2026-06-10 — GitHub connector search lag on new repo

- **Context**: The Life Shuffle repository was newly created and docs were added quickly.
- **Symptoms**: GitHub UI showed files existed, but connector search returned no results.
- **Cause**: GitHub/code search indexing appeared to lag behind the repository state.
- **Fix**: Fetch files directly by exact path instead of relying on search.
- **Files affected**: None.
- **Prevention / future note**: When a repo is new, ask for exact file paths or screenshots and use direct file fetch. Do not assume missing search results mean missing files.

---