# ibus-McBopomofo

小麥注音 ibus 版

> This is an alpha release. Bugs expected! TODOs and FIXMEs are everywhere!!

## Building

Dependencies are as follows:

* Vala (>= 0.40.0)
* meson (>= 0.61.0?)
* libibus-1.0-dev (>= 1.5.0?)
* ninja (>= 1.8.2)

You have to build [the core part](https://github.com/qbane/mcbopomofo-core) first, which is pinned as a submodule:

```
git submodule update --recursive

cd mcbopomofo-core
mkdir build
cd build
# need the following dependencies:
# cmake, extra-cmake-modules, libfmt, gettext
cmake ..
make
```

Then, **keep the build directory as-is**, and compile the project itself.

Note that older libfmt does not have a header-only version script for CMake.
If you encounter undefined references while building, you should edit `meson.build` by adding a dependency to libfmt to link against it.

```
cd ../..
meson setup build --prefix=/usr/local
cd build
ninja
meson install
```

Restart ibus to take effect: `ibus-daemon -rx`.

## Resources

Icons are converted from `*@2x.tiff` to PNG, obtained from [the MacOS version](https://github.com/openvanilla/McBopomofo/tree/master/Source/Images).
