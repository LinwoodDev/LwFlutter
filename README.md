# LwFlutter

Linwood's lightweight Flutter patch distribution.

This repository does **not** ship a full Flutter SDK. It ships:

- a base Flutter version in `flutter.version`
- patch files in `patches/`
- optional prebuilt local-engine artifacts for platforms that need engine patches
- a reusable setup action for Linwood Butterfly in `setup/action.yml`

## Layout

```text
LwFlutter/
├─ flutter.version
├─ patches/
│  ├─ common/
│  │  └─ *.patch
│  ├─ windows/
│  │  └─ *.patch
│  └─ linux/
│     └─ *.patch
└─ .github/workflows/release.yml
```

## Patch folders

- `patches/common/`: patches that should be applied for every platform and usually do not require a local engine artifact.
- `patches/windows/`: Windows-specific patches. If files exist here, the release workflow can build `windows_release_x64`.
- `patches/linux/`: Linux-specific patches. If files exist here, the release workflow can build `linux_release_x64`.

All patch files are applied to the official Flutter checkout in sorted order.

## Creating patch files

From a Flutter checkout:

```bash
git format-patch <base-ref>..<patched-ref> -o /path/to/LwFlutter/patches/windows
```

or for a single diff-style patch:

```bash
git diff <base-ref>..<patched-ref> > /path/to/LwFlutter/patches/windows/0001-my-change.patch
```

`git format-patch` is preferred because the setup action applies patches using `git am` first, with `git apply` as fallback.

## Creating a release

Tag the repo with the base Flutter version plus a Linwood suffix:

```bash
git tag v3.35.7-lw.1
git push origin v3.35.7-lw.1
```

The release workflow publishes:

```text
lwflutter-patches.zip
lwflutter-manifest.json
lwflutter-engine-windows_release_x64.zip  # only when Windows engine patches are present/requested
lwflutter-engine-linux_release_x64.zip    # only when Linux engine patches are present/requested
```

## Using from Linwood Butterfly

```yaml
- name: Setup Flutter
  id: flutter
  uses: LinwoodDev/LwFlutter/setup@main
  with:
    flutter-version: 3.35.7
    platform: windows

- name: Build Butterfly
  working-directory: app
  shell: pwsh
  run: |
    flutter pub get
    flutter build windows --release ${{ steps.flutter.outputs.local-engine-args }}
```

If a matching LwFlutter release exists, patches are applied to official Flutter. If a matching engine artifact exists for the platform, local-engine args are emitted. Otherwise it falls back to official Flutter behavior.

## License

This repository is licensed under the BSD 3-Clause License.

The patch files are intended to be applied on top of Flutter and may contain
diffs derived from Flutter source files. Flutter itself is licensed under the
BSD 3-Clause License. See the upstream Flutter license for details.
