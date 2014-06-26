cmake_minimum_required(VERSION 3.0)

# Include the following macro from the CMake Modules folder.
include(CMakeParseArguments)

# If this is Mac OS, override the default compiler (which is probably one
# provided by XCode).
if(APPLE)
  message(STATUS "Overriding default compiler...")
  set(CMAKE_C_COMPILER /usr/bin/gcc)
  set(CMAKE_CXX_COMPILER /usr/bin/g++)
endif()

# If the build type (Debug/Release) has not been set for a UNIX-style system,
# go ahead and set it to Release. This helps avoid issues for configurations that
# explicitly try to see if the current build type is either Debug or Release.
if(UNIX)
  if(NOT CMAKE_BUILD_TYPE)
    message(STATUS "No build type selected, defaulting to Release...")
    set(CMAKE_BUILD_TYPE "Release")
  endif()
endif()

macro(CMH_NEW_MODULE_WITH_DEPENDENCIES)
  # Get the name of this module (based on the name of its config file).
  CMH_GET_MODULE_NAME(CMH_MODULE_NAME ${CMAKE_CURRENT_LIST_FILE})

  # Prevent this function from being called more than one time in the current project.
  if(NOT ${CMH_MODULE_NAME}_DEFINED)
    set(${CMH_MODULE_NAME}_DEFINED TRUE)

    # Parse the input arguments (the dependencies of this module).
    set(${CMH_MODULE_NAME}_MODULE_DEPENDENCY_PATHS "")
    set(${CMH_MODULE_NAME}_MODULE_DEPENDENCIES "")
    foreach(DEPENDENCY ${ARGN})
      # Build a list of the full names or paths to the dependency modules.
      list(APPEND ${CMH_MODULE_NAME}_MODULE_DEPENDENCY_PATHS ${DEPENDENCY})

      # Build a list of just the names of the dependency modules.
      CMH_GET_MODULE_NAME(DEPENDENCY_MODULE_NAME ${DEPENDENCY})
      list(APPEND ${CMH_MODULE_NAME}_MODULE_DEPENDENCIES ${DEPENDENCY_MODULE_NAME})
    endforeach()

    # Iterate through the dependency modules and include them.
    foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCY_PATHS})
      if(IS_ABSOLUTE ${DEPENDENCY})
        include(${DEPENDENCY})
      else()
        find_package(${DEPENDENCY})
      endif()
    endforeach()

    # Set the name of this module again, as it will have been overwritten by
    # including any dependencies.
    CMH_GET_MODULE_NAME(CMH_MODULE_NAME ${CMAKE_CURRENT_LIST_FILE})

    # Set the dependencies of this module to tbe the dependencies of its dependencies.
    foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
      list(APPEND
        ${CMH_MODULE_NAME}_MODULE_DEPENDENCIES
        ${${DEPENDENCY}_MODULE_DEPENDENCIES})
    endforeach()

    CMH_ADD_MODULE_SUBDIRECTORY()
  endif()
endmacro(CMH_NEW_MODULE_WITH_DEPENDENCIES)

function(CMH_ADD_MODULE_SUBDIRECTORY)
  # Include the CMakeLists.txt file from the current directory.
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR} ${CMAKE_BINARY_DIR}/${CMH_MODULE_NAME})

  # Help find Boost.
  CMH_FIND_BOOST_HELPER()

  # Get the target type after the subdirectory has been processed.
  CMH_GET_TARGET_TYPE()

  set(CMH_MODULE_NAME_DEBUG ${CMH_MODULE_NAME}_d)

  if(CMH_IS_LIBRARY)
    # Create the paths to the library directories.
    set(${CMH_MODULE_NAME}_LIB_DIR ${CMAKE_BINARY_DIR}/lib)
    set(${CMH_MODULE_NAME}_DEBUG_LIB_DIR ${${CMH_MODULE_NAME}_LIB_DIR}/Debug)
    set(${CMH_MODULE_NAME}_RELEASE_LIB_DIR ${${CMH_MODULE_NAME}_LIB_DIR}/Release)

    # Set the library output directories (static libraries).
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY ${${CMH_MODULE_NAME}_LIB_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${${CMH_MODULE_NAME}_DEBUG_LIB_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${${CMH_MODULE_NAME}_RELEASE_LIB_DIR})

    # Set the library output directories (dynamic libraries).
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY ${${CMH_MODULE_NAME}_LIB_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY_DEBUG ${${CMH_MODULE_NAME}_DEBUG_LIB_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY_RELEASE ${${CMH_MODULE_NAME}_RELEASE_LIB_DIR})
  endif()

  if(CMH_IS_EXECUTABLE)
    # Create the paths to the executable directories.
    set(${CMH_MODULE_NAME}_BIN_DIR ${CMAKE_BINARY_DIR}/bin)
    set(${CMH_MODULE_NAME}_DEBUG_BIN_DIR ${${CMH_MODULE_NAME}_BIN_DIR}/Debug)
    set(${CMH_MODULE_NAME}_RELEASE_BIN_DIR ${${CMH_MODULE_NAME}_BIN_DIR}/Release)

    # Set the executable output directories.
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY ${${CMH_MODULE_NAME}_BIN_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY_DEBUG ${${CMH_MODULE_NAME}_DEBUG_BIN_DIR})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY_RELEASE ${${CMH_MODULE_NAME}_RELEASE_BIN_DIR})
  endif()

  if(CMH_IS_LIBRARY OR CMH_IS_EXECUTABLE)
    # Set the debug and release names of this target.
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      DEBUG_OUTPUT_NAME ${CMH_MODULE_NAME_DEBUG})
    set_target_properties(${CMH_MODULE_NAME} PROPERTIES
      RELEASE_OUTPUT_NAME ${CMH_MODULE_NAME})
  endif()

  if(CMH_IS_LIBRARY)
    # Set the interface properties for this module to their default empty values.
    set(${CMH_MODULE_NAME}_COMPILE_DEFINITIONS "")
    set(${CMH_MODULE_NAME}_INCLUDE_DIRECTORIES "")
    set(${CMH_MODULE_NAME}_LINK_LIBRARIES "")

    # Get the current interface properties for this module.
    get_target_property(CURRENT_COMPILE_DEFINITIONS
      ${CMH_MODULE_NAME} INTERFACE_COMPILE_DEFINITIONS)
    get_target_property(CURRENT_INCLUDE_DIRECTORIES
      ${CMH_MODULE_NAME} INTERFACE_INCLUDE_DIRECTORIES)
    get_target_property(CURRENT_LINK_LIBRARIES
      ${CMH_MODULE_NAME} INTERFACE_LINK_LIBRARIES)

    # If any of the current interface properties are valid, set them to be the
    # module's interface properties.
    if(CURRENT_COMPILE_DEFINITIONS)
      set(${CMH_MODULE_NAME}_COMPILE_DEFINITIONS ${CURRENT_COMPILE_DEFINITIONS})
    endif()
    if(CURRENT_INCLUDE_DIRECTORIES)
      set(${CMH_MODULE_NAME}_INCLUDE_DIRECTORIES ${CURRENT_INCLUDE_DIRECTORIES})
    endif()
    if(CURRENT_LINK_LIBRARIES)
      set(${CMH_MODULE_NAME}_LINK_LIBRARIES ${CURRENT_LINK_LIBRARIES})
    endif()

    # Set the prefix for static libraries.
    set(LIBRARY_PREFIX "")
    if(CMAKE_STATIC_LIBRARY_PREFIX)
      set(LIBRARY_PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})
    endif()
    # Set the extension for static libraries.
    set(LIBRARY_EXTENSION "")
    if(CMAKE_STATIC_LIBRARY_SUFFIX)
      set(LIBRARY_EXTENSION ${CMAKE_STATIC_LIBRARY_SUFFIX})
    endif()

    # Append the path to the debug and release version of this module's library.
    list(APPEND
      ${CMH_MODULE_NAME}_LINK_LIBRARIES
      optimized ${${CMH_MODULE_NAME}_RELEASE_LIB_DIR}/${LIBRARY_PREFIX}${CMH_MODULE_NAME}${LIBRARY_EXTENSION}
      debug ${${CMH_MODULE_NAME}_DEBUG_LIB_DIR}/${LIBRARY_PREFIX}${CMH_MODULE_NAME_DEBUG}${LIBRARY_EXTENSION})

    # Set the inferface properties to have scope outside of this function.
    set(${CMH_MODULE_NAME}_COMPILE_DEFINITIONS ${${CMH_MODULE_NAME}_COMPILE_DEFINITIONS} PARENT_SCOPE)
    set(${CMH_MODULE_NAME}_INCLUDE_DIRECTORIES ${${CMH_MODULE_NAME}_INCLUDE_DIRECTORIES} PARENT_SCOPE)
    set(${CMH_MODULE_NAME}_LINK_LIBRARIES ${${CMH_MODULE_NAME}_LINK_LIBRARIES} PARENT_SCOPE)
  endif()

  # Set this module to have the compile definitions and include directories
  # of its dependencies after we have already saved a copy above of the
  # definitions and directories provided by the user.
  foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
    set_property(TARGET ${CMH_MODULE_NAME} APPEND PROPERTY
      COMPILE_DEFINITIONS ${${DEPENDENCY}_COMPILE_DEFINITIONS})
    set_property(TARGET ${CMH_MODULE_NAME} APPEND PROPERTY
      INCLUDE_DIRECTORIES ${${DEPENDENCY}_INCLUDE_DIRECTORIES})
  endforeach()
endfunction(CMH_ADD_MODULE_SUBDIRECTORY)

macro(CMH_ADD_HEADER_MODULE)
  CMAKE_PARSE_ARGUMENTS(CMH_HEADER_MODULE "" "FOLDER_NAME" "" ${ARGN})
  if(CMH_HEADER_MODULE_FOLDER_NAME)
    source_group(${CMH_HEADER_MODULE_FOLDER_NAME} FILES ${CMH_HEADER_MODULE_UNPARSED_ARGUMENTS})
  else()
    source_group(${CMH_MODULE_NAME} FILES ${CMH_HEADER_MODULE_UNPARSED_ARGUMENTS})
  endif()
  add_custom_target(${CMH_MODULE_NAME}_custom_target SOURCES ${CMH_HEADER_MODULE_UNPARSED_ARGUMENTS})
  set_target_properties(${CMH_MODULE_NAME}_custom_target PROPERTIES PROJECT_LABEL ${CMH_MODULE_NAME})
  add_library(${CMH_MODULE_NAME} INTERFACE)
endmacro(CMH_ADD_HEADER_MODULE)

macro(CMH_ADD_LIBRARY_MODULE)
  CMAKE_PARSE_ARGUMENTS(CMH_LIBRARY_MODULE "" "FOLDER_NAME" "" ${ARGN})
  if(CMH_LIBRARY_MODULE_FOLDER_NAME)
    source_group(${CMH_LIBRARY_MODULE_FOLDER_NAME} FILES ${CMH_LIBRARY_MODULE_UNPARSED_ARGUMENTS})
  else()
    source_group(${CMH_MODULE_NAME} FILES ${CMH_LIBRARY_MODULE_UNPARSED_ARGUMENTS})
  endif()
  add_library(${CMH_MODULE_NAME} ${CMH_LIBRARY_MODULE_UNPARSED_ARGUMENTS})
endmacro(CMH_ADD_LIBRARY_MODULE)

macro(CMH_ADD_EXECUTABLE_MODULE)
  CMAKE_PARSE_ARGUMENTS(CMH_EXECUTABLE_MODULE "" "FOLDER_NAME" "" ${ARGN})
  if(CMH_EXECUTABLE_MODULE_FOLDER_NAME)
    source_group(${CMH_EXECUTABLE_MODULE_FOLDER_NAME} FILES ${CMH_EXECUTABLE_MODULE_UNPARSED_ARGUMENTS})
  else()
    source_group(${CMH_MODULE_NAME} FILES ${CMH_EXECUTABLE_MODULE_UNPARSED_ARGUMENTS})
  endif()
  add_executable(${CMH_MODULE_NAME} ${CMH_EXECUTABLE_MODULE_UNPARSED_ARGUMENTS})
endmacro(CMH_ADD_EXECUTABLE_MODULE)

macro(CMH_TARGET_COMPILE_DEFINITIONS)
  # Get the target type.
  CMH_GET_TARGET_TYPE()

  # Set this target's compile definitions.
  if(CMH_IS_LIBRARY OR CMH_IS_EXECUTABLE)
    target_compile_definitions(${CMH_MODULE_NAME} PUBLIC ${ARGN})
  else()
    target_compile_definitions(${CMH_MODULE_NAME} INTERFACE ${ARGN})
  endif()
endmacro(CMH_TARGET_COMPILE_DEFINITIONS)

macro(CMH_TARGET_INCLUDE_DIRECTORIES)
  # Get the target type.
  CMH_GET_TARGET_TYPE()

  # Set this target's include directories.
  if(CMH_IS_LIBRARY OR CMH_IS_EXECUTABLE)
    target_include_directories(${CMH_MODULE_NAME} PUBLIC ${ARGN})
  else()
    target_include_directories(${CMH_MODULE_NAME} INTERFACE ${ARGN})
  endif()
endmacro(CMH_TARGET_INCLUDE_DIRECTORIES)

macro(CMH_TARGET_LINK_LIBRARIES)
  # Get the target type.
  CMH_GET_TARGET_TYPE()

  # Set this target's link libraries.
  if(CMH_IS_LIBRARY OR CMH_IS_EXECUTABLE)
    target_link_libraries(${CMH_MODULE_NAME} PUBLIC ${ARGN})
  else()
    target_link_libraries(${CMH_MODULE_NAME} INTERFACE ${ARGN})
  endif()
endmacro(CMH_TARGET_LINK_LIBRARIES)

# This macro exists to enable functionality for commands that must be run in
# the same subdirectory as the given target, ex. target_link_libraries().
macro(CMH_LINK_MODULES)
  # Get the type of the target (library, executable, etc).
  CMH_GET_TARGET_TYPE()

  # If this module is an executable, link it to the libraries of its dependencies.
  if(CMH_IS_EXECUTABLE)
    foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
      target_link_libraries(${CMH_MODULE_NAME} PRIVATE ${${DEPENDENCY}_LINK_LIBRARIES})
      add_dependencies(${CMH_MODULE_NAME} ${DEPENDENCY})
    endforeach()
  else()
    message(WARNING "cmh_link_modules() called on target that was not an executable.")
  endif()
endmacro(CMH_LINK_MODULES)

# This macro converts a module's config path (either absolute, relative,
# or just the basename) into just the name of the module. It does this by
# removing all other parts of the config path except the basename. The resulting
# name is stored in the variable provided by the OUTPUT_NAME argument.
# ex. /path/my_module-config.cmake => my_module
macro(CMH_GET_MODULE_NAME OUTPUT_NAME MODULE_CONFIG_PATH)
  set(${OUTPUT_NAME} ${MODULE_CONFIG_PATH})
  # Remove the config.cmake suffix.
  string(REPLACE "-config.cmake" "" ${OUTPUT_NAME} ${${OUTPUT_NAME}})
  string(REPLACE "Config.cmake" "" ${OUTPUT_NAME} ${${OUTPUT_NAME}})
  # Remove the parent directories, or any remaining file extension.
  get_filename_component(${OUTPUT_NAME} ${${OUTPUT_NAME}} NAME_WE)
endmacro(CMH_GET_MODULE_NAME)

# This macro returns true if a provided list contains a certain query value.
# Specifically, the name provided to OUTPUT_NAME will be set to TRUE if the
# value in QUERY_VALUE is found in the list provided as the final argument.
macro(LIST_CONTAINS OUTPUT_NAME QUERY_VALUE)
  set(${OUTPUT_NAME} FALSE)
  foreach(VALUE ${ARGN})
    if(${QUERY_VALUE} STREQUAL ${VALUE})
      set(${OUTPUT_NAME} TRUE)
    endif()
  endforeach()
endmacro(LIST_CONTAINS)

macro(CMH_GET_TARGET_TYPE)
  # Get the type of the target (library, executable, etc).
  get_target_property(CMH_TARGET_TYPE ${CMH_MODULE_NAME} TYPE)

  # Custom targets show up as UTILITY.
  LIST_CONTAINS(CMH_IS_LIBRARY ${CMH_TARGET_TYPE} "STATIC_LIBRARY" "MODULE_LIBRARY" "SHARED_LIBRARY")
  LIST_CONTAINS(CMH_IS_EXECUTABLE ${CMH_TARGET_TYPE} "EXECUTABLE")
  LIST_CONTAINS(CMH_IS_HEADER_MODULE ${CMH_TARGET_TYPE} "INTERFACE_LIBRARY")
endmacro(CMH_GET_TARGET_TYPE)

macro(CMH_FIND_BOOST_HELPER)
  # Test to see if Boost has been used in a find_package() statement.
  if(DEFINED Boost_DIR)
    # Test to see if the Boost include directory has been located or set.
    if(NOT Boost_INCLUDE_DIR)
      # If the Boost include directory is not set, make sure that we print the message below only once.
      if(NOT CMH_FIND_BOOST_HELPER_MESSAGE)
        set(CMH_FIND_BOOST_HELPER_MESSAGE TRUE)
        # Set the variable in the parent scope as well as this macro is typically called from within
        # the cmh_add_module_subdirectory() function which defines its own scope.
        set(CMH_FIND_BOOST_HELPER_MESSAGE TRUE PARENT_SCOPE)
        message("If necessary, provide hints for the location of the Boost root and library directories in CMH_BOOST_ROOT_DIR and CMH_BOOST_LIBRARY_DIR.")
      endif()
    endif()
    # Prompt the user for hints as to where the Boost root and library directories are.
    set(CMH_BOOST_ROOT_DIR "" CACHE PATH "Hint as to where to find the Boost root directory.")
    set(CMH_BOOST_LIBRARY_DIR "" CACHE PATH "Hint as to where to find the Boost library directory.")
    # If the Boost root and library directories have not already been set to valid values,
    # overwrite them with the values provided above.
    if(NOT BOOST_ROOT OR NOT EXISTS ${BOOST_ROOT})
      set(BOOST_ROOT ${CMH_BOOST_ROOT_DIR} CACHE INTERNAL "Hint for Boost root directory location.")
    endif()
    if(NOT BOOST_LIBRARYDIR OR NOT EXISTS ${BOOST_LIBRARYDIR})
      set(BOOST_LIBRARYDIR ${CMH_BOOST_LIBRARY_DIR} CACHE INTERNAL "Hint for Boost library directory location.")
    endif()
  endif()
endmacro(CMH_FIND_BOOST_HELPER)
