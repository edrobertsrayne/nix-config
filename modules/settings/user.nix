{lib, ...}: {
  options.flake.settings.user = with lib; {
    username = mkOption {
      type = types.str;
      default = "ed";
    };
    fullname = mkOption {
      type = types.str;
      default = "Ed Roberts Rayne";
    };
    email = mkOption {
      type = types.str;
      default = "ed.rayne@gmail.com";
    };
    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0EYKmro8pZDXNyT5NiBZnRGhQ/5HlTn5PJEWRawUN1"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvkj8G6AkgmN5qXfnYgXuMAsx4WyHgJ/t6mO8AhOL/Y" # ed@freyja
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW5tgMzPytrfk373U9EfL5ol6No9lIelF6dL8ZYSe0B" # ed@thor
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZULon8h02P35ChHLr/AmVb3L28hbADYU8ZXJkIhIuU" # ed@odin
      ];
    };
  };
}
