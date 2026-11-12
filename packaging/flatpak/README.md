# Flatpak

`io.github.bewzaalex.kamerton.yml` builds Kamerton on the KDE runtime, with single-precision FFTW as
its only extra module. Each GitHub release gets a Flatpak bundle built from it.

Kamerton isn't on Flathub. Flathub doesn't accept manifests written with AI help, so a Flathub
submission needs its own manifest, written and submitted by a person.

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
    --compose-url-policy=full --mirror-screenshots-url=https://dl.flathub.org/media/ \
    app ../../packaging/flatpak/io.github.bewzaalex.kamerton.yml
flatpak install --user ./repo io.github.bewzaalex.kamerton
flatpak run io.github.bewzaalex.kamerton
```

Check the manifest and the build against Flathub's rules, still in `build/flatpak/`:

```sh
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest ../../packaging/flatpak/io.github.bewzaalex.kamerton.yml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo
```

Both should pass with no errors. The two URL options put the screenshots and icons in the catalog
with their Flathub addresses, as Flathub's own builds do.

The manifest builds the release tag, not your working copy. To try local changes, replace the `git`
source of the `kamerton` module with `type: dir` and `path: ../..` (relative to the manifest).

## A new release

1. Add the release to `data/io.github.bewzaalex.kamerton.metainfo.xml`, and point the screenshot URLs at
   the new tag.
2. Tag it (`vX.Y.Z`) and publish a GitHub release.
3. In the manifest, set `tag` and `commit` of the `kamerton` module to the new tag.
4. Build and check it as above, then make the bundle in `build/flatpak/` and attach it to the GitHub release:

   ```sh
   flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
       repo kamerton-X.Y.Z.flatpak io.github.bewzaalex.kamerton master
   ```

5. Update the version in the file name in the top README's Flatpak section.

## Clean up

From the top folder of the repository:

```sh
flatpak uninstall --user io.github.bewzaalex.kamerton
rm -rf build/flatpak
```

`rm -rf build` removes the native build too.
