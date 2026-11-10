#!/bin/bash

set -euxo pipefail

# vala 0.56.17 (latest on conda-forge) can't parse the <doc:format/> element that
# gobject-introspection >=1.86 writes into .gir files, so vapigen fails.
# Drop that purely informational element from the dependencies' .gir files and from
# our own (built first), then build the rest.
# Remove once vala >=0.56.19 is available.
for girdir in "$PREFIX/share/gir-1.0" "$BUILD_PREFIX/share/gir-1.0"; do
  if [[ -d "$girdir" ]]; then
    find "$girdir" -name '*.gir' -exec sed -i.bak '/<doc:format /d' {} +
    find "$girdir" -name '*.gir.bak' -delete
  fi
done
build_with_vala_workaround() {
  ninja -C "$1" -j${CPU_COUNT} libsecret/Secret-1.gir
  sed -i.bak '/<doc:format /d' "$1/libsecret/Secret-1.gir"
  rm "$1/libsecret/Secret-1.gir.bak"
  ninja -C "$1" -j${CPU_COUNT}
}

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
        --wrap-mode=nofallback \
        --default-library=shared \
        --prefix=$BUILD_PREFIX \
        --native-file=$BUILD_PREFIX/meson_native_file.txt

    # This script would generate the functions.txt and dump.xml and save them
    # This is loaded in the native build. We assume that the functions exported
    # by glib are the same for the native and cross builds
    export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-save.sh
    build_with_vala_workaround native-build
    ninja -C native-build install -j ${CPU_COUNT}
  )
  export GI_CROSS_LAUNCHER=$BUILD_PREFIX/libexec/gi-cross-launcher-load.sh
else
  # g-ir-scanner's shebang picks up the build env python, which may differ from the
  # python that the host gobject-introspection (and its _giscanner extension) was built for.
  cat << EOF > $SRC_DIR/gi_native_file.txt
[binaries]
g-ir-scanner = ['$PREFIX/bin/python', '$PREFIX/bin/g-ir-scanner']
EOF
  MESON_ARGS="${MESON_ARGS} --native-file=$SRC_DIR/gi_native_file.txt"
fi

meson setup builddir \
    -Dgtk_doc=false \
    -Dmanpage=false \
    --wrap-mode=nofallback \
    --default-library=shared \
    ${MESON_ARGS}

build_with_vala_workaround builddir
ninja -C builddir install -j${CPU_COUNT}
