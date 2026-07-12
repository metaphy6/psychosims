cmake_minimum_required(VERSION 3.10)
project(psychosims_native VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(psychosims_native SHARED
    src/psychosims_native.cpp
)

target_include_directories(psychosims_native PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

enable_testing()
add_subdirectory(test)
