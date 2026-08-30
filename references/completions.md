# Tab completion for install.sh

Two files, sourced from the checkout — an installer is run from the repo, so its completions are not installed anywhere:

```
completions/install.sh.bash    source completions/install.sh.bash
completions/install.sh.zsh     source completions/install.sh.zsh
```

Templates: [`templates/completions/`](../templates/completions/). Both are written to survive minimal environments: the bash file uses only builtins (no bash-completion package — `compopt` is guarded), the zsh file defines its function and calls `compdef` itself (no fpath, no rehash; zsh's dispatch falls back to the command basename, so `./install.sh` completes too). The README's "Any other distribution" section shows the two `source` lines.

If the repo also ships completions for the tool itself (most do), those stay separate files installed to `share/bash-completion/completions/` and `share/zsh/site-functions/` — the installer records them in the manifest like everything else. When a tool flag gains a short form (`-f` for `--force`), both of the tool's completion files update in the same commit.

## Hand-written on purpose, drift-checked by machine

The flag lists are hand-written — a generated completion is only as good as the `--help` parser generating it, and the family already keeps hand-written command lists honest by testing them. The checker is [`templates/tests/check-completions.sh`](../templates/tests/check-completions.sh), copied to `tests/check-completions.sh` and wired into the flake's `scripts-lint` check:

- every flag in install.sh's `case` patterns must appear in **both** completion files;
- every `--flag` a completion offers must be parsed by install.sh;
- the extractor refuses to pass when it finds zero flags — a broken regex must not read as "no drift".

Falsifiability: when wiring the checker into a repo, run it once against a deliberate mismatch (add a fake flag to a copy of install.sh) and watch it fail; the checker's job is proven by that red run, not by the green one.
