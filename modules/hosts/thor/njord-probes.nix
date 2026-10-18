_: {
  # End-to-end through Cloudflare -> njord's tunnel -> dokploy-traefik, the
  # path users take. A missing or stopped dokploy-traefik is invisible to
  # ContainerStopped once the container is gone; this is what caught it (#223).
  flake.modules.nixos.thor.monitoring.probeTargets = {
    Dokploy = "https://admin.robertsrayne.uk/";
    "Image Slicer" = "https://slicer.robertsrayne.uk/";
  };
}
