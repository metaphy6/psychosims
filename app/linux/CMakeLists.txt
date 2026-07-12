# Standard Flutter Linux desktop build file, extended to bundle the
# psychosims_native shared library built from ../../native/CMakeLists.txt.

cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

set(BINARY_NAME "psychosims")
set(APPLICATION_ID "com.psychosims")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "\$ORIGIN/lib")

# Configure build options.
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

set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Flutter-provided plugins.
include(flutter/generated_plugins.cmake)

add_subdirectory("runner")

# === Psychosims native library ==============================================
# Build the native inference backend as part of the desktop build so a normal
# `flutter build linux` produces and bundles the shared library automatically.
add_subdirectory(
  "${CMAKE_CURRENT_SOURCE_DIR}/../../native"
  "${CMAKE_CURRENT_BINARY_DIR}/native"
  EXCLUDE_FROM_ALL
)

# Bundle the native shared library next to the executable for local runs.
set(PSYCHOSIMS_NATIVE_LIBRARY "$<TARGET_FILE:psychosims_native>")
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${PSYCHOSIMS_NATIVE_LIBRARY}"
  "$<TARGET_FILE_DIR:${BINARY_NAME}>"
  COMMENT "Copying psychosims_native into bundle"
)

# Installation layout for release bundles.
set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(FILES "${PSYCHOSIMS_NATIVE_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)

install(TARGETS ${BINARY_NAME}
  RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime
)

# === End Psychosims native library ==========================================
