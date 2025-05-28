#!/usr/bin/env bash
set -e

SOURCE="libffi-3.4.2"
PACKAGE="$SOURCE.tar.gz"
URL="https://github.com/libffi/libffi/archive/v${SOURCE#libffi-}.tar.gz"
SHA256="0acbca9fd9c0eeed7e5d9460ae2ea945d3f1f3d48e13a4c54da12c7e0d23c313"
TESTFILE="lib/libffi.a"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CUSTOM_SOURCE_DIR="$SOURCE_DIR"
CUSTOM_BUILD_DIR="$BUILD_DIR"
CUSTOM_PREFIX="$PREFIX"
CUSTOM_MTUNE="$MTUNE"
CUSTOM_ADDRM="$ADDRM"

if [ "$#" -lt 1 ]; then
    echo "Specify toolchain(s) as argument(s). Supported toolchains:"
    echo "  native (detect default tools)"
    for filepath in "$PROJECT_DIR/toolchains"/*.bash ; do
        filename=$(basename "$filepath")
        echo "  ${filename%%.bash}"
    done
    exit 1
fi

for TOOLCHAIN in "$@" ; do

    [ "$TOOLCHAIN" == "native" ] || source "$PROJECT_DIR/toolchains/$TOOLCHAIN.bash"
    [ -n "$CUSTOM_SOURCE_DIR" ] || SOURCE_DIR="$PROJECT_DIR/$SOURCE"
    [ -n "$CUSTOM_BUILD_DIR" ] || BUILD_DIR="$PROJECT_DIR/build-$TOOLCHAIN"
    [ -n "$CUSTOM_PREFIX" ] || PREFIX="$PROJECT_DIR/local-$TOOLCHAIN"
    [ -n "$CUSTOM_MTUNE" ] || MTUNE="generic"
    if [ -z "$CUSTOM_ADDRM" ]; then
        case "$TOOLCHAIN" in
            *i686*)
                ADDRM="32"
                ;;
            *)
                ADDRM="64"
                ;;
        esac
    fi

    if [ -f "$PREFIX/$TESTFILE" ]; then
        echo "$TESTFILE is already installed in $PREFIX"
        continue
    fi

    echo "Building $SOURCE with the following:"
    for var in TOOLCHAIN SOURCE_DIR BUILD_DIR PREFIX CC CXX CFLAGS CXXFLAGS ADDRM MTUNE CMAKE_TOOLCHAIN_FILE CMAKE_PREFIX_PATH CMAKE_INSTALL_PREFIX CMAKE_BUILD_TYPE URL ; do
        echo "  $var=${!var}"
    done

    pushd "$PROJECT_DIR"
    [ -f "$PACKAGE" ] || curl --silent --location --output "$PACKAGE" "$URL"

    echo "$SHA256  $PACKAGE" | shasum --algorithm 256 --check || { echo "Checksum failed"; echo "    expected: $SHA256"; echo "    got     : $(shasum -a 256 "$PACKAGE")"; exit 2; }

    [ -d "$SOURCE" ] || tar xf "$PACKAGE"
    if [ ! -x "$SOURCE/configure" ]; then
        pushd "$SOURCE"
        ./autogen.sh
        popd
    fi

    mkdir -p "$BUILD_DIR" && pushd "$BUILD_DIR"

    "$SOURCE_DIR/configure" --prefix="$PREFIX" --libdir="$PREFIX/lib" --disable-multi-os-directory --enable-static --disable-shared --includedir="$PREFIX/include" CFLAGS="-mtune=$MTUNE -m$ADDRM -fPIC" CXXFLAGS="-mtune=$MTUNE -m$ADDRM -fPIC" --host=$TARGET || { echo "Configure failed." ; exit 1; }
    make -j$CORES || { echo "Build failed." ; exit 1; }
    make install || { echo "Install failed." ; exit 1; }
    rm -f "$PREFIX"/lib/libffi.so* 	# delete dynamic libraries to force static linking

    popd
    popd

    echo "$SOURCE built for $TOOLCHAIN successfully."
done
