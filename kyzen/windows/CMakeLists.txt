# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(kyzen LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "Kyzen")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Silence MSVC deprecations for legacy experimental coroutines (used by permission_handler_windows) and CRT functions
add_compile_definitions(
  _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
  _CRT_SECURE_NO_WARNINGS
)

if(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64" OR CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
  set(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/openssl-windows-build/arm64")
else()
  set(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/openssl-windows-build/x64")
endif()

set(OPENSSL_INCLUDE_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../openssl/include"
)

if(EXISTS "${OPENSSL_ROOT_DIR}/lib64")
    set(OPENSSL_LIB_DIR "${OPENSSL_ROOT_DIR}/lib64")
else()
    set(OPENSSL_LIB_DIR "${OPENSSL_ROOT_DIR}/lib")
endif()

set(OPENSSL_CRYPTO_LIBRARY "${OPENSSL_LIB_DIR}/libcrypto.lib")

if(NOT EXISTS "${OPENSSL_INCLUDE_DIR}")
    message(FATAL_ERROR "OpenSSL include directory not found: ${OPENSSL_INCLUDE_DIR}")
endif()

if(NOT EXISTS "${OPENSSL_CRYPTO_LIBRARY}")
    message(FATAL_ERROR "OpenSSL crypto library not found: ${OPENSSL_CRYPTO_LIBRARY}")
endif()

add_library(OpenSSL::Crypto STATIC IMPORTED)
set_target_properties(OpenSSL::Crypto PROPERTIES
    IMPORTED_LOCATION "${OPENSSL_CRYPTO_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_INCLUDE_DIR}"
)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
  target_compile_definitions(${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# Build decrypt.dll
add_library(decrypt_lib SHARED ${PROJECT_SOURCE_DIR}/../openssl/decrypt.c)
target_link_libraries(decrypt_lib PRIVATE OpenSSL::Crypto)

# Link required Windows system libraries for OpenSSL
target_link_libraries(decrypt_lib PRIVATE 
    ws2_32 
    crypt32
    advapi32
)

# Fix POSIX function warnings on Windows
if(MSVC)
    target_compile_definitions(decrypt_lib PRIVATE 
        _CRT_SECURE_NO_WARNINGS
        _CRT_NONSTDC_NO_DEPRECATE
    )
endif()

set_target_properties(decrypt_lib PROPERTIES 
    OUTPUT_NAME "decrypt"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/runner/$<CONFIG>"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/runner/$<CONFIG>"
)

# Use optimizations only in Release builds to avoid conflicts
if(MSVC)
    target_compile_options(decrypt_lib PRIVATE 
        $<$<CONFIG:Release>:/O2>
        $<$<CONFIG:Profile>:/O2>
    )
    target_link_options(decrypt_lib PRIVATE 
        $<$<CONFIG:Release>:/LTCG>
        $<$<CONFIG:Profile>:/LTCG>
    )
else()
    # For MinGW/GCC - apply optimizations for non-Debug builds
    target_compile_options(decrypt_lib PRIVATE 
        $<$<NOT:$<CONFIG:Debug>>:-O3>
        $<$<NOT:$<CONFIG:Debug>>:-flto>
    )
    target_link_options(decrypt_lib PRIVATE 
        $<$<NOT:$<CONFIG:Debug>>:-flto>
    )
endif()

add_dependencies(${BINARY_NAME} decrypt_lib)

# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

install(TARGETS decrypt_lib
    RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_PREFIX}"
    COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
