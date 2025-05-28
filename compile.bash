#!/usr/bin/env bash
set -e

SOURCE="libffi-3.4.8"
PACKAGE="$SOURCE.tar.gz"
URL="https://github.com/libffi/libffi/archive/v${SOURCE#libffi-}.tar.gz"
SHA256="cbb7f0b3b095dc506387ec1e35b891bfb4891d05b90a495bc69a10f2293f80ff"
TESTFILE="include/ffi.h"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CUSTOM_SOURCE_DIR="$SOURCE_DIR"
CUSTOM_BUILD_DIR="$BUILD_DIR"
CUSTOM_PREFIX="$PREFIX"
CUSTOM_MTUNE="$MTUNE"
CUSTOM_ADDRM="$ADDRM"

if [ ! -f "$PROJECT_DIR/toolchains/README.md" ]; then
    pushd "$PROJECT_DIR/toolchains" > /dev/null
    git submodule update --init --recursive
    popd > /dev/null
fi

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
        echo "  $var=${!var-(unset)}"
    done

    pushd "$PROJECT_DIR"
    if [ ! -f "$PACKAGE" ]; then
         curl --silent --location --output "$PACKAGE" "$URL"
         echo "$SHA256  $PACKAGE" | shasum --algorithm 256 --check || { echo "Checksum failed"; echo "    expected: $SHA256"; echo "    got     : $(shasum -a 256 "$PACKAGE")"; exit 2; }
    fi

    [ -d "$SOURCE" ] || tar xf "$PACKAGE"
    if [ ! -x "$SOURCE/configure" ]; then
        pushd "$SOURCE" > /dev/null
        ./autogen.sh
        popd > /dev/null
    fi

    mkdir -p "$BUILD_DIR" && pushd "$BUILD_DIR"

    if [ ! -r "$BUILD_DIR/Makefile" ]; then
        "$SOURCE_DIR/configure" --prefix="$PREFIX" --libdir="$PREFIX/lib" --disable-multi-os-directory --enable-static --disable-shared --includedir="$PREFIX/include" CFLAGS="-mtune=$MTUNE -m$ADDRM -fPIC" CXXFLAGS="-mtune=$MTUNE -m$ADDRM -fPIC" --host=$TARGET || { echo "Configure failed." ; exit 1; }
    else
        echo "Skipping configure: Makefile is already in $BUILD_DIR"
    fi
    make -j$CORES || { echo "Build failed." ; exit 1; }
    make install || { echo "Install failed." ; exit 1; }
    rm -f "$PREFIX"/lib/libffi.so* 	# delete dynamic libraries to force static linking

    popd
    popd

    echo "$SOURCE built for $TOOLCHAIN successfully."
done
