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
        # No probePath: no unauthenticated health endpoint; root 302s to login.
      })
    ];

    # Local generation only viable with the iGPU (OLLAMA_IGPU_ENABLE below).
    # gemma4:e2b: fastest benchmarked (elastic MatFormer, ~2B active despite
    # 5.1B on disk) — clears Cloudflare's 100s cap, gemma4:latest/12b don't.
    #
    # loadModels only adds, never prunes — hand-pulled models persist until
    # `ollama rm`.
    services.ollama = {
      enable = true; # binds 127.0.0.1:11434 by default
      loadModels = ["embeddinggemma:300m" "gemma4:e2b"];
      package = pkgs.ollama-vulkan;
      environmentVariables = {
        OLLAMA_IGPU_ENABLE = "1";
      };
    };

    systemd.services.ollama.serviceConfig = {
      CPUWeight = 20; # yield to OCR's celery work, same trigger
      # llama.cpp barrier-waits every thread, starving the scheduler
      # regardless of CPUWeight; no thread-count env var, so cap via cpuset.
      AllowedCPUs = "0-2";
    };

    # Classification is on-demand (Suggest button) only; auto-tagging uses
    # the separate scikit-learn classifier, no LLM.
    services.paperless = {
      enable = true;
      inherit port;
      address = "0.0.0.0"; # tailnet client, per docs/networking.md
      dataDir = "/srv/paperless";
      consumptionDir = "/srv/paperless/consume";
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_URL = "https://${url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TIME_ZONE = "Europe/London";
        PAPERLESS_AI_ENABLED = "true";
        PAPERLESS_AI_LLM_BACKEND = "ollama";
        PAPERLESS_AI_LLM_MODEL = "gemma4:e2b";
        PAPERLESS_AI_LLM_ENDPOINT = "http://127.0.0.1:11434";
        PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "ollama";
        PAPERLESS_AI_LLM_EMBEDDING_MODEL = "embeddinggemma:300m";
        PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT = "http://127.0.0.1:11434";
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
