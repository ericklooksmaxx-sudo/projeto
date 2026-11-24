#!/bin/bash
set -e  # Exit on error

OPENSSL_VERSION="3.4.1"
ANDROID_API=21
OPENSSL_SOURCE="openssl-${OPENSSL_VERSION}"
CURRENT_DIR=$(pwd -W)  # Use -W to get Windows path in MSYS2
OUTPUT_DIR="${CURRENT_DIR}/openssl-android-build"

# Set NDK environment variables
export ANDROID_NDK_HOME=/c/Users/utentee/AppData/Local/Android/Sdk/ndk/29.0.13599879
export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/windows-x86_64/bin:$PATH
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME

echo "Current directory: ${CURRENT_DIR}"
echo "Output directory: ${OUTPUT_DIR}"


command -v make >/dev/null 2>&1 || { echo "make is not installed. Please run 'pacman -S make'"; exit 1; }
command -v perl >/dev/null 2>&1 || { echo "perl is not installed. Please run 'pacman -S perl'"; exit 1; }

if [ ! -f "${OPENSSL_SOURCE}.tar.gz" ]; then
    wget "https://www.openssl.org/source/${OPENSSL_SOURCE}.tar.gz"
fi

if [ ! -d "$OPENSSL_SOURCE" ]; then
    tar -xzf "${OPENSSL_SOURCE}.tar.gz"
fi

mkdir -p "$OUTPUT_DIR"

build_openssl() {
    local ABI=$1
    local ANDROID_ARCH=$2
    local OPENSSL_ARCH=$3
    local COMPILER_PREFIX=$4
    
    echo "Building OpenSSL for $ABI..."
    
    local OUT_DIR="${OUTPUT_DIR}/${ABI}"
    mkdir -p "$OUT_DIR"
    
    echo "Output directory for $ABI: $OUT_DIR"
    
    pushd "$OPENSSL_SOURCE"
    
    [ -f Makefile ] && make clean || echo "No previous build to clean"
    
    export CC=${COMPILER_PREFIX}${ANDROID_API}-clang
    export CXX=${COMPILER_PREFIX}${ANDROID_API}-clang++
    
    echo "Using compiler: $CC"
    
    if ! command -v $CC &> /dev/null; then
        echo "ERROR: Compiler $CC not found. Check your NDK installation"
        popd
        return 1
    fi
    
    # Configure OpenSSL with ABSOLUTE paths
	./Configure \
	  android-${OPENSSL_ARCH} \
	  -D__ANDROID_API__=${ANDROID_API} \
	  --prefix="${OUT_DIR}" \
	  --openssldir="${OUT_DIR}" \
	  no-shared \
	  no-tests \
	  no-comp \
	  no-ssl \
	  no-dh \
	  no-dsa \
	  no-ec \
	  no-err \
	  no-engine \
	  no-async \
	  no-legacy \
	  no-aria \
	  no-camellia \
	  no-seed \
	  no-md2 no-md4 no-rmd160 \
	  no-bf no-cast no-des no-idea no-rc2 no-rc4 no-rc5 \
	  no-sm2 no-sm3 no-sm4 \
	  no-chacha no-poly1305 no-siphash \
	  no-whirlpool no-scrypt no-srtp \
	  no-cms no-ts no-ocsp \
	  no-cmac
    
    if [ ! -f Makefile ]; then
        echo "ERROR: Configure failed. Makefile was not created."
        popd
        return 1
    fi
    
    make -j4
    make install_sw
    
    popd
    
    echo "Finished building OpenSSL for $ABI"
}

build_openssl "arm64-v8a" "arm64" "arm64" "aarch64-linux-android" || echo "Failed to build for arm64-v8a"
build_openssl "armeabi-v7a" "arm" "arm" "armv7a-linux-androideabi" || echo "Failed to build for armeabi-v7a"
build_openssl "x86" "x86" "x86" "i686-linux-android" || echo "Failed to build for x86"
build_openssl "x86_64" "x86_64" "x86_64" "x86_64-linux-android" || echo "Failed to build for x86_64"

if [ -d "${OUTPUT_DIR}/arm64-v8a/include/openssl" ]; then
    mkdir -p "${OUTPUT_DIR}/include"
    cp -r "${OUTPUT_DIR}/arm64-v8a/include/openssl" "${OUTPUT_DIR}/include/"
    echo "Copied headers from arm64-v8a build"
elif [ -d "${OUTPUT_DIR}/armeabi-v7a/include/openssl" ]; then
    mkdir -p "${OUTPUT_DIR}/include"
    cp -r "${OUTPUT_DIR}/armeabi-v7a/include/openssl" "${OUTPUT_DIR}/include/"
    echo "Copied headers from armeabi-v7a build"
elif [ -d "${OUTPUT_DIR}/x86_64/include/openssl" ]; then
    mkdir -p "${OUTPUT_DIR}/include"
    cp -r "${OUTPUT_DIR}/x86_64/include/openssl" "${OUTPUT_DIR}/include/"
    echo "Copied headers from x86_64 build"
else
    echo "WARNING: No headers found. All builds may have failed."
fi

echo "OpenSSL build process completed"