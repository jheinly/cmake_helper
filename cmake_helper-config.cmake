# TODO: add test folder which contains CMake/C++ code to test the functionality of this package
# TODO: prevent duplicate compile definitions, include directories, and link libraries from being specified for the same target
# TODO: verify that CUDA-specific settings aren't being accidentally propagated to other modules

# CMake 3.0 is required as it added the add_library() INTERFACE option.
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

    # Create a list of the currently loaded modules. This will be used to
    # determine which modules were included when creating a standalone
    # executable that references one or more cmake_helper modules.
    if(NOT CMH_CURRENT_LOADED_MODULES)
      set(CMH_CURRENT_LOADED_MODULES "")
    endif()
    list(APPEND CMH_CURRENT_LOADED_MODULES ${CMH_MODULE_NAME})

    # Parse the input arguments (the dependencies of this module).
    set(${CMH_MODULE_NAME}_MODULE_DEPENDENCY_PATHS "")
    set(${CMH_MODULE_NAME}_MODULE_DEPENDENCIES "")
    foreach(DEPENDENCY ${ARGN})
      # Build a list of the full names or paths to the dependency modules.
      CMH_LIST_APPEND_IF_UNIQUE(${CMH_MODULE_NAME}_MODULE_DEPENDENCY_PATHS ${DEPENDENCY})

      # Build a list of just the names of the dependency modules.
      CMH_GET_MODULE_NAME(DEPENDENCY_MODULE_NAME ${DEPENDENCY})
      CMH_LIST_APPEND_IF_UNIQUE(${CMH_MODULE_NAME}_MODULE_DEPENDENCIES ${DEPENDENCY_MODULE_NAME})
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

    # Set the dependencies of this module to be the dependencies of its dependencies.
    foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
      CMH_LIST_APPEND_IF_UNIQUE(
        ${CMH_MODULE_NAME}_MODULE_DEPENDENCIES
        ${${DEPENDENCY}_MODULE_DEPENDENCIES})
    endforeach()

    CMH_ADD_MODULE_SUBDIRECTORY()
  endif()
endmacro(CMH_NEW_MODULE_WITH_DEPENDENCIES)

function(CMH_ADD_MODULE_SUBDIRECTORY)
  # Include the CMakeLists.txt file from the current directory.
  set(CMH_IN_SUBDIRECTORY TRUE)
  add_subdirectory(${CMAKE_CURRENT_LIST_DIR} ${CMAKE_BINARY_DIR}/${CMH_MODULE_NAME})
  set(CMH_IN_SUBDIRECTORY FALSE)

  # Help find Boost.
  CMH_FIND_BOOST_HELPER()

  # Help find the CUDA SDK.
  CMH_FIND_CUDA_SDK_HELPER()

  # Get the target type after the subdirectory has been processed.
  CMH_GET_TARGET_TYPE()

  # Set the name of this module when compiling in Debug mode.
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

  if(CMH_IS_LIBRARY OR CMH_IS_HEADER_MODULE)
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

    if(CMH_IS_LIBRARY)
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
    endif()

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

# This macro parses the arguments passed to a cmh_add_*_module() call.
macro(CMH_ADD_MODULE_HELPER OUTPUT_NAME)
  CMAKE_PARSE_ARGUMENTS(CMH_MODULE "" "FOLDER_NAME" "" ${ARGN})
  if(CMH_MODULE_FOLDER_NAME)
    source_group(${CMH_MODULE_FOLDER_NAME} FILES ${CMH_MODULE_UNPARSED_ARGUMENTS})
  else()
    source_group(${CMH_MODULE_NAME} FILES ${CMH_MODULE_UNPARSED_ARGUMENTS})
  endif()
  set(${OUTPUT_NAME} ${CMH_MODULE_UNPARSED_ARGUMENTS})
endmacro(CMH_ADD_MODULE_HELPER)

# Convience macro to create a header module.
macro(CMH_ADD_HEADER_MODULE)
  CMH_ADD_MODULE_HELPER(CMH_MODULE_SOURCE_FILES ${ARGN})
  add_custom_target(${CMH_MODULE_NAME}_custom_target SOURCES ${CMH_MODULE_SOURCE_FILES})
  set_target_properties(${CMH_MODULE_NAME}_custom_target PROPERTIES PROJECT_LABEL ${CMH_MODULE_NAME})
  add_library(${CMH_MODULE_NAME} INTERFACE)
endmacro(CMH_ADD_HEADER_MODULE)

# Convience macro to create a library module.
macro(CMH_ADD_LIBRARY_MODULE)
  CMH_ADD_MODULE_HELPER(CMH_MODULE_SOURCE_FILES ${ARGN})
  add_library(${CMH_MODULE_NAME} ${CMH_MODULE_SOURCE_FILES})
endmacro(CMH_ADD_LIBRARY_MODULE)

# Convience macro to create an executable module.
macro(CMH_ADD_EXECUTABLE_MODULE)
  CMH_ADD_MODULE_HELPER(CMH_MODULE_SOURCE_FILES ${ARGN})
  add_executable(${CMH_MODULE_NAME} ${CMH_MODULE_SOURCE_FILES})
  CMH_LINK_MODULES()
endmacro(CMH_ADD_EXECUTABLE_MODULE)

# Convience macro to create a CUDA library module.
macro(CMH_ADD_CUDA_LIBRARY_MODULE)
  CMH_ADD_MODULE_HELPER(CMH_MODULE_SOURCE_FILES ${ARGN})
  CMH_PREPARE_CUDA_COMPILER(CMH_CUDA_COMPILER_DEFINITIONS)
  cuda_add_library(${CMH_MODULE_NAME} ${CMH_MODULE_SOURCE_FILES} OPTIONS ${CMH_CUDA_COMPILER_DEFINITIONS})
  CMH_FINALIZE_CUDA_LIBRARY()
endmacro(CMH_ADD_CUDA_LIBRARY_MODULE)

# Convience macro to create a CUDA executable module.
macro(CMH_ADD_CUDA_EXECUTABLE_MODULE)
  CMH_ADD_MODULE_HELPER(CMH_MODULE_SOURCE_FILES ${ARGN})
  CMH_PREPARE_CUDA_COMPILER(CMH_CUDA_COMPILER_DEFINITIONS)
  cuda_add_executable(${CMH_MODULE_NAME} ${CMH_MODULE_SOURCE_FILES} OPTIONS ${CMH_CUDA_COMPILER_DEFINITIONS})
  CMH_LINK_MODULES()
endmacro(CMH_ADD_CUDA_EXECUTABLE_MODULE)

# Convience macro to set the compile definitions of a module.
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

# Convience macro to set the include directories of a module.
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

# Convience macro to set the link libraries of a module.
macro(CMH_TARGET_LINK_LIBRARIES)
  # Get the target type.
  CMH_GET_TARGET_TYPE()

  # Set this target's link libraries.
  if(CMH_IS_LIBRARY OR CMH_IS_EXECUTABLE)
    if(CMH_IS_CUDA_MODULE)
      # If this module is a CUDA module we need to use the default
      # target_link_libraries syntax as FindCUDA.cmake hasn't been
      # updated to support the new INTERFACE syntax yet.
      target_link_libraries(${CMH_MODULE_NAME} ${ARGN})
    else()
      target_link_libraries(${CMH_MODULE_NAME} PUBLIC ${ARGN})
    endif()
  else()
    target_link_libraries(${CMH_MODULE_NAME} INTERFACE ${ARGN})
  endif()
endmacro(CMH_TARGET_LINK_LIBRARIES)

# This macro exists to enable functionality for commands that must be run in
# the same subdirectory as the given target, ex. target_link_libraries().
# It should be called at the end of an executable (either standalone or a module).
macro(CMH_LINK_MODULES)
  # Get the number of input arguments.
  set(EXECUTABLE_NAME ${ARGN})
  list(LENGTH EXECUTABLE_NAME LIST_LEN)

  # If this command is called from within a cmake_helper module's subdirectory,
  # then we expect there to be no arguments, and we simply link this module's
  # dependencies to it.
  if(CMH_IN_SUBDIRECTORY)
    if(${LIST_LEN} EQUAL 0)
      # Get the type of the target (library, executable, etc).
      CMH_GET_TARGET_TYPE()

      # If this module is an executable, link it to the libraries of its dependencies.
      if(CMH_IS_EXECUTABLE)
        foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
          if(CMH_IS_CUDA_MODULE)
            # If this module is a CUDA module we need to use the default
            # target_link_libraries syntax as FindCUDA.cmake hasn't been
            # updated to support the new INTERFACE syntax yet.
            target_link_libraries(${CMH_MODULE_NAME} ${${DEPENDENCY}_LINK_LIBRARIES})
          else()
            target_link_libraries(${CMH_MODULE_NAME} PRIVATE ${${DEPENDENCY}_LINK_LIBRARIES})
          endif()
          add_dependencies(${CMH_MODULE_NAME} ${DEPENDENCY})
        endforeach()
      else()
        message(WARNING "cmh_link_modules() called on target that was not an executable.")
      endif()
    else()
      message(WARNING "cmh_link_modules() called with argument(s) when none were expected.")
    endif()
  else()
    # If this command is not called from within a module's subdirectory, then we
    # expect that it is being called from a standalone executable, and the single
    # argument to this command is the name of the executable we wish to link all
    # of the modules to.
    if(${LIST_LEN} EQUAL 1)
      # Iterate through the currently loaded cmake_helper modules.
      foreach(DEPENDENCY ${CMH_CURRENT_LOADED_MODULES})
        # Set the compile definitions.
        set_property(TARGET ${EXECUTABLE_NAME} APPEND PROPERTY
          COMPILE_DEFINITIONS ${${DEPENDENCY}_COMPILE_DEFINITIONS})

        # Set the include directories.
        set_property(TARGET ${EXECUTABLE_NAME} APPEND PROPERTY
          INCLUDE_DIRECTORIES ${${DEPENDENCY}_INCLUDE_DIRECTORIES})

        # Link the libraries, and add the dependency.
        target_link_libraries(${EXECUTABLE_NAME} PRIVATE ${${DEPENDENCY}_LINK_LIBRARIES})
        add_dependencies(${EXECUTABLE_NAME} ${DEPENDENCY})
      endforeach()
    else()
      message(WARNING "cmh_link_modules() expected 1 argument, but received ${LIST_LEN}.")
    endif()
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
macro(CMH_LIST_CONTAINS OUTPUT_NAME QUERY_VALUE)
  set(${OUTPUT_NAME} FALSE)
  foreach(VALUE ${ARGN})
    if(${QUERY_VALUE} STREQUAL ${VALUE})
      set(${OUTPUT_NAME} TRUE)
    endif()
  endforeach()
endmacro(CMH_LIST_CONTAINS)

# This macro will only append to the provided list if the given values in ${ARGN}
# do not already exist within the list.
macro(CMH_LIST_APPEND_IF_UNIQUE LIST_NAME)
  foreach(VALUE_TO_APPEND ${ARGN})
    CMH_LIST_CONTAINS(ALREADY_EXISTS ${VALUE_TO_APPEND} ${${LIST_NAME}})
    if(NOT ${ALREADY_EXISTS})
      list(APPEND ${LIST_NAME} ${VALUE_TO_APPEND})
    endif()
  endforeach()
endmacro(CMH_LIST_APPEND_IF_UNIQUE)

# This macro will determine the type of current module.
macro(CMH_GET_TARGET_TYPE)
  # Get the type of the target (library, executable, etc).
  get_target_property(CMH_TARGET_TYPE ${CMH_MODULE_NAME} TYPE)

  # Custom targets show up as UTILITY.
  CMH_LIST_CONTAINS(CMH_IS_LIBRARY ${CMH_TARGET_TYPE} "STATIC_LIBRARY" "MODULE_LIBRARY" "SHARED_LIBRARY")
  CMH_LIST_CONTAINS(CMH_IS_EXECUTABLE ${CMH_TARGET_TYPE} "EXECUTABLE")
  CMH_LIST_CONTAINS(CMH_IS_HEADER_MODULE ${CMH_TARGET_TYPE} "INTERFACE_LIBRARY")

  # Determine whether or not the current module is a CUDA module.
  CMH_LIST_CONTAINS(CMH_IS_CUDA_MODULE ${CMH_MODULE_NAME} ${CMH_CUDA_MODULE_NAMES})
endmacro(CMH_GET_TARGET_TYPE)

# This macro helps find the boost include and library directories.
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

# This macro requests the user to specify the default compute capability of their GPU. Given
# this compute capability, this macro will create the correct compiler definitions for this
# capability and store them in the provided ${OUTPUT_NAME} so that they can be later passed
# to the CUDA compiler. Additionally, this macro will setup the proper include directories
# and compile definitions for the dependencies of this module.
macro(CMH_PREPARE_CUDA_COMPILER OUTPUT_NAME)
  if(NOT CMH_CUDA_COMPUTE_CAPABILITY)
    set(CMH_CUDA_COMPUTE_CAPABILITY "1.0" CACHE STRING "CUDA compute capability of target GPU device.")
    set_property(CACHE CMH_CUDA_COMPUTE_CAPABILITY PROPERTY STRINGS 1.0 1.1 1.2 1.3 2.0 2.1 3.0 3.5 5.0)
  endif()
  string(REPLACE "." "" CAPABILITY ${CMH_CUDA_COMPUTE_CAPABILITY})
  if(CAPABILITY STREQUAL "21")
    set(${OUTPUT_NAME} "-arch=compute_20 -code=sm_21,compute_20")
  else()
    set(${OUTPUT_NAME} "-arch=compute_${CAPABILITY} -code=sm_${CAPABILITY},compute_${CAPABILITY}")
  endif()

  # Tell the CUDA compiler to provide verbose output, specifically so that
  # the register and shared memory usage is printed when compiling.
  list(APPEND ${OUTPUT_NAME} "--ptxas-options=-v")

  # Iterate through the dependencies of this module and add their include directories
  # and compile definitions as these must be specified before creating the CUDA target.
  # Note that the definitions and include directories will only apply to the CUDA
  # compilation and not to the C++ targets.
  foreach(DEPENDENCY ${${CMH_MODULE_NAME}_MODULE_DEPENDENCIES})
    list(APPEND ${OUTPUT_NAME} "${${DEPENDENCY}_COMPILE_DEFINITIONS}")
    cuda_include_directories(${${DEPENDENCY}_INCLUDE_DIRECTORIES})
  endforeach()

  # Keep a list of the current modules that are actually CUDA targets.
  if(NOT CMH_CUDA_MODULE_NAMES)
    set(CMH_CUDA_MODULE_NAMES ${CMH_MODULE_NAME})
  else()
    list(APPEND CMH_CUDA_MODULE_NAMES ${CMH_MODULE_NAME})
  endif()
  set(CMH_CUDA_MODULE_NAMES ${CMH_CUDA_MODULE_NAMES} PARENT_SCOPE)

  # Get the compile definitions and include directories from the current
  # directory before creating the CUDA library as the cuda_add_library()
  # macro will modify these values.
  get_directory_property(CMH_CURRENT_COMPILE_DEFINITIONS COMPILE_DEFINITIONS)
  get_directory_property(CMH_CURRENT_INCLUDE_DIRECTORIES INCLUDE_DIRECTORIES)
endmacro(CMH_PREPARE_CUDA_COMPILER)

# This macro takes the directory properties from the CUDA library and sets
# them to be target interface properties.
macro(CMH_FINALIZE_CUDA_LIBRARY)
  # Once the CUDA library has been created, set the directory properties
  # (the compile definitions and include directories) to be interface
  # properties of the target.
  if(CMH_CURRENT_COMPILE_DEFINITIONS)
    set_property(TARGET ${CMH_MODULE_NAME} APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS
      ${CMH_CURRENT_COMPILE_DEFINITIONS})
  endif()
  if(CMH_CURRENT_INCLUDE_DIRECTORIES)
    set_property(TARGET ${CMH_MODULE_NAME} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
      ${CMH_CURRENT_INCLUDE_DIRECTORIES})
  endif()
endmacro(CMH_FINALIZE_CUDA_LIBRARY)

# This macro attempts to automatically set the path of the CUDA SDK based on
# the version of the CUDA Toolkit that was found.
macro(CMH_FIND_CUDA_SDK_HELPER)
  if(CUDA_TOOLKIT_ROOT_DIR AND CUDA_VERSION)
    # CUDA was found.

    # Initially set that we don't have to search for the SDK.
    set(CMH_FIND_CUDA_SDK FALSE)

    # If the CUDA SDK path is null, or it seems to be for the wrong version,
    # set that we have to try to find the SDK.
    if(NOT CUDA_SDK_ROOT_DIR)
      set(CMH_FIND_CUDA_SDK TRUE)
    else()
      if(WIN32)
        string(FIND ${CUDA_SDK_ROOT_DIR} "v${CUDA_VERSION}" CMH_FOUND_POSITION)
        if(CMH_FOUND_POSITION EQUAL -1)
          set(CMH_FIND_CUDA_SDK TRUE)
        endif()
      elseif(APPLE)
        string(FIND ${CUDA_SDK_ROOT_DIR} "CUDA-${CUDA_VERSION}" CMH_FOUND_POSITION)
        if(CMH_FOUND_POSITION EQUAL -1)
          set(CMH_FIND_CUDA_SDK TRUE)
        endif()
      endif()
    endif()

    # Attempt to search for the CUDA SDK if we need to.
    if(CMH_FIND_CUDA_SDK)
      if(WIN32)
        set(CUDA_SDK_PATH_GUESS "C:/ProgramData/NVIDIA Corporation/CUDA Samples/v${CUDA_VERSION}")
      elseif(APPLE)
        set(CUDA_SDK_PATH_GUESS "/Applications/Xcode.app/Contents/Developer/NVIDIA/CUDA-${CUDA_VERSION}/samples")
      endif()

      if(CUDA_SDK_PATH_GUESS)
        if(IS_DIRECTORY ${CUDA_SDK_PATH_GUESS})
          set(CUDA_SDK_ROOT_DIR ${CUDA_SDK_PATH_GUESS} CACHE PATH "Path to CUDA SDK directory." FORCE)
          message("Found CUDA SDK: ${CUDA_SDK_ROOT_DIR}")
        endif()
      endif()
    endif()
  endif()
endmacro(CMH_FIND_CUDA_SDK_HELPER)
