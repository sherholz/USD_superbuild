## Copyright 2020 Intel Corporation
## SPDX-License-Identifier: Apache-2.0

#### Global superbuild options/vars ####

ProcessorCount(PROCESSOR_COUNT)

if(NOT PROCESSOR_COUNT EQUAL 0)
  set(BUILD_JOBS ${PROCESSOR_COUNT} CACHE STRING "Number of build jobs '-j <n>'")
else()
  set(BUILD_JOBS 4 CACHE STRING "Number of build jobs '-j <n>'")
endif()

option(INSTALL_IN_SEPARATE_DIRECTORIES
  "Install libraries into their own directories under CMAKE_INSTALL_PREFIX"
  ON
)
mark_as_advanced(INSTALL_IN_SEPARATE_DIRECTORIES)

set(installDir ${CMAKE_INSTALL_PREFIX})

get_filename_component(INSTALL_DIR_ABSOLUTE
  ${installDir} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_BINARY_DIR})

if(${CMAKE_VERSION} VERSION_GREATER 3.11.4)
  set(PARALLEL_JOBS_OPTS -j ${BUILD_JOBS})
endif()

set(DEFAULT_BUILD_COMMAND cmake --build . --config Release ${PARALLEL_JOBS_OPTS})

###############################################################################
###############################################################################
###############################################################################

#### Helper macros ####

macro(setup_component_path_vars _NAME _VERSION)
  set(COMPONENT_VERSION ${_VERSION})
  set(COMPONENT_NAME ${_NAME})
  set(COMPONENT_FULL_NAME ${_NAME}-${_VERSION})

  set(COMPONENT_INSTALL_PATH ${INSTALL_DIR_ABSOLUTE}/install)
  if(INSTALL_IN_SEPARATE_DIRECTORIES)
    set(COMPONENT_INSTALL_PATH
        ${INSTALL_DIR_ABSOLUTE}/install/${COMPONENT_FULL_NAME})
  endif()

  set(COMPONENT_DOWNLOAD_PATH ${COMPONENT_FULL_NAME})
  set(COMPONENT_SOURCE_PATH ${INSTALL_DIR_ABSOLUTE}/source/${COMPONENT_FULL_NAME})
  set(COMPONENT_STAMP_PATH ${COMPONENT_FULL_NAME}/stamp)
  set(COMPONENT_BUILD_PATH ${COMPONENT_FULL_NAME}/build)
endmacro()

macro(append_cmake_prefix_path)
  list(APPEND CMAKE_PREFIX_PATH ${ARGN})
  string(REPLACE ";" "|" CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}")
endmacro()

#### Main component build macro ####

macro(build_component)
  # See cmake_parse_arguments docs to see how args get parsed here:
  #    https://cmake.org/cmake/help/latest/command/cmake_parse_arguments.html
  set(options CLONE_GIT_REPOSITORY OMIT_FROM_INSTALL)
  set(oneValueArgs NAME VERSION URL)
  set(multiValueArgs BUILD_ARGS DEPENDS_ON)
  cmake_parse_arguments(BUILD_COMPONENT "${options}" "${oneValueArgs}"
                        "${multiValueArgs}" ${ARGN})

  # Setup COMPONENT_* variables (containing paths) for this function
  setup_component_path_vars(${BUILD_COMPONENT_NAME} ${BUILD_COMPONENT_VERSION})

  if(BUILD_COMPONENT_OMIT_FROM_INSTALL)
    set(COMPONENT_SOURCE_PATH ${COMPONENT_FULL_NAME}/source)
    set(COMPONENT_INSTALL_PATH ${CMAKE_BINARY_DIR}/${COMPONENT_NAME}/install)
  endif()

  # Setup where we get source from (clone repo or download source zip)
  if(BUILD_COMPONENT_CLONE_GIT_REPOSITORY)
    set(COMPONENT_REMOTE_SOURCE_OPTIONS
      GIT_REPOSITORY ${BUILD_COMPONENT_URL}
      GIT_TAG ${COMPONENT_VERSION}
      GIT_SHALLOW ON
    )
  else()
    set(COMPONENT_REMOTE_SOURCE_OPTIONS
      URL "${BUILD_COMPONENT_URL}/archive/${COMPONENT_VERSION}.zip"
    )
  endif()

  # Build the actual component
  ExternalProject_Add(${COMPONENT_NAME}
    PREFIX ${COMPONENT_FULL_NAME}
    DOWNLOAD_DIR ${COMPONENT_DOWNLOAD_PATH}
    STAMP_DIR ${COMPONENT_STAMP_PATH}
    SOURCE_DIR ${COMPONENT_SOURCE_PATH}
    BINARY_DIR ${COMPONENT_BUILD_PATH}
    ${COMPONENT_REMOTE_SOURCE_OPTIONS}
    LIST_SEPARATOR | # Use the alternate list separator
    CMAKE_ARGS
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_INSTALL_PREFIX:PATH=${COMPONENT_INSTALL_PATH}
      -DCMAKE_INSTALL_INCLUDEDIR=${CMAKE_INSTALL_INCLUDEDIR}
      -DCMAKE_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
      -DCMAKE_INSTALL_DOCDIR=${CMAKE_INSTALL_DOCDIR}
      -DCMAKE_INSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}
      -DCMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}
      ${BUILD_COMPONENT_BUILD_ARGS}
    BUILD_COMMAND ${DEFAULT_BUILD_COMMAND}
    BUILD_ALWAYS OFF
  )

  if(BUILD_COMPONENT_DEPENDS_ON)
    ExternalProject_Add_StepDependencies(${COMPONENT_NAME}
      configure ${BUILD_COMPONENT_DEPENDS_ON}
    )
  endif()

  # Place installed component on CMAKE_PREFIX_PATH for downstream consumption
  append_cmake_prefix_path(${COMPONENT_INSTALL_PATH})

  # Define extra build target which installs extra scripts

  if(NOT BUILD_COMPONENT_OMIT_FROM_INSTALL)
    # stash some old values form the component just built above
    set(BASE_COMPONENT_NAME ${COMPONENT_NAME})
    set(EXTRAS_INSTALL_PATH ${COMPONENT_INSTALL_PATH})

    # setup vars for the extras target defined below
    #setup_component_path_vars(${COMPONENT_NAME}_extras "")

    if(WIN32)
      set(PLATFORM_DIR windows)
    else()
      set(PLATFORM_DIR linux)
    endif()

    ExternalProject_Add(${COMPONENT_NAME}
      PREFIX ${COMPONENT_FULL_NAME}
      DOWNLOAD_DIR ${COMPONENT_DOWNLOAD_PATH}
      STAMP_DIR ${COMPONENT_STAMP_PATH}
      SOURCE_DIR ${COMPONENT_SOURCE_PATH}
      BINARY_DIR ${COMPONENT_BUILD_PATH}
      DOWNLOAD_COMMAND ""
      CONFIGURE_COMMAND ""
      BUILD_COMMAND ""
      #INSTALL_COMMAND "${CMAKE_COMMAND}" -E copy_directory
      #  <SOURCE_DIR>/${PLATFORM_DIR}
      #  ${EXTRAS_INSTALL_PATH}
      BUILD_ALWAYS OFF
    )
  endif()
endmacro()