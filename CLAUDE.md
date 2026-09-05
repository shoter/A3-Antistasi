# A3-Antistasi (Shoter's fork)

Arma 3 Antistasi mod, fork of official-antistasi-community/A3-Antistasi. Development happens on the `unstable` branch, and every push to `unstable` is built and published automatically:

- `.github/workflows/releaseUnstable.yml` publishes a new GitHub release for the pushed commit, tagged `unstable-<version>` (asset `A3A-unstable-<version>.zip`) and marked as the latest release.
- `.github/workflows/publishBranchToSteam.yml` uploads the build to the Steam Workshop item.

Both take their release notes from the top entry of `CHANGELOG-unstable.md`, through `.github/actions/changelog` and `Tools/renderChangelog.py`. That makes the rule below mandatory.

## Every push to `unstable` gets a changelog entry

Before pushing to `unstable`, add an entry describing what that push changes to the top of `CHANGELOG-unstable.md` and push it together with the changes. This applies to every push: features, fixes, merges of finished branches, and workflow or tooling changes alike.

Why: the release workflow publishes the top entry as the body of the push's GitHub release, and the Steam workflow publishes it as the Workshop change note. If a push does not touch `CHANGELOG-unstable.md`, both workflows publish a "no changelog entry was written for this push" notice and emit a warning instead of publishing the previous entry a second time.

How:

1. Finish the code changes and merge everything the push will contain into `unstable`.
2. On `unstable`, write the entry at the top of `CHANGELOG-unstable.md`, below the intro text and above the previous entry. Do not add entries on feature branches: they conflict at the top of the file when several branches merge.
3. Preview what will be published with `python Tools/renderChangelog.py --format bbcode`.
4. Commit the changelog, alone or with the last commit of the push, and push.

If a push went out without an entry, write the entry for it and push again; the next build publishes it.

### Entry format

```markdown
## YYYY-MM-DD - Short title

### Added
- Player-facing description of a new feature

### Changed
- ...

### Fixed
- ...
```

- An entry is a level-2 heading (`## `) plus everything up to the next level-2 heading. Only `## ` starts an entry, so use `### ` for sections inside it.
- The date is the day of the push (UTC). The title names the theme of the push in a few words.
- Sections are optional. Use the ones that apply from `Added`, `Changed`, `Fixed`, `Removed` and `Internal`; a small push can be a single bullet without sections.
- One push spanning several features is still one entry, with one bullet (or a few) per feature.
- Write for players and server admins: what they will notice in the game, not which functions changed. Say explicitly when a save is affected or a new setting exists.
- Plain Markdown only: bullets, `**bold**`, `` `code` ``, links. `Tools/renderChangelog.py` turns it into Steam BBCode; double quotes become single quotes there and the note is cut at 7000 characters, so keep entries short. A screenful is plenty.
- Older entries stay as they are, apart from typo fixes.
- `changelog.rst` is the upstream versioned changelog. Leave it to upstream releases; it is not part of this rule.
