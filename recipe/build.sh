#!/bin/bash

meson setup builddir \
    -Dgtk_doc=false \
    -Dmanpage=false \
    --wrap-mode=nofallback \
    --default-library=shared \
    ${MESON_ARGS}

ninja -C builddir -j${CPU_COUNT}
ninja -C builddir install -j${CPU_COUNT}
