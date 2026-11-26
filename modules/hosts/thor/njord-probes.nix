_: {
  # End-to-end through Cloudflare -> njord's tunnel -> dokploy-traefik, the path
  # users take. A missing dokploy-traefik is invisible to ContainerStopped once
  # the container is gone; this catches it.
  flake.modules.nixos.thor.monitoring.probeTargets = {
    Dokploy = "https://admin.robertsrayne.uk/";
    "Image Slicer" = "https://slicer.robertsrayne.uk/";
  };
}
