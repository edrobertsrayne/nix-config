{inputs, ...}: let
  inherit (inputs.self.settings) server ports;
  url = "paperless.${server.domain}";
  port = ports.paperless;
in {
  flake.modules.nixos.paperless = {
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

    # CPU-only local AI tagging (no GPU on thor; iGPU is committed to VAAPI).
    # See docs/paperless-ai.md for the operational detail.
    services.ollama = {
      enable = true; # binds 127.0.0.1:11434 by default
      loadModels = [
        "embeddinggemma:300m" # embeddings, paperless's own default
        "gemma3:4b" # classification; beats paperless's llama3.1 default (8B, ~2x slower here, no tagging-quality gain)
      ];
    };

    systemd.services.ollama.serviceConfig = {
      CPUWeight = 20; # soft priority: full speed when idle, yields under contention
      # llama.cpp busy-waits every worker thread in a barrier, so spanning all
      # 4 cores starves the scheduler whatever CPUWeight says. Ollama has no
      # thread-count env var; the cpuset is the lever — cgroup v2 restricts
      # sched_getaffinity, so ollama sizes its thread pool to 3 on its own.
      AllowedCPUs = "0-2";
      MemoryHigh = "6G";
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
    # Suggestions run inline in the HTTP request, and every route to paperless
    # crosses Cloudflare (no split-horizon DNS), which hard-caps a request at
    # 100s. That rules out slow models whatever the paperless-side timeout says.
    services.paperless = {
      enable = true;
      inherit port;
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
