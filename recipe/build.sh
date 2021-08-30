#!/bin/bash

./configure --prefix="$PREFIX" \
    --disable-manpages \
    --with-libgcrypt-prefix="$PREFIX" || cat config.log

# Requires python-dbus and some other stuff
# make check

# Conda-forge libtool is patched to honor -Wl,--as-needed
make install LIBTOOL=$BUILD_PREFIX/bin/libtool -j${CPU_COUNT}
