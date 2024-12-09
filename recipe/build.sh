#!/bin/bash

meson setup builddir -D gtk_doc=false -D manpage=false \
    ${MESON_ARGS}

ninja -C builddir -j${CPU_COUNT}
ninja -C builddir install -j${CPU_COUNT}
