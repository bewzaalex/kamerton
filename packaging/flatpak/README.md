# Flatpak

`io.github.bewzaalex.kamerton.yml` builds Kamerton on the KDE runtime, with single-precision FFTW as
its only extra module. The same manifest goes to Flathub.

## Build and test

You need the builder and the KDE SDK as flatpaks:

```sh
flatpak install --user flathub org.flatpak.Builder org.kde.Sdk//6.11
```

Build in `build/flatpak/`, so everything the builder writes stays there, its cache in `.flatpak-builder`
included:

```sh
mkdir -p build/flatpak && cd build/flatpak
flatpak run org.flatpak.Builder --user --force-clean --repo=repo \
    --mirror-screenshots-url=https://dl.flathub.org/media/ \
    app ../../packaging/flatpak/io.github.bewzaalex.kamerton.yml
flatpak install --user ./repo io.github.bewzaalex.kamerton
flatpak run io.github.bewzaalex.kamerton
```

Check the manifest and the build against Flathub's rules, still in `build/flatpak/`:

```sh
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest ../../packaging/flatpak/io.github.bewzaalex.kamerton.yml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo
```

In a local build the repo check reports `appstream-external-screenshot-url` and
`appstream-remote-icon-not-mirrored`: Flathub's own build servers host the screenshots and icons.

The manifest builds the release tag, not your working copy. To try local changes, replace the `git`
source of the `kamerton` module with `type: dir` and `path: ../..` (relative to the manifest).

## A new release

1. Add the release to `data/io.github.bewzaalex.kamerton.metainfo.xml`, and point the screenshot URLs at
   the new tag.
2. Tag it (`vX.Y.Z`) and publish a GitHub release.
3. In the manifest, set `tag` and `commit` of the `kamerton` module to the new tag.
4. Open a pull request with the same change in the Flathub repository of the app.

## Clean up

From the top folder of the repository:

```sh
flatpak uninstall --user io.github.bewzaalex.kamerton
rm -rf build/flatpak
```

`rm -rf build` removes the native build too.
