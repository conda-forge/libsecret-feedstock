#!/bin/bash

meson setup builddir -D gtk_doc=false -D manpage=false \
    ${MESON_ARGS}

ninja -C builddir
ninja -C builddir install
