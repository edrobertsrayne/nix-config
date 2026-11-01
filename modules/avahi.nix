_: {
  flake.modules.nixos.avahi = {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      settings.publish = {
        disable-publishing = false;
        disable-user-service-publishing = false;
        publish-addresses = true;
        publish-domain = true;
        publish-hinfo = true;
        publish-workstation = true;
      };
    };
  };
}
