# ibus-McBopomofo

小麥注音 ibus 版

> This is an alpha release. Bugs expected! TODOs and FIXMEs are everywhere!!

## Installation guide

Dependencies are as follows:

* GIO
* GLib (>= 2.56)
* libibus-1.0-dev (>= 1.5.0?)
* meson (>= 0.61.0?)
* ninja (>= 1.8.2)
* Vala (>= 0.40.0)
* [McBopomofo core](https://github.com/qbane/mcbopomofo-core)

It can be built with the official repository of Ubuntu 18.04 LTS. The version numbers are based on that fact.

### The core

The McBopomofo engine is encapsulated as a static C library. It is pinned as a submodule for sharing resources with upstream. You have to fetch it in order to build this project:

```
git submodule update --recursive
cd mcbopomofo-core
mkdir -p build/src
```

You can download a built artifact (currently for Ubuntu only), extract the library named "libMcBopomofoCore.a", and tell Meson the location (default to `build/src`). You can also build it from scratch:

```
cd build
# need the following dependencies:
# cmake, extra-cmake-modules, libfmt, gettext
cmake ..
make
```

Then, **keep the build directory as-is**, and compile the project itself.

Note that older libfmt does not have a header-only version script for CMake.
If you encounter undefined references while building, you should edit `meson.build` by adding a dependency to libfmt to link against it.

### Build this project

```
cd ../..
meson setup build --prefix=/usr/local
cd build
ninja
meson install
```

### Installing

If you install to the standard prefix `/usr` (not recommended!), you can simply restart ibus to take effect: `ibus-daemon -rx`. Then select it in GNOME control center if you are using GNOME shell, or through `ibus-setup`.

For the recommended setup in the previous section, it is a non-standard prefix. You need to let IBus "discover" the installation by regenerating the registry cache *as your current user*, as follows:

```
IBUS_COMPONENT_PATH=/usr/local/share/ibus/component:/usr/share/ibus/component ibus write-cache
```

You need to do this whenever you change the component description XML, because it (`~/.cache/ibus/bus/registry`) will be invalidated, and only the standard path is scanned at default.

### Configuration

For now, please use `dconf-editor` to explore and edit the configuration. The settings is at dconf path `/desktop/ibus/engine/mcbopomofo/`.

## Resources

Icons are converted from `*@2x.tiff` to PNG, obtained from [the MacOS version](https://github.com/openvanilla/McBopomofo/tree/master/Source/Images).
