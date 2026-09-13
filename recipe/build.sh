#!/bin/bash

set -euxo pipefail

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  sed -i "/\[binaries\]/a\g-ir-scanner = '${BUILD_PREFIX}/bin/g-ir-scanner'" ${BUILD_PREFIX}/meson_cross_file.txt
  sed -i "/\[binaries\]/a\g-ir-compiler = '${BUILD_PREFIX}/bin/g-ir-compiler'" ${BUILD_PREFIX}/meson_cross_file.txt
  sed -i "/\[binaries\]/a\glib-mkenums = '${BUILD_PREFIX}/bin/glib-mkenums'" ${BUILD_PREFIX}/meson_cross_file.txt

  unset _CONDA_PYTHON_SYSCONFIGDATA_NAME
  (
    cat << EOF >$BUILD_PREFIX/meson_native_file.txt
[binaries]
g-ir-scanner = '$BUILD_PREFIX/bin/g-ir-scanner'
g-ir-compiler = '$BUILD_PREFIX/bin/g-ir-compiler'
glib-mkenums = '$BUILD_PREFIX/bin/glib-mkenums'
EOF
    mkdir -p native-build

    export CC=$CC_FOR_BUILD
    export OBJC=$OBJC_FOR_BUILD
    export AR="$($CC_FOR_BUILD -print-prog-name=ar)"
    export NM="$($CC_FOR_BUILD -print-prog-name=nm)"
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig

    # Unset them as we're ok with builds that are either slow or non-portable
    unset CFLAGS
    unset CPPFLAGS
    export host_alias=$build_alias

    meson setup native-build \
        -Dgtk_doc=false \
        -Dmanpage=false \
        -Dvapi=false \
        --wrap-mode=nofallback \
        --default-library=shared \
        --prefix=$BUILD_PREFIX \
        --native-file=$BUILD_PREFIX/meson_native_file.txt

    # This script would generate the functions.txt and dump.xml and save them
    # This is loaded in the native build. We assume that the functions exported
    # by glib are the same for the native and cross builds
    export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-save.sh
    ninja -C native-build -j ${CPU_COUNT}
    ninja -C native-build install -j ${CPU_COUNT}
  )
  export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-load.sh
else
  # The g-ir-scanner shipped with the host gobject-introspection only runs under
  # the python it was built against, which need not be the one in the build
  # prefix. Use the build prefix copy from g-ir-build-tools instead.
  cat << EOF >$BUILD_PREFIX/meson_native_file.txt
[binaries]
g-ir-scanner = '$BUILD_PREFIX/bin/g-ir-scanner'
EOF
  EXTRA_MESON_ARGS="--native-file=$BUILD_PREFIX/meson_native_file.txt"
fi

meson setup builddir \
    -Dgtk_doc=false \
    -Dmanpage=false \
    --wrap-mode=nofallback \
    --default-library=shared \
    ${EXTRA_MESON_ARGS:-} \
    ${MESON_ARGS}

# vapigen from vala 0.56 chokes on the <doc:format/> element that
# gobject-introspection >= 1.86 writes into .gir files, so strip it from the
# .gir files of our dependencies ...
for gir_dir in "$PREFIX/share/gir-1.0" "$BUILD_PREFIX/share/gir-1.0"; do
  [[ -d "$gir_dir" ]] || continue
  find "$gir_dir" -name '*.gir' -exec sed -i '/<doc:format /d' {} +
done

# ... and from our own, which means generating it before the vapi target runs.
ninja -C builddir -j${CPU_COUNT} libsecret/Secret-1.gir
sed -i '/<doc:format /d' builddir/libsecret/Secret-1.gir

ninja -C builddir -j${CPU_COUNT}
ninja -C builddir install -j${CPU_COUNT}
