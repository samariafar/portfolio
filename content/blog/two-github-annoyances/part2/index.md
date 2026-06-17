+++
title = "Two GitHub Annoyances I Fixed So You Don't Have To — Part 2"
date = 2023-06-27
path = "blog/two-github-annoyances-part2"
template = "static-page.html"

[extra.social_media_image]
path = "../cover.png"
alt_text = "GitHub Octocat mascot"
+++

[← Part 1](@/blog/two-github-annoyances/part1/index.md)

## Problem 2: Relative links in community health files don't travel

GitHub lets you define default community health files — `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue templates, and so on — in a special `.github` repository. Every repo in your organization inherits them automatically. It's a great feature: one set of files, hundreds of repos.

Except for the links inside them.

If you write `[Report Bug](https://github.com/bilbilak/repath/issues/new)` in your SECURITY.md, that link works in the bilbilak/repath repo but points to the wrong place when someone views it in a fork. If you write `[Report Bug](./issues/new)` (relative link), it resolves relative to the URL of the file on GitHub — which, for shared community files, is often the `.github` repository itself, not the repo the user is actually looking at. Forks and mirrors make it worse: absolute URLs are permanently wrong, and relative ones don't travel.

I spent a while looking for a solution and couldn't find one. So I built [Repath](https://repath.to).

### How Repath works

Repath is a Cloudflare Worker (about 110 lines of TypeScript) that provides referrer-based URL redirection. It turns a static link into a dynamic one that resolves based on where the user came from.

Here's the real-world example from my organization's SECURITY.md:

```markdown
[private vulnerability reporting](https://repath.to/security/advisories)
```

When a user clicks that link from any Bilbilak repo's SECURITY.md, their browser sends a `Referer` header containing the page they were on — say, `https://github.com/some-user/repath/blob/main/docs/SECURITY.md`. Repath parses that URL, extracts the path segments, and resolves the target based on the `from` parameter.

For GitHub repos, you almost always want `from=2` — take the first two path segments (owner and repo):

```
https://repath.to/security/advisories?from=2
```

- Referer: `https://github.com/some-user/repath/blob/main/docs/SECURITY.md`
- Segments: `["some-user", "repath", "blob", "main", "docs", "SECURITY.md"]`
- `from=2` → base = `["some-user", "repath"]`
- Redirect target: `https://github.com/some-user/repath/security/advisories`

The same link also works from a Codeberg mirror:

- Referer: `https://codeberg.org/some-user/repath/src/branch/main/README.md`
- `from=2` → base = `["some-user", "repath"]`
- Redirect target: `https://codeberg.org/some-user/repath/security/advisories`

One link, works everywhere.

### The `from` parameter

Repath supports several resolution strategies:

| `from` | Behaviour | Example result |
|--------|-----------|----------------|
| (omitted) / `current` | Keep full referer path | `https://github.com/user/repo/blob/main/docs/issues` |
| `root` | Drop everything | `https://github.com/issues` |
| `parent` | Remove last segment | `https://github.com/user/repo/blob/main/issues` |
| `2` (or any N) | Take first N segments | `https://github.com/user/repo/issues` |
| `-1` (negative N) | Drop last N segments | `https://github.com/user/repo/blob/issues` |

The worker is deployed at [repath.to](https://repath.to) on Cloudflare Workers, with security headers that prevent indexing (`X-Robots-Tag: noindex`) and caching (`Cache-Control: no-store`), since every redirect needs to read a fresh `Referer` header.

### The bigger picture

This isn't just about GitHub community health files. Repath is a general-purpose referrer-relative URL service. Any situation where you need a link to resolve differently depending on the referrer — multi-forge documentation, cross-repo links in monorepos, context-aware navigation — Repath handles it.

## Why I built these instead of waiting

Neither of these is a bug in GitHub. They're design gaps that affect a specific subset of users in specific circumstances. The Linguist algorithm is reasonable as a general heuristic — byte count usually does pick the right language. The community health file system is a net positive for everyone, even if the link problem is annoying.

But the workarounds were trivial to build. `linguist-ballast` is a bash script and some sample files. Repath is 110 lines of TypeScript deployed on a free Cloudflare Workers plan. Each took an afternoon to ship and has been saving me time weekly ever since.

Sometimes the right response to a platform gap isn't to file a feature request and wait — it's to build the 100-line fix yourself and move on.

Both projects are open source:

- [linguist-ballast](https://github.com/bilbilak/linguist-ballast) — ballast files, delta script, and planned generator/CI
- [repath](https://github.com/bilbilak/repath) — source code and deployment config
