# Third-party notices and asset provenance

## Licensing boundary

- Authored UI, user-space native hooks, device helpers, tools, tests and optional
  integrations: [MIT](../LICENSE), copyright 2026 Geeprox.
- Authored kernel module repair builder, assembly and boot-selection helpers under
  `driver/`: [GPL-2.0-only](../driver/LICENSE).
- Factory application, original/patched kernel module, radio firmware, native Qt
  plugins and OEM fallback QML: **not distributed and not relicensed**. Local tools
  read the owner's supported original and preserve its recovery copy.
- Device DIN/Roboto/Qingping fonts are referenced on the owner's device, not bundled.

## Bundled upstream works

**Astronomy Engine** by Don Cross / cosinekitty, MIT.
[Upstream](https://github.com/cosinekitty/astronomy),
[full license](../qml/AstronomyEngine.LICENSE),
[browser source](https://github.com/cosinekitty/astronomy/blob/master/source/js/astronomy.browser.min.js).
The browser bundle is adapted only with a QML library/global export shim. Numerical
code is retained. `MoonPhase.js` uses numeric UTC J2000 days; the minute cache and
north-up illuminated-disk renderer are authored additions.

**Permanent Marker Regular** by Font Diner, Apache-2.0.
[Upstream font and notices](https://github.com/google/fonts/tree/main/apache/permanentmarker),
[full license](../qml/fonts/PermanentMarker-LICENSE.txt).
The original font is retained without renaming. The root MIT license does not
replace the font's Apache license.

## Original raster assets

- `qml/textures/pool-depth-v3.png`: original prompt-generated pool material, with
  its generation brief and hash under `qml/textures/`.
- `qml/water/`: original local extraction/blending of that material into three
  constant textures. Runtime animation uses transforms and alpha; obsolete
  48-frame caches are omitted.
- `qml/art/observatory.png`: original prompt-generated observatory illustration,
  with prompt summary and hash in `qml/art/provenance.json`.

No personal photo, design-reference screenshot or artist image was supplied to
these generations. C2PA authenticity chunks are preserved where present; EXIF and
text metadata are not included. Generated images are supplied under the root MIT
terms to the extent rights are held. The repository does not claim rights in
third-party marks, typefaces or vendor work. Preview screenshots use fixed
synthetic readings and contain no personal photos, networks or transcriptions.

The media placeholder is an authored blank raster encoded in a source constant.
SVG controls are simple authored geometric symbols; the old branded knot logo
is replaced by a generic sensor grid.

## Optional runtime/build dependencies

The optional service installs dependencies from their own upstream distributions;
none are vendored here. Relevant projects include [MLX](https://github.com/ml-explore/mlx),
[mlx-whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper),
[NumPy](https://numpy.org/), [OpenCC](https://github.com/yichen0831/opencc-python),
[pyelftools](https://github.com/eliben/pyelftools), [Unicorn](https://www.unicorn-engine.org/),
[TypeScript](https://github.com/microsoft/TypeScript), Node.js and clang.
Their own licenses and model licenses apply. Qt, FFmpeg and ImageMagick are
external host/device requirements, not packaged binaries.
