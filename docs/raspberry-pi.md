# Raspberry Pi 5 bootstrap image

`nixosConfigurations.rpi5` (`modules/hosts/rpi5/rpi5.nix`) builds an SD image
for a Raspberry Pi 5. It is a **holding config**, not a real host: no agenix,
no impermanence, no re-keyed secrets. Its only job is to get a Pi onto the
network with your normal shell tools so a proper host config can be written
against a machine you can already reach. See issue #132 for why (external
monitoring for thor).

It deliberately does not use `flake.lib.mkNixosSystem` — that pulls in
agenix-backed user passwords and the Tailscale authkey via `common`, none of
which can be decrypted before the Pi's host key exists and
`secrets/secrets.nix` is re-keyed for it. Instead:

- Login is SSH-key only (`settings.user.sshKeys`, same list as thor) plus
  console autologin as `ed` — there is no password at all.
- The Tailscale authkey and Wi-Fi credentials are dropped onto the image's FAT
  `FIRMWARE` partition after flashing, not baked into the image or committed
  to git.
- The shell environment (claude-code, neovim/nvf, git, gh, tmux, the rest of
  `modules/utilities/*`) is reused as-is via `home-manager`, `avahi`,
  `locale`, `capslock` — the same aspects thor's `common` pulls in, minus
  everything that needs agenix.

## Build

On thor (needs `boot.binfmt.emulatedSystems = ["aarch64-linux"]`, from
`modules/hosts/thor/binfmt.nix` — apply with `nixos-rebuild test` first if not
already active):

```bash
nix build .#nixosConfigurations.rpi5.config.system.build.sdImage
```

The first build is slow: most of the closure substitutes from
`cache.nixos.org` for aarch64, but `claude-code` is unfree and therefore never
cached, so it compiles under QEMU emulation.

Output: `result/sd-image/*.img.zst`.

## Flash

```bash
zstd -d result/sd-image/*.img.zst -o /tmp/rpi5.img
lsblk                     # identify the SD card - writing erases it
sudo dd if=/tmp/rpi5.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Before first boot, mount the card's `FIRMWARE` partition (FAT, readable from
any OS) and add:

- `tailscale.key` — a reusable, pre-authorized key from the Tailscale admin
  console. Not stored in this repo.
- `wifi.conf` — must exist even for an ethernet-only setup (an empty file is
  fine); the unit that mounts it fails otherwise. For Wi-Fi:

  ```
  country=GB
  network={
    ssid="YourSSID"
    psk=<64-hex, from `wpa_passphrase "YourSSID" "password"`>
  }
  ```

  Use the hex PSK rather than a quoted passphrase to avoid quoting issues.
  `country=GB` matters — without a regulatory domain set the radio stays
  restricted.

## First boot

1. `ping rpi5.local` (avahi).
2. `ssh ed@rpi5.local` — key auth only, no password prompt.
3. `tailscale status` on thor should show `rpi5` as a peer; `ssh ed@rpi5` over
   the tailnet works via Tailscale SSH (`--ssh`).
4. Confirm tool parity: `claude --version`, `nvim`, `eza`, `lazygit`, `tmux`.

If something's wrong, `journalctl -u tailscaled-autoconnect -u wpa_supplicant`.
The two degrade independently: a missing/bad `tailscale.key` only fails
`tailscaled-autoconnect` (`tailscaled` itself keeps running, so
`sudo tailscale up` recovers by hand); a bad `wifi.conf` just leaves ethernet
working.

## Next step

Once reachable, replace this file's `flake.nixosConfigurations.rpi5` with a
real host under `modules/hosts/<name>/`, wired through `mkNixosSystem` like
thor: generate the Pi's `ssh_host_ed25519_key`, add its pubkey to
`secrets/secrets.nix`'s `systems`, re-key
(`cd secrets && nix run github:ryantm/agenix -- -r`), and pick real passwords
via agenix instead of the key-only/no-password setup here.
