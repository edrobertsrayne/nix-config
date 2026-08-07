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

    services.paperless = {
      enable = true;
      inherit port;
      dataDir = "/srv/paperless";
      consumptionDir = "/srv/paperless/consume";
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_URL = "https://${url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TIME_ZONE = "Europe/London";

        PAPERLESS_AI_ENABLED = true;
        PAPERLESS_AI_LLM_BACKEND = "ollama";
        PAPERLESS_AI_LLM_MODEL = "gemma3:4b";
        PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "ollama";
        PAPERLESS_AI_LLM_EMBEDDING_MODEL = "embeddinggemma:300m";
        # One endpoint var suffices: paperless_ai/embedding.py falls back
        # llm_embedding_endpoint or llm_endpoint.
        PAPERLESS_AI_LLM_ENDPOINT = "http://127.0.0.1:11434";
        # Default is 120s; CPU inference runs ~115s/doc, so failures surface
        # as an opaque LLMTimeoutError right at the default.
        PAPERLESS_AI_LLM_REQUEST_TIMEOUT = 600;
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
