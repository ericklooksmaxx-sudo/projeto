cmake_minimum_required(VERSION 3.10.2)
project(decrypt_lib)

set(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../openssl")

set(SOURCES ${OPENSSL_ROOT_DIR}/decrypt.c)

add_library(decrypt_lib SHARED ${SOURCES})

target_include_directories(decrypt_lib PRIVATE 
    ${OPENSSL_ROOT_DIR}/include
)

target_link_libraries(decrypt_lib
    ${CMAKE_CURRENT_SOURCE_DIR}/openssl/lib/${ANDROID_ABI}/libcrypto.a
)

target_compile_options(decrypt_lib PRIVATE -O3 -flto)
target_link_options(decrypt_lib PRIVATE -flto)

set_target_properties(decrypt_lib PROPERTIES OUTPUT_NAME "decrypt")
