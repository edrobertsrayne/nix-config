# Deploying changes

How a change to this repo becomes a change on thor, and how to undo one.

thor's entire configuration is this git repo. There is no state on the machine
that you edit directly — no `/etc/nginx/nginx.conf` to tweak, no `apt install`.
You change a `.nix` file, build it, and the machine becomes what the file says.
That is the whole model, and it is why undoing a change is a menu option at boot
rather than an archaeology exercise.

## The loop

```sh
cd ~/config
$EDITOR modules/some-service.nix        # 1. change something
nix flake check                         # 2. does it evaluate?
sudo nixos-rebuild test --flake .#thor  # 3. build it and turn it on
git commit -am "feat: ..."              # 4. keep it
```

Step 2 catches typos and type errors without building anything, in seconds.
Step 3 is where the real work happens: Nix builds every package the new
configuration needs, then activates it.

**mimir (#203) is a second `nixosConfiguration`, not a service inside thor's,
but it does not deploy like one.** mimir is a microvm.nix guest that shares
thor's `/nix/store` read-only over virtiofs and does not run `nix-daemon`, so
neither `nixos-rebuild switch --flake .#mimir` on mimir itself nor
`--target-host` from thor can land a closure there — both fail, the latter
with a misleading local-looking error. Deploy mimir with microvm.nix's own
host-side CLI instead, from thor: `sudo microvm -R -u mimir`. See
[`modules/hosts/mimir/README.md`](../modules/hosts/mimir/README.md#deploying-config-changes)
for the full explanation and command reference.

### Choosing `test`, `switch`, or `boot`

These three verbs are the only meaningful difference between deploys. They vary
along two axes: does it take effect *now*, and does it survive a *reboot*.

| Verb | Active now? | Boot default? | Use it when |
|---|---|---|---|
| `test` | yes | **no** | You want to try the change. If it breaks something, reboot and the machine returns to the last good configuration. |
| `switch` | yes | yes | You have decided on the change and want it to stick. |
| `boot` | no | yes | The change only takes effect on reboot anyway — a new kernel, initrd, or bootloader setting. |

`test` is the cautious option and costs nothing but remembering to run `switch`
(or commit and let the nightly upgrade do it) once you are happy. `switch` is
the normal option for a change you are confident in. Neither is wrong; the only
mistake is `test`-ing something, walking away, and being surprised when a reboot
reverts it.

A fourth verb is worth knowing:

```sh
nixos-rebuild dry-build --flake .#thor   # build nothing, just prove it evaluates and would build
```

No `sudo` needed, and it never touches the running system.

### Deploying from another machine

```sh
nixos-rebuild switch --flake github:edrobertsrayne/nix-config#thor \
  --target-host thor --use-remote-sudo
```

## Before you commit

The repo formats and lints itself. `direnv` loads a devenv shell
(`devenv.nix`) that installs git hooks:

| Hook | What it does |
|---|---|
| `alejandra` | The Nix formatter. Rewrites your file to canonical style. |
| `statix` | Flags redundant Nix idioms. |
| `deadnix` | Flags unused bindings and arguments. |

If a commit is rejected, the hook has usually already fixed the file — `git add`
and commit again. To format by hand: `nix fmt`.

On a pull request, `.github/workflows/nix-flake-check.yaml` runs `nix flake
check` and `nix-fmt.yaml` formats and commits back. Neither builds the system,
so a green PR proves the config evaluates, not that it works.

## Undoing a change

Every build you activate is kept as a *generation* — a complete, immutable
snapshot of the system. thor keeps the last five
(`boot.loader.systemd-boot.configurationLimit`, `modules/hosts/thor/thor.nix`).

List them:

```sh
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Three ways back, in increasing order of severity:

```sh
# 1. You ran `test` and it went wrong — just reboot. The bootloader still
#    points at the previous generation.
sudo reboot

# 2. You ran `switch` and it went wrong — go back one generation.
sudo nixos-rebuild switch --rollback

# 3. The machine won't boot — at the systemd-boot menu, pick an older
#    generation from the list. This is the reason `configurationLimit` exists,
#    and the reason it is not 1.
```

If the box is unreachable and you cannot see the boot menu over SSH, that is
what the PiKVM is for — see [troubleshooting.md](troubleshooting.md).

The safety net is five generations deep and only covers *configuration*. It does
not roll back data — see [storage.md](storage.md) for what does.

## The nightly upgrade

thor upgrades itself. `modules/nix.nix` sets:

```nix
system.autoUpgrade = {
  enable = true;
  flake = "github:edrobertsrayne/nix-config";
  dates = "04:00";
  allowReboot = true;
};
```

**Anything merged to `main` is live on thor within a day, and the machine may
reboot itself to get there.** That is deliberate — the rationale is in the
comment above that block — but it has two consequences worth internalising:

- A change is not "not deployed yet" just because you did not run
  `nixos-rebuild`. Merging *is* deploying, on a delay.
- Because it pulls from GitHub, an unpushed local commit is not what runs at
  04:00. A `test`-ed local change that was never committed will be silently
  replaced by whatever `main` says.

You can see the effect in the generation list: generations timestamped `04:0x`
are the auto-upgrade's, not yours.

## Disk housekeeping

Old generations and unreferenced packages accumulate. Three things clean up
automatically:

| Mechanism | Schedule | What |
|---|---|---|
| `nix.gc` (`modules/nix.nix`) | weekly | Deletes generations older than 7 days |
| `nix.optimise` | automatic | Hard-links identical files in the store |
| `nh clean` (`modules/utilities/nh.nix`) | daily | Keeps 3 generations / 5 days |

To reclaim space immediately:

```sh
sudo nix-collect-garbage --delete-older-than 7d
```

Note that this deletes the generations you would otherwise roll back to. Do not
run it as a reflex right after a risky deploy.

### The `nh` gotcha

`nh` is a friendlier `nixos-rebuild` wrapper, and `modules/utilities/nh.nix`
sets `programs.nh.flake = "github:edrobertsrayne/nix-config"`. That means a bare
`nh os switch` **builds from GitHub, not from your working copy** — your
uncommitted edits are ignored, silently. To build the local checkout, pass the
path:

```sh
nh os test ~/config      # or: nh os switch ~/config
```

When in doubt, use `nixos-rebuild --flake .#thor`, which is unambiguous.

## Adding a service

Most services are a single file in `modules/`, picked up automatically —
`import-tree` loads every git-tracked `.nix` file under `modules/`, so there is
no import list to update. **A new file must be `git add`-ed before it will
load**, which is the most common "why is nothing happening" moment.

Two helpers do the repetitive work:

- **`mkProxiedService`** (`modules/lib/proxy.nix`) — one call gives the service
  an nginx vhost at `<subdomain>.greensroad.uk`, a tile on Homepage, and a
  blackbox HTTP probe that alerts if it stops answering. Pass `probePath` if the
  service has a health endpoint; probing `/` only proves something is listening.
  `host` defaults to `127.0.0.1`. Override it when the service does not run
  on the same host as nginx (see below).
- **`mkArr`** (`modules/lib/servarr.nix`) — wires the \*arr apps' API key
  secret, disables local authentication, and puts the service user in the
  `tank` group so it can write the shared media trees. It does **not** call
  `mkProxiedService`. The vhost is a separate module (below).

Ports go in `modules/settings/ports.nix`, which is the single source of truth —
never hard-code a port in a service module. Read `modules/searxng.nix` for a
minimal example and `modules/downloads/radarr.nix` for the servarr pattern.

### Same-host vs. cross-host services

`flake.modules.nixos.<name>` lands on a host only if that host's own module
imports it, or if it is in `common`, which every host gets. A service module
and its `mkProxiedService` vhost are two independent things. They usually
live in the same file and get imported together onto the same host, but
nothing stops them from splitting across hosts. nginx runs only on thor.

For a service that runs on another host — mimir, so far, for the download
stack moved there in #203 — define two separate flake modules in the file,
instead of one:

```nix
flake.modules.nixos.radarr = inputs.self.lib.mkArr { ... };

flake.modules.nixos.radarr-proxy = inputs.self.lib.mkProxiedService {
  ...
  host = inputs.self.settings.hosts.mimir.address;
};
```

The service module goes on the host that runs it, through that host's own
imports (for example, mimir's `downloads` group). The `-proxy` module goes on
thor, grouped with its siblings alongside the group it mirrors (for example,
`downloads-proxy` sits next to `downloads` in
`modules/downloads/downloads.nix`) and imported from `thor.nix`.

Getting this wrong is a silent failure, not a build error. The service
module still evaluates fine on the host that runs it. It just never gets an
nginx vhost anywhere. The `mkProxiedService` call still evaluates fine if you
place it on the wrong host. It just proxies to a backend that is not there.
Confirm that thor actually imports the `-proxy` module, not only that some
host imports the service module.

**Addressing a cross-host backend:** prefer a static LAN IP
(`inputs.self.settings.hosts.mimir.address`, `modules/settings/hosts.nix`)
over a Tailscale hostname, when the two hosts already share an L2 segment
(mimir's tap interface is bridged into thor's own `br0`). `nginx`'s
`proxyPass` resolves a hostname only once, at config-load, because no
`resolver` directive is configured. A Tailscale name is one extra moving part
for no benefit here. See [networking.md](networking.md) for the full
rationale and the firewall rule that must accompany it.

## Secrets

Credentials are encrypted into the repo with [agenix](https://github.com/ryantm/agenix)
and decrypted on thor at activation into `/run/agenix/`. Never commit a
plaintext credential.

The full workflow — creating, editing, re-keying, and the several ways to hand
a secret to a service — is documented in
[`.claude/skills/secrets/SKILL.md`](../.claude/skills/secrets/SKILL.md). It
lives there because it is also the instruction set the coding agent follows;
keeping one copy means it cannot drift from what actually gets done.

The two things that catch everyone out are in that document's troubleshooting
table: you must `cd secrets` first, and you should always decrypt a secret
after writing it to prove it is not empty.
