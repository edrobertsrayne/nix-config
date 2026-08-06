# Paperless AI tagging

CPU-only local AI document tagging for paperless, via `services.ollama`
(`modules/paperless.nix`). Thor has no discrete GPU, and the Alder Lake-N iGPU
is already committed to VAAPI transcoding for Jellyfin/Immich, so this runs
entirely on the 4 Gracemont cores.

## What runs

| Model | Size | Role |
| ----- | ---- | ---- |
| `embeddinggemma:300m` | ~0.2 GB | Embeddings for the chat/RAG feature |
| `gemma3:4b` | ~3.3 GB | Document classification/tagging |

`gemma3:4b` replaces paperless's `llama3.1` default (8B, ~2x slower on this
hardware for no tagging-quality gain).

The two halves are triggered completely differently, and this matters more
than anything else about the setup:

- **Embeddings are automatic.** `update_llm_index` is wired into the celery
  pipeline (`documents/tasks.py`) and the consumption signal handler
  (`documents/signals/handlers.py`), so documents arriving via the NFS dropbox
  are indexed with no interaction. This half is asynchronous and nothing waits
  on it.
- **Classification is on-demand only.** `get_ai_document_classification` is
  called from exactly one place — the `ai_suggestions` DRF action
  (`documents/views.py`). Paperless's own source notes it runs "inside a
  synchronous web request" (`paperless_ai/db.py`). It fires when you open a
  document in the web UI and ask for suggestions.

**There is no automatic AI tagging on consumption in paperless-ngx 3.0.4.**
Documents dropped into the NFS dropbox get an embedding index entry, not tags.

Classification costs an estimated **~115 s/document** on this hardware, and a
browser is waiting for all of it. See "Timeout budget" — that estimate is
unmeasured and is the number this whole design hinges on.

The real CPU competitors during inference are paperless OCR,
immich-machine-learning and the qemu VM. Jellyfin transcodes on the iGPU, so
it is not directly affected.

## Do not use the paperless AI settings page

**This is the most important thing on this page.** Paperless's `AIConfig`
resolves each field as *DB value or env value* (`paperless/config.py`) — the DB
columns start `NULL`, so the Nix-managed env vars apply until someone edits
Settings → AI in the paperless web UI. That write goes straight to
`/srv/paperless/db.sqlite3` and from then on **silently and permanently**
outranks `modules/paperless.nix`. `nixos-rebuild` cannot correct it — there is
no declarative reset short of deleting the row by hand.

Treat that settings page as read-only. All AI configuration lives in
`modules/paperless.nix`.

## Why long documents are fine

Paperless hard-caps classifier input at 4000 characters
(`paperless_ai/ai_classifier.py`, `document.content[:4000]`) — no env var
changes this. The real prompt sent for tagging is short regardless of document
length, which is what makes ~115 s/doc CPU inference tolerable.

This cap is specific to tagging/classification. The **embedding index still
covers full documents**, for the separate chat/RAG feature — that's a
different code path (`indexing.py`) and is why `embeddinggemma` exists
alongside the classifier model.

## Timeout budget

Because classification is synchronous, a request crosses three timeout layers.
It only succeeds if inference finishes inside **all** of them:

| Layer | Limit | Set where |
| ----- | ----- | --------- |
| Cloudflare edge | **100 s** | Not configurable below Enterprise |
| nginx `proxy_read_timeout` | 600 s | `mkProxiedService` `extraConfig`, this repo |
| `PAPERLESS_AI_LLM_REQUEST_TIMEOUT` | 600 s | `modules/paperless.nix` |

nginx defaults to 60 s here — `modules/nginx.nix` sets
`recommendedProxySettings = true` with no `proxyTimeout` override — so without
the vhost `extraConfig` every request would 504 at 60 s. It is raised to match
the paperless timeout so that paperless's own error surfaces rather than a
generic gateway error.

**The binding constraint is Cloudflare's 100 s.** `*.greensroad.uk` resolves to
Cloudflare even on the tailnet (no split-horizon DNS — see
`docs/networking.md`), so every route to paperless crosses that edge. Against
an estimated ~115 s/document this is marginal at best: expect a 524 unless real
inference lands under ~100 s.

If it does not, the options are a smaller classifier model (`gemma3:1b`,
roughly 30 s, lower tag quality), a remote model via OpenRouter (~3 s, fits
easily), or accepting that the suggestions button is unusable and keeping only
the embedding half. Measure before choosing.

Results are cached for 50 minutes per document and backend
(`set_llm_suggestions_cache`, `documents/caching.py`), so the cost is paid once
per document rather than once per page view — but only the request path writes
that cache, so the first click always pays in full.

## CPU containment

`systemd.services.ollama.serviceConfig.CPUWeight = 20` is a proportional
share, not a hard cap — it costs nothing when the box is idle and only yields
under contention with OCR/immich/the VM. A hard `CPUQuota` was rejected: it
would pay a permanent ~2x slowdown to solve a problem that's occasional.

`AllowedCPUs = "0-2"` matters independently of `CPUWeight`: llama.cpp
busy-waits every worker thread in a barrier, so running it across all 4 cores
starves the scheduler regardless of cgroup weight. Ollama exposes no
thread-count environment variable (`OLLAMA_NUM_THREADS` does not exist), so the
cpuset is the lever — cgroup v2 constrains `sched_getaffinity`, and ollama
sizes its own thread pool from that. Costs ~15% inference speed in exchange for
keeping one core schedulable.

Neither setting touches **memory bandwidth**. Inference saturates the single
DDR5 channel, which the iGPU also uses — heavy tagging can still nudge a
Jellyfin transcode. There's no cgroup control for this.

## Admin password

`services.paperless.passwordFile` is gone — the admin account is created
once via:

```
paperless-manage createsuperuser
```

Safe to drop because `/srv` is its own ZFS dataset (`zroot/srv`), outside the
impermanence wipe, so `/srv/paperless/db.sqlite3` (and the admin user in it)
survives reboots and rebuilds. Only a deliberate `zfs destroy zroot/srv` would
require re-running the command.

## Deploying this change

Adding `/var/lib/private/ollama` to `environment.persistence."/persist"`
means a plain `nixos-rebuild test` would start the bind mount live under a
running service. This change needs:

```
sudo nixos-rebuild boot --flake .#thor
```

followed by a reboot — not `test`. Doing it as a boot+reboot also means
`loadModels` pulls the ~4 GB of models directly into the persisted location,
rather than downloading them once pre-reboot and again after.
