# Storage review of an AI-built Supabase app (demo)

A proof piece for security reviews of apps built with AI app builders, on the part they get wrong most quietly: file storage. A fictional tenant-screening app's Supabase Storage setup (buckets and the policies on `storage.objects`) with four flaws, each reproduced by an attack run as Supabase's `anon` or `authenticated` role, then fixed, with the same attacks refused and normal use still working.

| # | Flaw | Severity | Fix |
|---|---|---|---|
| 1 | ID scans and payslips in a public bucket: anyone with a file's address downloads it, policies or not | high | private bucket, signed URLs |
| 2 | The read policy checks the bucket only: every tenant lists and downloads every document | high | own folder, `storage.foldername(name)[1] = auth.uid()` |
| 3 | The delete policy checks the bucket only: every tenant deletes every document | high | own folder |
| 4 | Avatar upload and replace check the bucket only: anyone replaces anyone's avatar | medium | own folder on insert, and on update both `using` and `with check` |

Full write-up, in the format a client would receive: [docs/storage-review.md](docs/storage-review.md). Database access rules are covered by the companion demo [supabase-access-review-demo](https://github.com/nightly-works/supabase-access-review-demo).

Supabase itself is not needed: `sql/00_supabase_shim.sql` recreates the API roles, `auth.uid()`, `storage.objects` with row-level security, `storage.foldername()`, and the Storage API's download decision (a public bucket serves any file to anyone; a private one only what the caller's policies let them select, per Supabase's bucket documentation). It models the access decision, not the Storage service.

Run: `./run.sh` (PostgreSQL server binaries under `/usr/lib/postgresql/*/bin`, `psql`). It starts a throwaway cluster, runs the attacks on the setup as delivered (each must work), applies `sql/02_fixes.sql`, runs them again (each must be refused) and checks normal use, stopping at the first unexpected result.

[![checks](https://github.com/nightly-works/supabase-storage-review-demo/actions/workflows/checks.yml/badge.svg)](https://github.com/nightly-works/supabase-storage-review-demo/actions/workflows/checks.yml)

Built by an AI agent (Claude) at [Nightly Works](https://github.com/nightly-works); the app is fictional, written for this demo. MIT licence.
