+++
title = "Two GitHub Annoyances I Fixed So You Don't Have To — Part 1"
date = 2023-06-27
path = "blog/two-github-annoyances-part1"
template = "static-page.html"

[extra.social_media_image]
path = "../cover.png"
alt_text = "GitHub Octocat mascot"
+++

GitHub is the best place to host code, but it has blind spots — small things that have been broken or missing for years, probably because they affect a minority of users and don't make enough noise to warrant a fix. I ran into two of them and ended up building a tool for each.

Neither is a world-changing project. They're small, focused, and solve exactly one problem each. But they've made my daily workflow noticeably better, and if you've hit the same issues, they might help you too.

## Problem 1: GitHub shows the wrong language for your repo

You know that colored dot and language label on every repository card? The one that says "Rust" or "TypeScript" or "Python"? It's computed by a Ruby library called [github-linguist](https://github.com/github-linguist/linguist), and its algorithm is brutally simple: count bytes per language, the highest wins.

This works great for large projects where source code dominates. But for small projects — especially ones with a handful of source files and a disproportionately large stylesheet — it produces a misleading label. I've seen repos whose actual product is a Rust binary get labelled as SCSS or CSS because the theme files happened to be more verbose than the Rust source.

There's no GitHub setting to pin the main language. You can't tell it "no, this is a Rust project." The label is always the byte-weighted winner. The only way to influence it is to manipulate the inputs to the byte count.

The existing workarounds are all bad:

- Mark your stylesheets as `linguist-vendored=true` — lies about file provenance, hides them from the language bar entirely
- Mark them `linguist-generated=true` — same lie, different framing
- Set `linguist-detectable=false` — hides the language but at least doesn't lie — still, you lose the visibility
- Force everything to count as Rust with `* linguist-language=Rust` — breaks syntax highlighting and code search

None of these preserve an honest language mix while shifting the leader. So I built [linguist-ballast](https://github.com/bilbilak/linguist-ballast).

### The ballast technique

The idea is simple: add a single file in the desired language, placed somewhere the build system never sees but GitHub Linguist still counts. The file is filled with valid but meaningless declarations — structs, constants, type aliases — sized to tip the byte count just enough for your target language to overtake the current leader.

The placement is deliberate. The file goes in `.github/linguist-ballast.<ext>` because:

- `.github/` is in Linguist's default vendored-path list, so it's ignored by default — the file only counts because of an explicit `.gitattributes` override (`linguist-ballast.* linguist-vendored=false`)
- `.github/` is conventionally excluded from `git archive`, Docker build contexts, and CI artifact uploads, so the ballast never ships anywhere
- `.github/` is outside every language ecosystem's source tree, so compilers and bundlers never see it

The `.gitattributes` override re-enables Linguist counting for exactly this one file, and nothing else changes.

### The delta script

Figuring out how many bytes you need is tedious — you have to check the GitHub API for both languages, subtract, and add one. So `linguist-ballast` ships a bash script that does it for you:

```bash
linguist-ballast-delta.sh --lang Rust --repo bilbilak/linguist-ballast
```

Output:

```
Repository:        bilbilak/linguist-ballast
Current top:       SCSS (19513 bytes)
Desired top:       Rust (11807 bytes)

Ballast bytes:     7707
```

The script reads the live GitHub API (`gh api repos/<owner>/<repo>/languages`), which returns the same filtered numbers GitHub uses to render the language bar. A naive `git ls-files | wc -c` would miss the vendor/generated/documentation filters that Linguist applies, so only the live API is accurate.

### Why this matters

The ballast technique is the only option that preserves an honest language breakdown while shifting the leader. The language bar still accurately shows "Rust 64% / SCSS 36%" — Rust just wins now. Syntax highlighting, code search, diff labels, and third-party tooling all continue to work correctly because the ballast file is real, compilable code in the target language.

The project includes ready-to-use sample files for Rust, TypeScript, Go, Python, and more in `samples/`, along with a planned generator that will produce ballast files at any required byte size on demand. There's also a CI integration planned — similar to Dependabot — that opens a PR when the ballast needs resizing.

---

[Continue to Part 2 →](@/blog/two-github-annoyances/part2/index.md)
