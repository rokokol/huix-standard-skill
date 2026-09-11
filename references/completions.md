# Tab completion for install.sh

Two files, sourced from the checkout — an installer is run from the repo, so its completions are not installed anywhere:

```
completions/install.sh.bash    source completions/install.sh.bash
completions/install.sh.zsh     source completions/install.sh.zsh
```

Templates: [`templates/completions/`](../templates/completions/). What a completion file must look like — builtins only, a guarded `compopt`, a `while IFS= read -r` loop rather than `mapfile`, `# shellcheck shell=bash` on the bash file, a zsh file that registers itself with `compdef` so `./install.sh` completes too — is the [bash-best-practices](https://github.com/rokokol/bash-best-practices-skill) skill's, in its `references/completions.md`, and is not repeated here. The README's "Any other distribution" section shows the two `source` lines

If the repo also ships completions for the tool itself (most do), those stay separate files installed to `share/bash-completion/completions/` and `share/zsh/site-functions/` — the installer records them in the manifest like everything else. When a tool flag gains a short form (`-f` for `--force`), both of the tool's completion files update in the same commit

## Hand-written on purpose, drift-checked by machine

The flag lists are hand-written — a generated completion is only as good as the `--help` parser generating it, and the family already keeps hand-written command lists honest by testing them. The checker is that skill's `check-sh.sh`, vendored into the repo through the ci skill's cascade and wired into the flake's `scripts-lint` check as `./check-sh.sh -c completions/install.sh.bash completions/install.sh.zsh install.sh`: every flag `install.sh` parses must appear in both files as a whole token, every `--flag` a completion offers must be parsed by `install.sh`, and a run that extracts zero flags is a refusal rather than a pass. The same call holds the installer's help to its flags and exit codes

Falsifiability: when wiring the checker into a repo, run it once against a deliberate mismatch (add a fake flag to a copy of install.sh) and watch it fail; the checker's job is proven by that red run, not by the green one
