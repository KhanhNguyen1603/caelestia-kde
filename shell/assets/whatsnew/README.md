# What's New assets

Media for the What's New window. The entries themselves are declared in
`shell/modules/whatsnew/Entries.qml`; this directory only holds the files they
point at.

## Adding an entry

Append an object to the end of `list` in `Entries.qml`:

```qml
{
    "id": "some_short_handle",
    "revision": 16,
    "version": "2.7.0",
    "date": "2026-11-08",
    "icon": "extension",
    "title": qsTr("A headline"),
    "description": qsTr("The full text, shown under the title."),
    "mediaUrl": "some_screenshot.png"
}
```

- `id` - a stable handle. Never reuse or rename one.
- `revision` - higher than every entry above it. Revisions are what the shell
  records acknowledgement against, so changing one either re-shows the entry to
  everybody or hides it from them. Never renumber or reorder a shipped entry.
  Pruning entries from the list is fine; acknowledged revisions that no longer
  match an entry are ignored.
- `version` - the release the entry shipped in. Consecutive entries with the
  same version are grouped under one heading, so a release's entries have to sit
  together in the list. Versions never go backwards down the file.
- `date` - that release's date, `YYYY-MM-DD`, shown beside the version and in
  the window header. Every entry in a release carries the same date.
- `icon` - a Material icon name. Optional.
- `title`, `description` - wrapped in `qsTr()` so lupdate can extract them.
  Write the description as one or two sentences a user can scan: name the
  surface and the action, keep it under about 120 characters, and leave out
  "now", "seamless", "comprehensive" and benefit clauses. The row shows the
  whole description wrapped to the card, so anything longer pushes the rest of
  the release off the first screen.
- `mediaUrl` - a filename in this directory, or `root:/assets/...` to point at a
  shared shell asset. `.mp4`, `.webm`, `.mkv`, `.avi` and `.mov` play muted on a
  loop; anything else is shown as a still. Optional; an entry with media gets a
  disclosure chevron and expands in place.
- `mediaTransparent` - set it when the media should not get the backing panel.
  Optional.

`.github/scripts/test_repo_integrity.py` fails the build when a revision is
duplicated or out of order, a version or date is missing or goes backwards, an
id is duplicated, a title or description is not wrapped for extraction, a media
path escapes this directory, or a media file does not exist.

## State

Acknowledgement is stored in `~/.local/state/caelestia/whatsnew.json`:

```json
{ "schemaVersion": 1, "acknowledged": [9, 10, 11], "showAfterUpdate": true }
```

Opening an entry adds its revision to that list, and closing the window
acknowledges the rest: a user who dismisses the window has seen it, and handing
them the same release again at the next login is the bug this guards against.
`showAfterUpdate` is the window's own opt-out switch; with it off the window
stays away until it is opened from its keybind or the `whatsnew` IPC target.
Revisions that no longer match an entry are ignored, so pruning an old entry
neither re-shows nor hides anything for a user who already acknowledged it.
