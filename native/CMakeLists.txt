cmake_minimum_required(VERSION 3.10)
project(psychosims_native VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Skip optional llama.cpp targets we do not need.
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(PSY_NATIVE_LIBRARY_DIR "${CMAKE_BINARY_DIR}" CACHE PATH "Native library output directory")

find_package(Threads REQUIRED)

add_subdirectory(third_party/llama.cpp)

add_library(psychosims_native SHARED
    src/psychosims_native.cpp
)

target_include_directories(psychosims_native PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(psychosims_native PRIVATE
    llama
    ggml
    Threads::Threads
)

set_target_properties(psychosims_native PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    LIBRARY_OUTPUT_DIRECTORY "${PSY_NATIVE_LIBRARY_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${PSY_NATIVE_LIBRARY_DIR}"
)

enable_testing()
add_subdirectory(test)
