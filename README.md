# LwFlutter

Linwood's lightweight Flutter patch distribution.

This repository does **not** ship a full Flutter SDK. It ships:

- a base Flutter version in `flutter.version`
- patch files or patch sources in `patches/`
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
└─ .github/workflows/
   ├─ release.yml
   └─ test-patches.yml
```

## Patch folders

- `patches/common/`: patches that should be applied for every platform and usually do not require a local engine artifact.
- `patches/windows/`: Windows-specific patches. If files exist here, the release workflow can build `windows_release_x64`.
- `patches/linux/`: Linux-specific patches. If files exist here, the release workflow can build `linux_release_x64`.

All materialized patch files are applied to the official Flutter checkout in sorted order.

## Patch files and patch sources

You can commit patch files:

```text
patches/windows/0001-my-change.patch
```

The workflows run `scripts/materialize_patches.sh` to copy all `.patch` files into a real patch set before applying or publishing them.

## Testing patches

The `Test patches` workflow checks out the Flutter version from `flutter.version`, materializes the patches, and runs `git am --3way` for every patch.

You can run the same locally:

```bash
scripts/materialize_patches.sh patches materialized-patches

git clone https://github.com/flutter/flutter.git /tmp/flutter
cd /tmp/flutter
git checkout "$(cat /path/to/LwFlutter/flutter.version)"

shopt -s globstar nullglob
for patch in /path/to/LwFlutter/materialized-patches/**/*.patch; do
  git am --3way "$patch"
done
```

## Reporting issues

Please only open issues in this repository for problems that are related to the LwFlutter patches or the LwFlutter release/setup infrastructure.

Before opening an issue, test the same project with the matching official Flutter version from `flutter.version` and without any LwFlutter patches. If the problem also happens on official Flutter, please report it to Flutter or the affected application instead.

Good LwFlutter issues are things like:

- a patch no longer applies to the configured Flutter version
- a LwFlutter release asset is missing or broken
- Butterfly behaves differently with LwFlutter than with the same official Flutter version
- the setup action downloads or applies the wrong patch/engine artifact

Please include the LwFlutter release tag, the Flutter version, the platform, and the result of your official-Flutter comparison.

## Creating a release

You can create a tag manually:

```bash
git tag v3.35.7-lw.1
git push origin v3.35.7-lw.1
```

Or run the release workflow manually without entering a tag. It will generate the next tag automatically:

```text
v<flutter.version>-lw.N
```

The release workflow publishes:

```text
lwflutter-patches.zip
lwflutter-manifest.json
lwflutter-engine-windows_release_x64.zip  # only when Windows engine patches are present/requested
lwflutter-engine-linux_release_x64.zip    # only when Linux engine patches are present/requested
```

`lwflutter-patches.zip` contains materialized `.patch` files.

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

## Local patch testing

Before opening an issue here, please check whether the problem also happens on the matching official Flutter version.

This repository should only be used for issues caused by LwFlutter patches, LwFlutter releases, the setup action, or the patch build workflows. If the same problem also happens on official Flutter without LwFlutter patches, report it upstream to Flutter instead.

You can test whether the patches still apply locally:

```bash
scripts/test_patches_locally.sh
```

To test against a specific Flutter stable version:

```bash
scripts/test_patches_locally.sh --flutter-ref 3.35.7
```

To reuse an existing Flutter checkout instead of cloning Flutter again:

```bash
scripts/test_patches_locally.sh --flutter-root ~/dev/flutter --flutter-ref 3.35.7
```

## Updating to the latest Flutter stable

To update `flutter.version` to the latest official Flutter stable version:

```bash
scripts/update_to_latest_stable.sh
```

To update and immediately test whether the patches still apply:

```bash
scripts/update_to_latest_stable.sh --test
```

There is also a GitHub Actions workflow, **Update Flutter stable**, that can open a pull request automatically when a newer Flutter stable release is available.
