#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build

./configure --prefix="$PREFIX" \
    --disable-manpages \
    --enable-introspection \
    --with-libgcrypt-prefix="$PREFIX" || cat config.log

# Requires python-dbus and some other stuff
# make check

make install -j${CPU_COUNT}
