# Specify the minimum version for CMake
cmake_minimum_required(VERSION 2.8)

# Message
message(STATUS "Transistor Placement")
message(STATUS ${CMAKE_CURRENT_SOURCE_DIR})
message(STATUS ${PROJECT_SOURCE_DIR})

# Find includes in the build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Set CC and CXX. Prefer the activated environment's toolchain.
if(DEFINED ENV{CC} AND NOT "$ENV{CC}" STREQUAL "")
  set(CMAKE_C_COMPILER "$ENV{CC}")
else()
  execute_process(COMMAND which gcc OUTPUT_VARIABLE CC OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(CMAKE_C_COMPILER ${CC})
endif()

if(DEFINED ENV{CXX} AND NOT "$ENV{CXX}" STREQUAL "")
  set(CMAKE_CXX_COMPILER "$ENV{CXX}")
else()
  execute_process(COMMAND which g++ OUTPUT_VARIABLE CXX OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(CMAKE_CXX_COMPILER ${CXX})
endif()

# Project's name
project(transistorplacement)

# Z3 SMT prover - Please modify it to suit your environment
if(NOT DEFINED Z3_DIR)
  set(Z3_DIR "${CMAKE_CURRENT_SOURCE_DIR}/z3/build")
endif()
if(EXISTS "${Z3_DIR}/cmake/Z3Config.cmake")
  set(Z3_CONFIG_DIR "${Z3_DIR}/cmake")
else()
  set(Z3_CONFIG_DIR "${Z3_DIR}")
endif()
find_package(Z3
  REQUIRED
  CONFIG
  # `NO_DEFAULT_PATH` is set so that -DZ3_DIR has to be passed to find Z3.
  # This should prevent us from accidentally picking up an installed
  # copy of Z3. This is here to benefit Z3's build system when building
  # this project. When making your own project you probably shouldn't
  # use this option.
  NO_DEFAULT_PATH
  PATHS "${Z3_CONFIG_DIR}"
)
message(STATUS "Z3_FOUND: ${Z3_FOUND}")
message(STATUS "Found Z3 ${Z3_VERSION_STRING}")
message(STATUS "Z3_DIR: ${Z3_DIR}")

# build configuration - Debug|Release|RelWithDebInfo|MinSizeRel
set ( CMAKE_BUILD_TYPE Debug )

# Set the output folder where your program will be created
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR})
set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR})

set(CMAKE_CXX_STANDARD 17)

set(PATH_SRC ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Warnings/Errors

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror=return-type")

file(GLOB_RECURSE SRC_FILES_
	${PATH_SRC}/*.cpp
	${PATH_SRC}/*.c)

set(SRC_FILES ${SRC_FILES_})

# Include Directories
include_directories(headers ${PATH_SRC} ${Z3_CXX_INCLUDE_DIRS})

# Link library
link_libraries ( ${Z3_LIBRARIES} )
# link_libraries ( ${Z3_LIBRARIES} "-static")

# Targets
add_executable(placement ${SRC_FILES})

# for static
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
target_link_libraries(placement PRIVATE Threads::Threads)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9)
  target_link_libraries(placement PRIVATE stdc++fs)
endif()


# Linker Flags
#set_target_properties(main PROPERTIES LINK_FLAGS "-static -W1,--whole-archive -rdynamic -lpthread -W1,--no-whole-archive")
