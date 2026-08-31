# install.sh — the canonical installer

`install.sh` projects the Nix package and module onto a plain prefix. It is the one file a non-Nix user runs, so it carries the whole contract: what gets installed where, what the system needs first, and how to take it all back out. The template is [`templates/install.sh`](../templates/install.sh); this file is the reasoning behind it.

## Flag grammar

The fixed core, in this order in `--help`:

```
-h, --help           show help and exit
-v, --version        print "<name> x.y.z" (from VERSION) and exit
    --prefix DIR     install prefix (default /usr/local; env PREFIX)
    --destdir DIR    staging root; no live system state is touched (env DESTDIR)
    --uninstall      remove a previous install by its manifest
```

After the core come repo-specific flags, one per install-affecting Nix option. `-f` exists only where a `--force` exists. Value-taking flags guard with `"${2:?value required by $1}"`; unknown flags print usage to stderr and exit 1. `--uninstall` refuses to combine with configuration flags — an uninstall has no configuration.

Booleans are single flags that flip the default, and the installer is **declarative**: each run converges the system to exactly the flags given. Running again without `--fix-discord-voice` removes the sysctl file and restores the saved value, the same way unsetting a Nix option does on rebuild. Say this in `--help` in one sentence; it is a behavior change for anyone used to `--no-x` pairs.

`--help` ends with a `Runtime environment` section listing the env vars the *installed tool* reads (not the installer). Those are the runtime tunables that deliberately did not become flags.

## Layout and the bin entry

Everything lives in `$PREFIX/share/<name>/`: the script(s), the data, the manifest. `$PREFIX/bin/<name>` is a **relative symlink** (`ln -sfn ../share/<name>/<name>.sh`) so the whole prefix can be moved or staged. The script resolves itself through `readlink -f` and finds its data in its own directory — no path substitution at install time for the common case.

When an install flag has to bake an environment default into the entry point (the non-Nix analog of `wrapProgram --set-default`), the symlink becomes a generated wrapper, written with a heredoc whose `\$` are escaped — shellcheck reads that cleanly, where a printf full of literal `${...}` needs a disable comment:

```sh
cat >"$root/bin/<name>" <<EOF
#!/bin/sh
export SOME_VAR="\${SOME_VAR:-$value}"
exec "$share_runtime/<name>.sh" "\$@"
EOF
chmod 755 "$root/bin/<name>"
```

The `${VAR:-...}` lands literally, so the user's environment still wins — that is what `--set-default` means. The wrapper is recorded in the manifest like any other file, and the declarative sweep (below) puts the symlink back when the flag is dropped.

**Never silence a linter where a rewrite satisfies it.** The two shapes that come up: `! cmd` under `set -e` skips errexit (SC2251) — write `if cmd; then exit 1; fi`; literal `${...}` in generated scripts (SC2016) — write them via escaped heredocs. A `disable=` comment is a last resort for a rule that is wrong about the code, not a way past a rule that is right.

Repos that render a config with an embedded path (ddlc-hyprlock's `@share@`) substitute the **runtime** path `$PREFIX/share/<name>`, never `$DESTDIR$PREFIX` — DESTDIR is where files land, PREFIX is where they will live. Escape sed replacement metacharacters: `sed 's/[&|\\]/\\&/g'`.

## DESTDIR and --no-systemd

`--destdir` is staging: files land under `${DESTDIR%/}$PREFIX`, and every live action — `systemctl`, `sysctl`, user lookups, ownership — is skipped, along with their preflight entries.

Repos that touch systemd also take `--no-systemd`: a **real** install (files at their final paths) that skips the live `systemctl`/`systemd-analyze` calls. This is what containers and image builds need — DESTDIR is not it, because DESTDIR changes the paths. An explicit flag, not autodetection: a silently degraded install is a lie about what happened. When the preflight finds `systemctl` missing and `/run/systemd/system` absent, its error suggests the flag.

## Preflight — refuse loudly, install nothing

Two dependency classes:

- **install deps** — the installer or the installed artifact cannot exist without them. Any missing ⇒ collect all, print the report, exit 1 having written nothing.
- **session deps** — supplied by the user's live session (hyprctl, rofi, hyprlock, journalctl). Missing ⇒ one warning line each; the install proceeds. A theme for a compositor you have not installed yet is still a valid install.

The report format is machine-readable, and the distro tests depend on it:

```
install.sh: missing dependencies:
  - sing-box (/usr/bin/sing-box)

Install sing-box on Arch:
  $ sudo pacman -S --needed sing-box
```

Every *runnable* remediation line is `two spaces + "$ " + the exact command`. Prose and bare URLs are indented without the `$ `. The distro tests extract the `^  \$ ` lines and run them verbatim (stripping a leading `sudo`) — the printed command is the tested command, so the guidance cannot rot silently.

Per-distro guidance branches on `ID`/`ID_LIKE` from `/etc/os-release` (read, not sourced; honor an `OS_RELEASE` env override so tests can point at fixtures). Rules:

- One recommended method per distro. Arch: official repos and AUR are both official — `$ sudo pacman -S --needed pkg` or `$ paru -S pkg`. Debian/Ubuntu/Fedora without a package: the upstream's own repository as exact `$ ` commands if scriptable, else `$ go install ...@latest` (preceded by the `$ ` line installing go from official packages), else a URL line.
- Never print `-y`/`--noconfirm` in guidance — a human is reading it; the test harness arranges non-interactivity around the command, not inside it.
- The unknown-distro arm prints the generic method or URL, so the script degrades to still-useful on anything.

## Uninstall by manifest

The install writes `$root/share/<name>/install-manifest`:

- first line: `# <name> <version> install manifest`, then one absolute **runtime** path per line (no DESTDIR prefix — the manifest ships inside a staged tree and stays correct);
- written last, after everything it names exists.

`--uninstall`:

1. read the manifest (re-prefixing `${DESTDIR%/}` onto each line when staging), `rm -f` each path;
2. `rmdir --ignore-fail-on-non-empty -p` the parent directories — never `rm -rf` a shared directory like `share/zsh/site-functions`;
3. remove the manifest and the share dir;
4. repos with live state (units to disable, sysctl to restore) undo it before removing files;
5. idempotent: a second `--uninstall` finds nothing and exits 0 quietly.

No manifest found ⇒ fall back to the repo's pre-standard fixed path list, kept for exactly one release and marked with a comment saying when it goes.

skvpn's `managed` marker keeps its separate meaning — "refuse to overwrite files this installer did not write" — that is about *install* safety, and the manifest does not replace it.

## Self-checks the repo must carry

- `tests/run.sh` (or `scripts-lint`) asserts `--help` names every flag the `case` parses, and `-v` output equals `<name> $(cat VERSION)`.
- The completions drift check ([completions.md](completions.md)) fails when a flag exists in `install.sh` but not in both completion files.
- The refusal path is tested: a machine missing an install dep gets a report naming *all* missing deps (not just the first), and nothing is written.
