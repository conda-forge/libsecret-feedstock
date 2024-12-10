#!/bin/bash

meson setup builddir -D gtk_doc=false -D manpage=false --wrap-mode=nofallback --default-library=shared \
    ${MESON_ARGS}

ninja -C builddir -j${CPU_COUNT}
ninja -C builddir install -j${CPU_COUNT}
