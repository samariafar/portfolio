+++
title = "I Fixed the Six Things Git Flow Gets Wrong"
date = 2021-08-17
template = "static-page.html"

[extra.social_media_image]
path = "cover.png"
alt_text = "LoomFlow branching model diagram"
+++

Vincent Driessen's _A Successful Git Branching Model_ — the post that introduced Git Flow — was published in 2010. That's the same year the iPad launched, Instagram was founded, and `go fmt` shipped its first release. In software years, it's ancient history.

Git Flow defined five branch types (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`) and a layered pipeline for cutting releases. It was brilliant for teams shipping versioned desktop software with a QA cycle and a staging environment. Sixteen years later, it's still the branching model I see most often in the wild — and it's showing its age in ways that make daily work harder than it needs to be.

I didn't want to abandon Git Flow. I wanted to fix the specific things about it that grate against modern workflows: automated tooling, rebase-heavy collaboration, structured changelogs, and tight SemVer discipline. So I wrote LoomFlow, a branching model that takes Git Flow's skeleton and sharpens it in six places. The [full specification](@/publications/articles/loomflow.md) runs to a dozen pages; this post covers _why_ each change exists, not the exhaustive details.

## Problem 1: There's nowhere for post-merge fixes to live

You merge a feature to `develop`. A linter bot runs and finds style violations. An integration test reveals that your feature and another feature interact badly. A reviewer leaves a follow-up comment after the merge. Where do those fixes go?

In vanilla Git Flow, the implicit answer is "re-open the feature branch." That's messy — the author considered their work done, the branch might already be deleted, and if it's still open it has drifted from `develop`. It's also the wrong answer for bot-generated fixes: a dependency-update bot has no business modifying a human developer's feature branch.

LoomFlow adds a sixth branch type: `bugfix/{name}`, branched from and merged back into `develop`. It's explicitly for post-integration work — mechanical fixes from bots, integration regressions, non-blocking review follow-ups. A `bugfix/*` branch lives its whole life in a few minutes: branch, commit, open PR, merge, delete. The feature branch stays dead where it belongs.

The rule that stops this from becoming a dumping ground: `bugfix/*` is for fixes _after_ the originating work has merged. If the work isn't complete, it stays on the feature branch. This is enforced at review, not in tooling.

## Problem 2: Release branch naming breaks under SemVer

Git Flow names release branches `release/x.y.z` — full SemVer, patch included. The problem is that a release branch _always_ tags `x.y.0`. Stabilization fixes during the release window don't increment the patch; they produce the same `x.y.0` final tag. Having `z` in the branch name is either misleading (it says `1.4.7` but tags `1.4.0`) or forces you to rename the branch mid-flight.

LoomFlow drops the patch component: `release/1.4`, `release/2.0`. The branch produces `v1.4.0`; the tag moment is when the patch is assigned, not when the branch is created.

Hotfix branches have the reverse problem, and the fix is different. Git Flow names them `hotfix/{x.y.z}` — pre-committing to a specific patch number at branch creation. But multiple hotfixes against the same release can be in flight simultaneously, authored by different people, and their ship order isn't predictable in advance. If you name a branch `hotfix/1.4.2` but another hotfix ships first as `v1.4.1`, your branch has the wrong number baked in.

LoomFlow names hotfix branches by the defect, not the version: `hotfix/auth-token-leak`, `hotfix/csv-parse-crash`. The patch number is assigned at the moment of merge to `main` — when you can actually know what the next available number is.

## Problem 3: Release branches create a shadow develop

In Git Flow, you cut a `release/*` branch from `develop`, make stabilization commits directly on it (version bumps, last-minute fixes, changelog finalization), and then — critically — back-merge those commits from `release/*` into `develop`. Until that back-merge happens, `develop` is missing commits that already shipped to production. Forget the back-merge, and `develop` has bugs you thought you fixed.

LoomFlow inverts this: every change destined for a release is committed on `develop` first (typically via a `bugfix/*` branch) and then **cherry-picked** onto the release branch. Three things follow:

1. `develop` stays the single source of truth — every commit on `main` already exists on `develop`.
2. No back-merge is needed. There's nothing to propagate back.
3. You can't accidentally import in-flight features onto a release branch with a lazy `git merge develop`. The cherry-pick discipline forces you to pick each commit explicitly.

This is the most opinionated rule in LoomFlow and the one people push back on most. Cherry-picks duplicate SHAs, which complicates `git log` output. The counter-argument is that `git log --cherry` handles this reliably, and the alternative — a back-merge you might forget, onto a branch that temporarily has commits `develop` doesn't — is demonstrably more fragile at scale.

## Problem 4: The merge conflict lands on the wrong person

When a long-running feature finally merges into `develop`, the person performing the merge inherits the conflict resolution. That person usually didn't write the feature. They're staring at conflicts in code they've never seen, trying to guess whether the feature or `develop` should win.

LoomFlow prescribes two coupled rules for feature branches:

- **Single author.** One person owns the branch. If the feature is big enough to need multiple contributors, it's big enough to decompose.
- **Rebase sync.** The author rebases onto `develop` periodically during development and again immediately before opening the pull request.

The rebase routes conflict resolution to the author — the person with the smallest cognitive context, the one who actually knows which side should win. The single-author rule makes rebase safe (no co-worker will pull from a branch whose SHAs you just rewrote). Together they mean the final `feature/*` → `develop` merge is clean: no conflicts, no surprises, just the `--no-ff` merge commit.

This is what the literature calls _reverse integration_. LoomFlow uses rebase for it (linear feature history, trivially re-syncable) rather than merge (accumulates back-merge commits on the feature branch, interleaving unrelated `develop` activity with the feature's own narrative). The trade-off — rebase rewrites SHAs — is only acceptable because of the single-author rule.

## Problem 5: Branch deletion destroys information

Every short-lived branch in LoomFlow is deleted after merge. That's a hygiene rule, not an option — zombie branches confuse ownership and clutter listings. But once the branch ref is gone, can you still tell which commits came from which feature?

The answer depends on your merge strategy. Fast-forward merges make the branch's commits indistinguishable from any other commits on `develop`. Squash merges collapse the feature into one commit and destroy the per-commit type signal. Both lose the integration boundary.

LoomFlow mandates `git merge --no-ff` everywhere: `feature/*` and `bugfix/*` into `develop`, `release/*` and `hotfix/*` into `main`, `hotfix/*` into `develop`. The merge commit's auto-generated message ("Merge branch 'feature/auth' into develop") permanently records the branch name in every clone. The sub-commits survive as ancestors. You can answer "which features did contributor X ship last month" long after the branches are gone.

And yes, the commit graph gets busier. `git log --first-parent` collapses it back to the merge-commit spine when you want the high-level summary.

## Problem 6: The conventions live in your head

Git Flow is branch topology. It doesn't tell you how to format commits, how to version releases, or how to maintain a changelog. Every team reinvents these bindings independently, and the result is a mess of `version: 1.0` tags and `Updated stuff` commit messages.

LoomFlow is a contract between five systems — branch topology, commit format, version semantics, changelog structure, and merge mechanics — and it makes the bindings normative:

- **Conventional Commits** for structured commit messages (with optional **gitmoji** prefix for visual scanning)
- **Semantic Versioning** for version derivation from commit types
- **Keep a Changelog** for `CHANGELOG.md` structure
- **`--no-ff` everywhere** for durable integration boundaries

The bindings are practical, not theoretical. Conventional Commits plus SemVer means `standard-version` or `semantic-release` can compute your next version automatically. Keep a Changelog means every release has a human-readable, structured change summary. And because commit format drives everything downstream, squash merges — which collapse `feat:`, `fix:`, `refactor:` into one blob — are explicitly forbidden.

## When not to use this

LoomFlow is the right model for projects that ship versioned, deployable artifacts with at least one pre-production environment. It's the wrong model for:

- Config repos and dotfiles (trunk-based development on `main` is fine)
- Libraries published from tags on `main` (GitHub Flow plus tag-driven publishing is simpler)
- One-off scripts and notebooks (any structured flow is overkill)

The rule of thumb: if you don't have a staging/QA/release-candidate environment, you don't need the integration buffer that `develop` provides, and LoomFlow's ceremony costs more than its discipline benefits.

## The loom

The name isn't accidental. Features, bugfixes, hotfixes — each is a thread. `develop` is the loom. They weave through it into the finished cloth of a tagged release. Git Flow gave us the warp and weft; LoomFlow just makes the weaving cleaner.

I've been running this model on my own projects for months and it's held up through parallel work, bot interference, and the occasional mid-release panic. The full specification is [here](@/publications/articles/loomflow.md), and if you want to adopt it, the TL;DR is:

```
git config --global merge.ff false       # --no-ff everywhere
git config --global rerere.enabled true  # don't re-resolve the same conflict
```

Branch, commit, rebase, merge, delete. That's the loop. LoomFlow just makes sure you don't trip over yourself while you're running it.
