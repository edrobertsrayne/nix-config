{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "paperless.${server.domain}";
  port = ports.paperless;
in {
  flake.modules.nixos.paperless = {pkgs, ...}: {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Paperless";
        subdomain = "paperless";
        inherit port;
        group = "Productivity";
        description = "Document management";
        icon = "paperless-ngx.png";
        # No probePath: paperless-ngx has no unauthenticated health endpoint.
        # The root URL 302s to /accounts/login/ and the probe follows it.
      })
    ];

    # Embeddings only. Classification runs on a remote model — no GPU on thor
    # and the iGPU is committed to VAAPI, so 4B-class generation on the
    # Gracemont cores took ~115s/doc, past Cloudflare's 100s request cap.
    # A 300M embedding pass is a single forward pass and stays local.
    #
    # Keeping an embedding backend set is not just for chat: ai_classifier.py
    # picks build_prompt_with_rag over build_prompt_without_rag whenever one
    # exists, so the Suggest button sends the 5 nearest documents as few-shot
    # context. That is the main quality lever on suggestions — without it the
    # model invents tag names absent from the library.
    #
    # loadModels only ever adds; it never prunes. Models pulled by hand stay
    # in the persisted store until `ollama rm`.
    services.ollama = {
      enable = true; # binds 127.0.0.1:11434 by default
      loadModels = ["embeddinggemma:300m"]; # paperless's own default
      package = pkgs.ollama-vulkan;
      environmentVariables = {
        OLLAMA_IGPU_ENABLE = "1";
      };
    };

    systemd.services.ollama.serviceConfig = {
      # Indexing is async celery work fired by the consumption handler, so it
      # runs exactly when OCR does. Both settings are about yielding to that,
      # not about inference latency — nothing here is user-facing.
      CPUWeight = 20; # soft priority: full speed when idle, yields under contention
      # llama.cpp busy-waits every worker thread in a barrier, so spanning all
      # 4 cores starves the scheduler whatever CPUWeight says — a bulk
      # re-index walks the whole library, not one document. Ollama has no
      # thread-count env var; the cpuset is the lever — cgroup v2 restricts
      # sched_getaffinity, so ollama sizes its thread pool to 3 on its own.
      AllowedCPUs = "0-2";
    };

    # Scope of paperless's built-in AI, as of 3.0.4:
    #   - Classification is on-demand only. get_ai_document_classification has
    #     exactly one caller — the `ai_suggestions` action in
    #     documents/views.py — which is the Suggest button in the document
    #     editor. Nothing calls it on consumption, so there is no automatic AI
    #     tagging. Automatic tagging is the scikit-learn DocumentClassifier
    #     instead: set a tag's matching algorithm to Auto and it learns from
    #     the already-tagged corpus. No LLM involved.
    #   - Embedding indexing is automatic, via the consumption signal handler.
    # Suggestions run inline in the HTTP request, so they're bound by the same
    # Cloudflare 100s cap noted above.
    services.paperless = {
      enable = true;
      inherit port;
      # address stays 0.0.0.0, not 127.0.0.1 (the module default), so the
      # tailnet can reach <tailscale-ip>:${toString port} directly — same
      # reasoning as immich.nix (#174). No openFirewall: the bind address
      # plus tailscale0 being a trusted interface (tailscale.nix) is the
      # boundary. LAN (br0) still can't reach this port, only loopback
      # (nginx) and the tailnet can. Paperless's own login is the only gate
      # on that path — Cloudflare Access never sees tailnet-direct traffic.
      address = "0.0.0.0";
      dataDir = "/srv/paperless";
      consumptionDir = "/srv/paperless/consume";
      consumptionDirIsPublic = true;
      # No PAPERLESS_AI_* here on purpose. paperless/config.py resolves every
      # AI field as `app_config.<x> or settings.<X>` — the DB column wins
      # whenever it is non-empty. Columns start NULL, so env vars do seed a
      # fresh install, but the first save on Settings → AI writes them all and
      # from then on nixos-rebuild cannot reach them. Ours are already written,
      # so declaring them here would only look authoritative. Read live state:
      #   sqlite3 /srv/paperless/db.sqlite3 \
      #     'select llm_backend, llm_model, llm_endpoint from paperless_applicationconfiguration;'
      #
      # Scoped to AI: the OCR columns below are equally overridable, but
      # nothing edits Settings → OCR, so declaring them is not a fiction.
      settings = {
        PAPERLESS_URL = "https://${url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TIME_ZONE = "Europe/London";
      };
      # Admin password now set via `paperless-manage createsuperuser` instead.
    };

    environment.persistence."/persist".directories = [
      "/var/lib/redis-paperless"
      # ollama runs DynamicUser with StateDirectory=ollama, so the real path
      # is /var/lib/private/ollama; /var/lib/ollama is just a symlink to it.
      "/var/lib/private/ollama"
    ];
  };
}
