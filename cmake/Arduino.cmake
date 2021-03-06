cmake_minimum_required(VERSION 2.8.5)
include(CMakeParseArguments)


#=============================================================================#
# [PUBLIC/USER]
# see documentation at top
#=============================================================================#
function(GENERATE_ARDUINO_LIBRARY INPUT_NAME)
    message(STATUS "Generating ${INPUT_NAME}")
    parse_generator_arguments(${INPUT_NAME} INPUT
                              ""                  # Options
                              ""                  # One Value Keywords
                              "SRCS;HDRS;LIBS"    # Multi Value Keywords
                              ${ARGN})

    set(ALL_LIBS)
    set(ALL_SRCS ${INPUT_SRCS} ${INPUT_HDRS})

    setup_arduino_core(CORE_LIB ${BOARD_ID})

    find_arduino_libraries(TARGET_LIBS "${ALL_SRCS}" "")

    set(LIB_DEP_INCLUDES)
    foreach(LIB_DEP ${TARGET_LIBS})
        set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${LIB_DEP}\"")
    endforeach()

    setup_arduino_libraries(ALL_LIBS  ${BOARD_ID} "${ALL_SRCS}" "" "${LIB_DEP_INCLUDES}" "")

    list(APPEND ALL_LIBS ${CORE_LIB} ${INPUT_LIBS})

    add_library(${INPUT_NAME} ${ALL_SRCS})

    get_arduino_flags(ARDUINO_C_FLAGS ARDUINO_CXX_FLAGS ARDUINO_LINK_FLAGS  ${BOARD_ID})

    set_target_properties(${INPUT_NAME} PROPERTIES
                COMPILE_FLAGS "${ARDUINO_CXX_FLAGS} ${COMPILE_FLAGS} ${LIB_DEP_INCLUDES}"
                LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")

    target_link_libraries(${INPUT_NAME} ${ALL_LIBS})

    SET(ARDUINO_CURRENT_LIBRARY ${INPUT_NAME} CACHE INTERNAL "ARDUINO_CURRENT_LIBRARY")
    SET(ARDUINO_CURRENT_LIBRARY_DIR ${CMAKE_CURRENT_SOURCE_DIR} CACHE INTERNAL "ARDUINO_CURRENT_LIBRARY_DIR")

    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/examples)
      ADD_ARDUINO_SKETCHS("examples")
      # subdirs("${CMAKE_CURRENT_SOURCE_DIR}/examples")
    endif()
endfunction()

#=============================================================================#
# [PUBLIC/USER]
# see documentation at top
#=============================================================================#
function(GENERATE_ARDUINO_FIRMWARE INPUT_NAME)
  message(STATUS "Generating ${INPUT_NAME}")
  parse_generator_arguments(${INPUT_NAME} INPUT
      ""
      "SKETCH"            # One Value Keywords
      "SRCS;HDRS;SERIAL;ARDLIBS"  # Multi Value Keywords
      ${ARGN})

  set(ALL_LIBS)
  set(ALL_SRCS)
  set(LIB_DEP_INCLUDES)

  setup_arduino_core(CORE_LIB ${BOARD_ID})

  if (NOT "${INPUT_SKETCH}" STREQUAL "")
    get_filename_component(INPUT_SKETCH "${INPUT_SKETCH}" ABSOLUTE)
    setup_arduino_sketch(${INPUT_NAME} ${INPUT_SKETCH} ALL_SRCS)
    if (IS_DIRECTORY "${INPUT_SKETCH}")
      set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${INPUT_SKETCH}\"")
    else ()
      get_filename_component(INPUT_SKETCH_PATH "${INPUT_SKETCH}" PATH)
      set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${INPUT_SKETCH_PATH}\"")
    endif ()
  endif ()

  set(ALL_SRCS ${ALL_SRCS} ${INPUT_SRCS} ${INPUT_HDRS})

  # EXTENSIFY_CPP(${SRCS})

  required_variables(VARS ALL_SRCS MSG "must define SRCS or SKETCH for target ${INPUT_NAME}")

  find_arduino_libraries(TARGET_LIBS "${ALL_SRCS}" "${INPUT_ARDLIBS}")
  foreach (LIB_DEP ${TARGET_LIBS})
    arduino_debug_msg("Arduino Library: ${LIB_DEP}")
    set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${LIB_DEP}\" -I\"${LIB_DEP}/src\"")
  endforeach ()

  setup_arduino_libraries(ALL_LIBS ${BOARD_ID} "${ALL_SRCS}" "${INPUT_ARDLIBS}" "${LIB_DEP_INCLUDES}" "")
  foreach (LIB_INCLUDES ${ALL_LIBS_INCLUDES})
    arduino_debug_msg("Arduino Library Includes: ${LIB_INCLUDES}")
    set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} ${LIB_INCLUDES}")
  endforeach ()

  list(APPEND ALL_LIBS ${CORE_LIB} ${INPUT_LIBS})

  if (ARDUINO_CURRENT_LIBRARY_DIR)
    set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${ARDUINO_CURRENT_LIBRARY_DIR}\" -I\"${ARDUINO_CURRENT_LIBRARY_DIR}/src\"")
  endif()

  setup_arduino_target(${INPUT_NAME} ${BOARD_ID} "${ALL_SRCS}" "${ALL_LIBS}" "${LIB_DEP_INCLUDES}" "")
  target_link_libraries(${INPUT_NAME} ${ARDUINO_CURRENT_LIBRARY})

  setup_arduino_upload(${INPUT_NAME})

  if (SERIAL_PORT_PATH)
    setup_serial_target(${INPUT_NAME} "${INPUT_SERIAL}" "${SERIAL_PORT_PATH}")
  endif ()

endfunction()

function(ADD_ARDUINO_SKETCHS SKETCH_DIR)
  if (SKETCH_DIR)
    get_filename_component(SKETCH_ABS_DIR "${SKETCH_DIR}" ABSOLUTE)
  endif()

  if (NOT SKETCH_ABS_DIR)
    set(SKETCH_ABS_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  file(GLOB SKETCHES RELATIVE ${SKETCH_ABS_DIR} ${SKETCH_ABS_DIR}/*)
  foreach(SKETCH ${SKETCHES})
    set(SKETCH_CONFIG "${SKETCH_ABS_DIR}/${SKETCH}/CMakeLists.txt")
    if(EXISTS ${SKETCH_CONFIG})
      # If there is a CMakeLists.txt file in the sketch's directory,
      # it is probably configuration settings. Include it.
      subdirs("${SKETCH_ABS_DIR}/${SKETCH}")
    else()
      setup_arduino_sketch_firmware(${SKETCH_ABS_DIR} ${SKETCH})
    endif()
  endforeach()
endfunction()

# function(ADD_ARDUINO_SKETCH SKETCH_DIR SKETCH)
#   get_filename_component(SKETCH "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
#   get_filename_component(SKETCH_DIR "${CMAKE_CURRENT_SOURCE_DIR}" DIRECTORY)
#   setup_arduino_sketch_firmware(${SKETCH_DIR} ${SKETCH})
# endfunction()

#=============================================================================#
#                        Internal Functions
#=============================================================================#

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# EXTENSIFY_CPP()
#
# Uisng language C++ for ino and pde file
#
#=============================================================================#

# macro(EXTENSIFY_CPP)
#   foreach(FILE ${ALL_SRCS})
#     get_filename_component(EXT ${FILE} EXT)
#     if (EXT STREQUAL ".ino" OR EXT STREQUAL ".pde")
#       set_source_files_properties(FILE PROPERTIES LANGUAGE CXX)
#     endif()
#   endforeach()
# endmacro()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# parse_generator_arguments(TARGET_NAME PREFIX OPTIONS ARGS MULTI_ARGS [ARG1 ARG2 .. ARGN])
#
#         PREFIX     - Parsed options prefix
#         OPTIONS    - List of options
#         ARGS       - List of one value keyword arguments
#         MULTI_ARGS - List of multi value keyword arguments
#         [ARG1 ARG2 .. ARGN] - command arguments [optional]
#
# Parses generator options from either variables or command arguments
#
#=============================================================================#
macro(PARSE_GENERATOR_ARGUMENTS TARGET_NAME PREFIX OPTIONS ARGS MULTI_ARGS)
  cmake_parse_arguments(${PREFIX} "${OPTIONS}" "${ARGS}" "${MULTI_ARGS}" ${ARGN})
  error_for_unparsed(${PREFIX})
  load_generator_settings(${TARGET_NAME} ${PREFIX} ${OPTIONS} ${ARGS} ${MULTI_ARGS})
endmacro()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# load_generator_settings(TARGET_NAME PREFIX [SUFFIX_1 SUFFIX_2 .. SUFFIX_N])
#
#         TARGET_NAME - The base name of the user settings
#         PREFIX      - The prefix name used for generator settings
#         SUFFIX_XX   - List of suffixes to load
#
#  Loads a list of user settings into the generators scope. User settings have
#  the following syntax:
#
#      ${BASE_NAME}${SUFFIX}
#
#  The BASE_NAME is the target name and the suffix is a specific generator settings.
#
#  For every user setting found a generator setting is created of the follwoing fromat:
#
#      ${PREFIX}${SUFFIX}
#
#  The purpose of loading the settings into the generator is to not modify user settings
#  and to have a generic naming of the settings within the generator.
#
#=============================================================================#
function(LOAD_GENERATOR_SETTINGS TARGET_NAME PREFIX)
  foreach (GEN_SUFFIX ${ARGN})
    if (${TARGET_NAME}_${GEN_SUFFIX} AND NOT ${PREFIX}_${GEN_SUFFIX})
      set(${PREFIX}_${GEN_SUFFIX} ${${TARGET_NAME}_${GEN_SUFFIX}} PARENT_SCOPE)
    endif ()
  endforeach ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_core(VAR_NAME BOARD_ID)
#
#        VAR_NAME    - Variable name that will hold the generated library name
#
# Creates the Arduino Core library for the specified board,
# each board gets it's own version of the library.
#
#=============================================================================#
function(setup_arduino_core VAR_NAME)
  set(CORE_LIB_NAME ${BOARD_ID}_CORE)
  if (BOARD_CORE_PATH)
    if (NOT TARGET ${CORE_LIB_NAME})

      set(ALL_SRCS)
      get_arduino_flags(ARDUINO_C_FLAGS ARDUINO_CXX_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)
      get_arduino_asm_flags(ARDUINO_ASM_FLAGS)

      # Find C files
      find_c_sources(C_FILES ${BOARD_CORE_PATH} True)
      if (C_FILES)
        set_source_files_properties(${C_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_C_FLAGS})
        set(ALL_SRCS ${C_FILES} ${ALL_SRCS})
      endif ()

      find_c_sources(C_FILES ${BOARD_VARIANT_PATH} True)
      if (C_FILES)
        set_source_files_properties(${C_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_C_FLAGS})
        set(ALL_SRCS ${C_FILES} ${ALL_SRCS})
      endif ()


      # Find CPP files
      find_cxx_sources(CXX_FILES ${BOARD_CORE_PATH} True)
      if (CXX_FILES)
        set_source_files_properties(${CXX_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_CXX_FLAGS})
        set(ALL_SRCS ${CXX_FILES} ${ALL_SRCS})
      endif ()

      find_cxx_sources(CXX_FILES ${BOARD_VARIANT_PATH} True)
      if (CXX_FILES)
        set_source_files_properties(${CXX_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_CXX_FLAGS})
        set(ALL_SRCS ${CXX_FILES} ${ALL_SRCS})
      endif ()

      # Finf ASM files
      find_asm_sources(ASM_FILES ${BOARD_CORE_PATH} True)
      if (ASM_FILES)
        set_source_files_properties(${ASM_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_ASM_FLAGS})
        set(ALL_SRCS ${ASM_FILES} ${ALL_SRCS})
      endif ()

      find_asm_sources(ASM_FILES ${BOARD_VARIANT_PATH} True)
      if (ASM_FILES)
        set_source_files_properties(${ASM_FILES} PROPERTIES COMPILE_FLAGS ${ARDUINO_ASM_FLAGS})
        set(ALL_SRCS ${ASM_FILES} ${ALL_SRCS})
      endif ()

      # Debian/Ubuntu fix
      list(REMOVE_ITEM ALL_SRCS "${BOARD_CORE_PATH}/main.cxx")

      #        message(-----)
      #        print_list(ALL_SRCS)
      #        message(-----)

      add_library(${CORE_LIB_NAME} ${ALL_SRCS})
      set_target_properties(${CORE_LIB_NAME} PROPERTIES LINK_FLAGS "${ARDUINO_LINK_FLAGS}")
    endif ()
    set(${VAR_NAME} ${CORE_LIB_NAME} PARENT_SCOPE)
  endif ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# get_arduino_flags(COMPILE_FLAGS LINK_FLAGS BOARD_ID)
#
#       COMPILE_C_FLAGS_VAR -Variable holding compiler C flags
#       COMPILE_CXX_FLAGS_VAR -Variable holding compiler C++ flags
#       LINK_FLAGS_VAR - Variable holding linker flags
#       BOARD_ID - The board id name
#
# Configures the the build settings for the specified Arduino Board.
#
#=============================================================================#
function(get_arduino_flags COMPILE_C_FLAGS_VAR COMPILE_CXX_FLAGS_VAR LINK_FLAGS_VAR BOARD_ID)
  if (BOARD_CORE_PATH)

    # output
    set(COMPILE_FLAGS "")

    if (DEFINED BUILD_VID)
      set(COMPILE_FLAGS "${COMPILE_FLAGS} -DUSB_VID=${BUILD_VID}")
    endif ()
    if (DEFINED BUILD_PID)
      set(COMPILE_FLAGS "${COMPILE_FLAGS} -DUSB_PID=${BUILD_PID}")
    endif ()
    set(COMPILE_FLAGS "${COMPILE_FLAGS} -I\"${BOARD_CORE_PATH}\"")
    foreach (LIB_PATH ${ARDUINO_LIBRARIES_PATHS})
      set(COMPILE_FLAGS "${COMPILE_FLAGS} -I\"${LIB_PATH}\"")
    endforeach ()

    if (BOARD_VARIANT_PATH)
      set(COMPILE_FLAGS "${COMPILE_FLAGS} -I\"${BOARD_VARIANT_PATH}\"")
    endif ()
    set(LINK_FLAGS "")

    get_arduino_c_flags(ARDUINO_C_FLAGS)
    get_arduino_cxx_flags(ARDUINO_CXX_FLAGS)
    get_arduino_linker_flags(ARDUINO_LINKER_FLAGS)

    # output
    set(${COMPILE_C_FLAGS_VAR} "${ARDUINO_C_FLAGS} ${COMPILE_FLAGS}" PARENT_SCOPE)
    set(${COMPILE_CXX_FLAGS_VAR} "${ARDUINO_CXX_FLAGS} ${COMPILE_FLAGS}" PARENT_SCOPE)
    set(${LINK_FLAGS_VAR} "${ARDUINO_LINKER_FLAGS} ${LINK_FLAGS}" PARENT_SCOPE)

  else ()
    message(FATAL_ERROR "No board core path has been set (${BOARD_CORE_PATH}), aborting.")
  endif ()
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# find_c_sources(VAR_NAME LIB_PATH RECURSE)
#
#        VAR_NAME - Variable name that will hold the detected sources
#        LIB_PATH - The base path
#        RECURSE  - Whether or not to recurse
#
# Finds all C sources located at the specified path.
#
#=============================================================================#
function(find_c_sources VAR_NAME LIB_PATH RECURSE)
  set(FILE_SEARCH_LIST
      ${LIB_PATH}/*.c
      ${LIB_PATH}/*.h)

  if (RECURSE)
    file(GLOB_RECURSE LIB_FILES ${FILE_SEARCH_LIST})
  else ()
    file(GLOB LIB_FILES ${FILE_SEARCH_LIST})
  endif ()

  if (LIB_FILES)
    set(${VAR_NAME} ${LIB_FILES} PARENT_SCOPE)
  endif ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# find_c_sources(VAR_NAME LIB_PATH RECURSE)
#
#        VAR_NAME - Variable name that will hold the detected sources
#        LIB_PATH - The base path
#        RECURSE  - Whether or not to recurse
#
# Finds all C++ sources located at the specified path.
#
#=============================================================================#
function(find_cxx_sources VAR_NAME LIB_PATH RECURSE)
  set(FILE_SEARCH_LIST
      ${LIB_PATH}/*.cpp
      ${LIB_PATH}/*.cc
      ${LIB_PATH}/*.cxx
      ${LIB_PATH}/*.hh
      ${LIB_PATH}/*.hxx)

  if (RECURSE)
    file(GLOB_RECURSE LIB_FILES ${FILE_SEARCH_LIST})
  else ()
    file(GLOB LIB_FILES ${FILE_SEARCH_LIST})
  endif ()

  if (LIB_FILES)
    set(${VAR_NAME} ${LIB_FILES} PARENT_SCOPE)
  endif ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# find_asm_sources(VAR_NAME LIB_PATH RECURSE)
#
#        VAR_NAME - Variable name that will hold the detected sources
#        LIB_PATH - The base path
#        RECURSE  - Whether or not to recurse
#
# Finds all S sources located at the specified path.
#
#=============================================================================#
function(find_asm_sources VAR_NAME LIB_PATH RECURSE)
  set(FILE_SEARCH_LIST
      ${LIB_PATH}/*.s)

  if (RECURSE)
    file(GLOB_RECURSE LIB_FILES ${FILE_SEARCH_LIST})
  else ()
    file(GLOB LIB_FILES ${FILE_SEARCH_LIST})
  endif ()

  if (LIB_FILES)
    set(${VAR_NAME} ${LIB_FILES} PARENT_SCOPE)
  endif ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# find_arduino_libraries(VAR_NAME SRCS ARDLIBS)
#
#      VAR_NAME - Variable name which will hold the results
#      SRCS     - Sources that will be analized
#      ARDLIBS  - Arduino libraries identified by name (e.g., Wire, SPI, Servo)
#
#     returns a list of paths to libraries found.
#
#  Finds all Arduino type libraries included in sources. Available libraries
#  are ${ARDUINO_SDK_PATH}/libraries and ${CMAKE_CURRENT_SOURCE_DIR}.
#
#  Also adds Arduino libraries specifically names in ALIBS.  We add ".h" to the
#  names and then process them just like the Arduino libraries found in the sources.
#
#  A Arduino library is a folder that has the same name as the include header.
#  For example, if we have a include "#include <LibraryName.h>" then the following
#  directory structure is considered a Arduino library:
#
#     LibraryName/
#          |- LibraryName.h
#          `- LibraryName.c
#
#  If such a directory is found then all sources within that directory are considred
#  to be part of that Arduino library.
#
#=============================================================================#
function(find_arduino_libraries VAR_NAME SRCS ARDLIBS)
  get_property(include_dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)

  set(ARDUINO_LIBS)
  foreach (SRC ${SRCS})

    # Skipping generated files. They are, probably, not exist yet.
    # TODO: Maybe it's possible to skip only really nonexisting files,
    # but then it wiil be less deterministic.
    get_source_file_property(_srcfile_generated ${SRC} GENERATED)
    # Workaround for sketches, which are marked as generated
    get_source_file_property(_sketch_generated ${SRC} GENERATED_SKETCH)

    if (NOT ${_srcfile_generated} OR ${_sketch_generated})
      if (NOT (EXISTS ${SRC} OR
          EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${SRC} OR
          EXISTS ${CMAKE_CURRENT_BINARY_DIR}/${SRC}))
        message(FATAL_ERROR "Invalid source file: ${SRC}")
      endif ()
      file(STRINGS ${SRC} SRC_CONTENTS)

      foreach (LIBNAME ${ARDLIBS})
        list(APPEND SRC_CONTENTS "#include <${LIBNAME}.h>")
      endforeach ()

      foreach (SRC_LINE ${SRC_CONTENTS})
        if ("#${SRC_LINE}#" MATCHES "^#[ \t]*#[ \t]*include[ \t]*[<\"]([^>\"]*)[>\"]#")
          get_filename_component(INCLUDE_NAME ${CMAKE_MATCH_1} NAME_WE)
          get_property(LIBRARY_SEARCH_PATH
              DIRECTORY     # Property Scope
              PROPERTY LINK_DIRECTORIES)

          set(LIBRARIE_PATHS
              ${ARDUINO_EXTRA_LIBRARIES_PATH}
              ${CMAKE_CURRENT_SOURCE_DIR}/${LOCAL_LIBS_PATH}
              ${CMAKE_CURRENT_SOURCE_DIR}/libs
              ${CMAKE_CURRENT_SOURCE_DIR}
              ${include_dirs}
              ${ARDUINO_LIBRARIES_PATHS}
              ${LIBRARY_SEARCH_PATH})

          foreach (LIB_SEARCH_PATH ${LIBRARIE_PATHS})
            if (EXISTS ${LIB_SEARCH_PATH}/${INCLUDE_NAME}/${CMAKE_MATCH_1})
              list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
              break()
            endif ()
            if (EXISTS ${LIB_SEARCH_PATH}/${INCLUDE_NAME}/src/${CMAKE_MATCH_1})
              list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
              break()
            endif ()
            get_source_file_property(_header_generated ${LIB_SEARCH_PATH}/${CMAKE_MATCH_1} GENERATED)
            if((EXISTS ${LIB_SEARCH_PATH}/${CMAKE_MATCH_1}) OR ${_header_generated})
              list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
              break()
            endif()
          endforeach ()
        endif ()
      endforeach ()
    endif ()
  endforeach ()

  if (ARDUINO_LIBS)
    list(REMOVE_DUPLICATES ARDUINO_LIBS)
  endif ()
  set(${VAR_NAME} ${ARDUINO_LIBS} PARENT_SCOPE)
  #  message(@@ ${ARDUINO_LIBS})
endfunction()

function(setup_arduino_library VAR_NAME BOARD_ID LIB_PATH COMPILE_FLAGS LINK_FLAGS)
  set(LIB_TARGETS)
  set(LIB_INCLUDES)

  get_filename_component(LIB_NAME ${LIB_PATH} NAME)
  set(TARGET_LIB_NAME ${BOARD_ID}_${LIB_NAME})
  if (NOT TARGET ${TARGET_LIB_NAME})
    string(REGEX REPLACE ".*/" "" LIB_SHORT_NAME ${LIB_NAME})

    # Detect if recursion is needed
    if (NOT DEFINED ${LIB_SHORT_NAME}_RECURSE)
      set(${LIB_SHORT_NAME}_RECURSE False)
    endif ()

    find_c_sources(LIB_C_FILES ${LIB_PATH} ${${LIB_SHORT_NAME}_RECURSE})
    find_cxx_sources(LIB_CXX_FILES ${LIB_PATH} ${${LIB_SHORT_NAME}_RECURSE})
    set(LIB_SRCS ${LIB_C_FILES} ${LIB_CXX_FILES})
    if (LIB_SRCS)
      message(STATUS "Generating ${TARGET_LIB_NAME} for library ${LIB_NAME}")
      arduino_debug_msg("Generating Arduino ${LIB_NAME} library")
      add_library(${TARGET_LIB_NAME} STATIC ${LIB_SRCS})
      include_directories(${LIB_PATH})
      include_directories(${LIB_PATH}/src)
      include_directories(${LIB_PATH}/utility)

      get_arduino_flags(ARDUINO_C_FLAGS ARDUINO_CXX_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)
      #      get_arduino_flags(ARDUINO_COMPILE_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)

      find_arduino_libraries(LIB_DEPS "${LIB_SRCS}" "")

      foreach (LIB_DEP ${LIB_DEPS})
        if (NOT DEP_LIB_SRCS STREQUAL TARGET_LIB_NAME AND DEP_LIB_SRCS)
          message(STATUS "Found library ${LIB_NAME} needs ${DEP_LIB_SRCS}")
        endif ()

        setup_arduino_library(DEP_LIB_SRCS ${BOARD_ID} ${LIB_DEP} "${COMPILE_FLAGS}" "${LINK_FLAGS}")
        # Do not link to this library. DEP_LIB_SRCS will always be only one entry
        # if we are looking at the same library.
        if (NOT DEP_LIB_SRCS STREQUAL TARGET_LIB_NAME)
          list(APPEND LIB_TARGETS ${DEP_LIB_SRCS})
          list(APPEND LIB_INCLUDES ${DEP_LIB_SRCS_INCLUDES})
        endif ()
      endforeach ()

      if (LIB_INCLUDES)
        string(REPLACE ";" " " LIB_INCLUDES "${LIB_INCLUDES}")
      endif ()

      set(ADDITIONAL_COMPILER_FLAGS "${LIB_INCLUDES} -I\"${LIB_PATH}\" -I\"${LIB_PATH}/src\" -I\"${LIB_PATH}/utility\" ${COMPILE_FLAGS}")

      set_source_files_properties(${LIB_C_FILES}
          PROPERTIES COMPILE_FLAGS "${ARDUINO_C_FLAGS} ${ADDITIONAL_COMPILER_FLAGS}")
      set_source_files_properties(${LIB_CXX_FILES}
          PROPERTIES COMPILE_FLAGS "${ARDUINO_CXX_FLAGS} ${ADDITIONAL_COMPILER_FLAGS}")
      set_target_properties(${TARGET_LIB_NAME} PROPERTIES
          LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")

      list(APPEND LIB_INCLUDES "-I\"${LIB_PATH}\" -I\"${LIB_PATH}/src\" -I\"${LIB_PATH}/utility\"")

      target_link_libraries(${TARGET_LIB_NAME} ${BOARD_ID}_CORE)
      list(APPEND LIB_TARGETS ${TARGET_LIB_NAME})

    endif ()
  else ()
    # Target already exists, skiping creating
    list(APPEND LIB_TARGETS ${TARGET_LIB_NAME})
  endif ()
  if (LIB_TARGETS)
    list(REMOVE_DUPLICATES LIB_TARGETS)
  endif ()
  set(${VAR_NAME} ${LIB_TARGETS} PARENT_SCOPE)
  set(${VAR_NAME}_INCLUDES ${LIB_INCLUDES} PARENT_SCOPE)
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_libraries(VAR_NAME BOARD_ID SRCS COMPILE_FLAGS LINK_FLAGS)
#
#        VAR_NAME    - Vairable wich will hold the generated library names
#        BOARD_ID    - Board ID
#        SRCS        - source files
#        COMPILE_FLAGS - Compile flags
#        LINK_FLAGS    - Linker flags
#
# Finds and creates all dependency libraries based on sources.
#
#=============================================================================#
function(setup_arduino_libraries VAR_NAME BOARD_ID SRCS ARDLIBS COMPILE_FLAGS LINK_FLAGS)
  set(LIB_TARGETS)
  set(LIB_INCLUDES)

  find_arduino_libraries(TARGET_LIBS "${SRCS}" ARDLIBS)
  foreach (TARGET_LIB ${TARGET_LIBS})
    # Create static library instead of returning sources
    setup_arduino_library(LIB_DEPS ${BOARD_ID} ${TARGET_LIB} "${COMPILE_FLAGS}" "${LINK_FLAGS}")
    list(APPEND LIB_TARGETS ${LIB_DEPS})
    list(APPEND LIB_INCLUDES ${LIB_DEPS_INCLUDES})
  endforeach ()

  set(${VAR_NAME} ${LIB_TARGETS} PARENT_SCOPE)
  set(${VAR_NAME}_INCLUDES ${LIB_INCLUDES} PARENT_SCOPE)
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_target(TARGET_NAME ALL_SRCS ALL_LIBS COMPILE_FLAGS LINK_FLAGS)
#
#        TARGET_NAME - Target name
#        BOARD_ID    - Arduino board ID
#        ALL_SRCS    - All sources
#        ALL_LIBS    - All libraries
#        COMPILE_FLAGS - Compile flags
#        LINK_FLAGS    - Linker flags
#
# Creates an Arduino firmware target.
#
#=============================================================================#
function(setup_arduino_target TARGET_NAME BOARD_ID ALL_SRCS ALL_LIBS COMPILE_FLAGS LINK_FLAGS)
  add_executable(${TARGET_NAME} ${ALL_SRCS})
  set_target_properties(${TARGET_NAME} PROPERTIES SUFFIX ".elf")

  get_arduino_flags(ARDUINO_C_FLAGS ARDUINO_CXX_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)

  set_target_properties(${TARGET_NAME} PROPERTIES
      COMPILE_FLAGS "${ARDUINO_CXX_FLAGS} ${COMPILE_FLAGS}"
      LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")
  target_link_libraries(${TARGET_NAME} ${ALL_LIBS})

  if (NOT EXECUTABLE_OUTPUT_PATH)
    set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
  endif ()
  set(TARGET_PATH ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})

  message(STATUS "Using ${CMAKE_OBJCOPY} for converting firmware image to hex")

  add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
      COMMAND ${CMAKE_OBJCOPY}
      ARGS ${ARDUINO_OBJCOPY_EEP_FLAGS}
      ${TARGET_PATH}.elf
      ${TARGET_PATH}.eep
      COMMENT "Generating EEP image"
      VERBATIM)

  # Convert firmware image to ASCII HEX format
  add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
      COMMAND ${CMAKE_OBJCOPY}
      ARGS ${ARDUINO_OBJCOPY_HEX_FLAGS}
      ${TARGET_PATH}.elf
      ${TARGET_PATH}.hex
      COMMENT "Generating HEX image"
      VERBATIM)

  # Display target size
  add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
      COMMAND iotor size "${CMAKE_CURRENT_SOURCE_DIR}"
      -p ${EXECUTABLE_OUTPUT_PATH}
      -n ${TARGET_NAME}
      COMMENT "Calculating image size"
      VERBATIM)

  # Create ${TARGET_NAME}-size target
  add_custom_target(${TARGET_NAME}-size
      COMMAND iotor size "${CMAKE_CURRENT_SOURCE_DIR}"
      -p ${EXECUTABLE_OUTPUT_PATH}
      -n ${TARGET_NAME}
      DEPENDS ${TARGET_NAME}
      COMMENT "Calculating ${TARGET_NAME} image size"
      VERBATIM)

endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_upload(TARGET_NAME)
#
#        TARGET_NAME - Target name
#
# Create an upload target (${TARGET_NAME}-upload) for the specified Arduino target.
#
#=============================================================================#
function(setup_arduino_upload TARGET_NAME)
  setup_arduino_bootloader_upload(${TARGET_NAME})

  # Add programmer support if defined
  #  if (PROGRAMMER_ID AND ${PROGRAMMER_ID}.protocol)
  #    setup_arduino_programmer_burn(${TARGET_NAME} ${BOARD_ID} ${PROGRAMMER_ID} ${PORT} "${AVRDUDE_FLAGS}")
  #    setup_arduino_bootloader_burn(${TARGET_NAME} ${BOARD_ID} ${PROGRAMMER_ID} ${PORT} "${AVRDUDE_FLAGS}")
  #  endif ()
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_bootloader_upload(TARGET_NAME)
#
#      TARGET_NAME - target name
#
# Set up target for upload firmware via the bootloader.
#
# The target for uploading the firmware is ${TARGET_NAME}-upload .
#
#=============================================================================#
function(setup_arduino_bootloader_upload TARGET_NAME)
  set(UPLOAD_TARGET ${TARGET_NAME}-upload)
  #  set(AVRDUDE_ARGS)
  #
  #  setup_arduino_bootloader_args(${BOARD_ID} ${TARGET_NAME} ${PORT} "${AVRDUDE_FLAGS}" AVRDUDE_ARGS)
  #
  #  if (NOT AVRDUDE_ARGS)
  #    message("Could not generate default avrdude bootloader args, aborting!")
  #    return()
  #  endif ()
  #
  #  if (NOT EXECUTABLE_OUTPUT_PATH)
  #    set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
  #  endif ()
  #  set(TARGET_PATH ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})
  #
  #  list(APPEND AVRDUDE_ARGS "-Uflash:w:${TARGET_PATH}.hex:i")
  #  list(APPEND AVRDUDE_ARGS "-Ueeprom:w:${TARGET_PATH}.eep:i")

  get_arduino_upload_flags(UPLOAD_ARGS ${TARGET_NAME})
  add_custom_target(${UPLOAD_TARGET}
      ${ARDUINO_UPLOAD_PROGRAM}
      ${UPLOAD_ARGS}
      DEPENDS ${TARGET_NAME}
      COMMENT "Uploading HEX image"
      VERBATIM)

  # Global upload target
  if (NOT TARGET upload)
    add_custom_target(upload)
  endif ()

  add_dependencies(upload ${UPLOAD_TARGET})
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_serial_target(TARGET_NAME CMD)
#
#         TARGET_NAME - Target name
#         CMD         - Serial terminal command
#
# Creates a target (${TARGET_NAME}-serial) for launching the serial termnial.
#
#=============================================================================#
function(setup_serial_target TARGET_NAME CMD SERIAL_PORT)
  string(CONFIGURE "${CMD}" FULL_CMD @ONLY)
  add_custom_target(${TARGET_NAME}-serial
      COMMAND ${FULL_CMD})
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# setup_arduino_sketch(TARGET_NAME SKETCH_PATH OUTPUT_VAR)
#
#      TARGET_NAME - Target name
#      SKETCH_PATH - Path to sketch directory
#      OUTPUT_VAR  - Variable name where to save generated sketch source
#
# Generates C++ sources from Arduino Sketch.
#=============================================================================#
function(setup_arduino_sketch TARGET_NAME SKETCH_PATH OUTPUT_VAR)
    get_filename_component(SKETCH_NAME "${SKETCH_PATH}" NAME)
    get_filename_component(SKETCH_PATH "${SKETCH_PATH}" ABSOLUTE)

    if(EXISTS "${SKETCH_PATH}")
        set(SKETCH_CPP  ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}_${SKETCH_NAME}.cpp)

        if (IS_DIRECTORY "${SKETCH_PATH}")
            # Sketch directory specified, try to find main sketch...
            set(MAIN_SKETCH ${SKETCH_PATH}/${SKETCH_NAME})

            if(EXISTS "${MAIN_SKETCH}.pde")
                set(MAIN_SKETCH "${MAIN_SKETCH}.pde")
            elseif(EXISTS "${MAIN_SKETCH}.ino")
                set(MAIN_SKETCH "${MAIN_SKETCH}.ino")
            else()
                message(FATAL_ERROR "Could not find main sketch (${SKETCH_NAME}.pde or ${SKETCH_NAME}.ino) at ${SKETCH_PATH}! Please specify the main sketch file path instead of directory.")
            endif()
        else()
            # Sektch file specified, assuming parent directory as sketch directory
            set(MAIN_SKETCH ${SKETCH_PATH})
            get_filename_component(SKETCH_PATH "${SKETCH_PATH}" PATH)
        endif()
        arduino_debug_msg("sketch: ${MAIN_SKETCH}")

        # Find all sketch files
        file(GLOB SKETCH_SOURCES ${SKETCH_PATH}/*.pde ${SKETCH_PATH}/*.ino)
        set(ALL_SRCS ${SKETCH_SOURCES})

        list(REMOVE_ITEM SKETCH_SOURCES ${MAIN_SKETCH})
        list(SORT SKETCH_SOURCES)

        generate_cpp_from_sketch("${MAIN_SKETCH}" "${SKETCH_SOURCES}" "${SKETCH_CPP}")

        # Regenerate build system if sketch changes
        add_custom_command(OUTPUT ${SKETCH_CPP}
                           COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
                           WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                           DEPENDS ${MAIN_SKETCH} ${SKETCH_SOURCES}
                           COMMENT "Regnerating ${SKETCH_NAME} Sketch")
        set_source_files_properties(${SKETCH_CPP} PROPERTIES GENERATED TRUE)
        # Mark file that it exists for find_file
        set_source_files_properties(${SKETCH_CPP} PROPERTIES GENERATED_SKETCH TRUE)

        set("${OUTPUT_VAR}" ${${OUTPUT_VAR}} ${SKETCH_CPP} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Sketch does not exist: ${SKETCH_PATH}")
    endif()
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# generate_cpp_from_sketch(MAIN_SKETCH_PATH SKETCH_SOURCES SKETCH_CPP)
#
#         MAIN_SKETCH_PATH - Main sketch file path
#         SKETCH_SOURCES   - Setch source paths
#         SKETCH_CPP       - Name of file to generate
#
# Generate C++ source file from Arduino sketch files.
#=============================================================================#
function(generate_cpp_from_sketch MAIN_SKETCH_PATH SKETCH_SOURCES SKETCH_CPP)
    file(WRITE ${SKETCH_CPP} "// Automatically generated by Iotor\n")
    file(READ  ${MAIN_SKETCH_PATH} MAIN_SKETCH)

    # remove comments
    remove_comments(MAIN_SKETCH MAIN_SKETCH_NO_COMMENTS)

    # find first statement
    string(REGEX MATCH "[\n][_a-zA-Z0-9]+[^\n]*" FIRST_STATEMENT "${MAIN_SKETCH_NO_COMMENTS}")
    string(FIND "${MAIN_SKETCH}" "${FIRST_STATEMENT}" HEAD_LENGTH)
    if ("${HEAD_LENGTH}" STREQUAL "-1")
        set(HEAD_LENGTH 0)
    endif()
    #message(STATUS "FIRST STATEMENT: ${FIRST_STATEMENT}")
    #message(STATUS "FIRST STATEMENT POSITION: ${HEAD_LENGTH}")
    string(LENGTH "${MAIN_SKETCH}" MAIN_SKETCH_LENGTH)

    string(SUBSTRING "${MAIN_SKETCH}" 0 ${HEAD_LENGTH} SKETCH_HEAD)
    #arduino_debug_msg("SKETCH_HEAD:\n${SKETCH_HEAD}")

    # find the body of the main pde
    math(EXPR BODY_LENGTH "${MAIN_SKETCH_LENGTH}-${HEAD_LENGTH}")
    string(SUBSTRING "${MAIN_SKETCH}" "${HEAD_LENGTH}+1" "${BODY_LENGTH}-1" SKETCH_BODY)
    #arduino_debug_msg("BODY:\n${SKETCH_BODY}")

    # write the file head
    file(APPEND ${SKETCH_CPP} "#line 1 \"${MAIN_SKETCH_PATH}\"\n${SKETCH_HEAD}")

    # Count head line offset (for GCC error reporting)
    file(STRINGS ${SKETCH_CPP} SKETCH_HEAD_LINES)
    list(LENGTH SKETCH_HEAD_LINES SKETCH_HEAD_LINES_COUNT)
    math(EXPR SKETCH_HEAD_OFFSET "${SKETCH_HEAD_LINES_COUNT}+2")

    # add arduino include header
    #file(APPEND ${SKETCH_CPP} "\n#line 1 \"autogenerated\"\n")
    file(APPEND ${SKETCH_CPP} "\n#line ${SKETCH_HEAD_OFFSET} \"${SKETCH_CPP}\"\n")
    if(ARDUINO_SDK_VERSION VERSION_LESS 1.0)
        file(APPEND ${SKETCH_CPP} "#include \"WProgram.h\"\n")
    else()
        file(APPEND ${SKETCH_CPP} "#include \"Arduino.h\"\n")
    endif()

    # add function prototypes
    foreach(SKETCH_SOURCE_PATH ${SKETCH_SOURCES} ${MAIN_SKETCH_PATH})
        arduino_debug_msg("Sketch: ${SKETCH_SOURCE_PATH}")
        file(READ ${SKETCH_SOURCE_PATH} SKETCH_SOURCE)
        remove_comments(SKETCH_SOURCE SKETCH_SOURCE)

        set(ALPHA "a-zA-Z")
        set(NUM "0-9")
        set(ALPHANUM "${ALPHA}${NUM}")
        set(WORD "_${ALPHANUM}")
        set(LINE_START "(^|[\n])")
        set(QUALIFIERS "[ \t]*([${ALPHA}]+[ ])*")
        set(TYPE "[${WORD}]+([ ]*[\n][\t]*|[ ])+")
        set(FNAME "[${WORD}]+[ ]?[\n]?[\t]*[ ]*")
        set(FARGS "[(]([\t]*[ ]*[*&]?[ ]?[${WORD}](\\[([${NUM}]+)?\\])*[,]?[ ]*[\n]?)*([,]?[ ]*[\n]?)?[)]")
        set(BODY_START "([ ]*[\n][\t]*|[ ]|[\n])*{")
        set(PROTOTYPE_PATTERN "${LINE_START}${QUALIFIERS}${TYPE}${FNAME}${FARGS}${BODY_START}")

        string(REGEX MATCHALL "${PROTOTYPE_PATTERN}" SKETCH_PROTOTYPES "${SKETCH_SOURCE}")

        # Write function prototypes
        file(APPEND ${SKETCH_CPP} "\n//=== START Forward: ${SKETCH_SOURCE_PATH}\n")
        foreach(SKETCH_PROTOTYPE ${SKETCH_PROTOTYPES})
            string(REPLACE "\n" " " SKETCH_PROTOTYPE "${SKETCH_PROTOTYPE}")
            string(REPLACE "{" "" SKETCH_PROTOTYPE "${SKETCH_PROTOTYPE}")
            arduino_debug_msg("\tprototype: ${SKETCH_PROTOTYPE};")
            # " else if(var == other) {" shoudn't be listed as prototype
            if(NOT SKETCH_PROTOTYPE MATCHES "(if[ ]?[\n]?[\t]*[ ]*[)])")
                file(APPEND ${SKETCH_CPP} "${SKETCH_PROTOTYPE};\n")
            else()
                arduino_debug_msg("\trejected prototype: ${SKETCH_PROTOTYPE};")
            endif()
            # file(APPEND ${SKETCH_CPP} "${SKETCH_PROTOTYPE};\n")
        endforeach()
        file(APPEND ${SKETCH_CPP} "//=== END Forward: ${SKETCH_SOURCE_PATH}\n")
    endforeach()

    # Write Sketch CPP source
    get_num_lines("${SKETCH_HEAD}" HEAD_NUM_LINES)
    file(APPEND ${SKETCH_CPP} "#line ${HEAD_NUM_LINES} \"${MAIN_SKETCH_PATH}\"\n")
    file(APPEND ${SKETCH_CPP} "\n${SKETCH_BODY}")
    foreach (SKETCH_SOURCE_PATH ${SKETCH_SOURCES})
        file(READ ${SKETCH_SOURCE_PATH} SKETCH_SOURCE)
        file(APPEND ${SKETCH_CPP} "\n//=== START : ${SKETCH_SOURCE_PATH}\n")
        file(APPEND ${SKETCH_CPP} "#line 1 \"${SKETCH_SOURCE_PATH}\"\n")
        file(APPEND ${SKETCH_CPP} "${SKETCH_SOURCE}")
        file(APPEND ${SKETCH_CPP} "\n//=== END : ${SKETCH_SOURCE_PATH}\n")
    endforeach()
endfunction()

function(setup_arduino_sketch_firmware SKETCH_DIR SKETCH)
  set(SKETCH_SOURCE_CPP "${SKETCH_DIR}/${SKETCH}/${SKETCH}.cpp")
  set(SKETCH_SOURCE_INO "${SKETCH_DIR}/${SKETCH}/${SKETCH}.ino")
  set(SKETCH_SOURCE_PDE "${SKETCH_DIR}/${SKETCH}/${SKETCH}.pde")

  get_filename_component(SKETCH_DIR_NAME ${SKETCH_DIR} NAME)
  set(SKETCH_TARGET_NAME ${SKETCH})
  if(NOT ${SKETCH_DIR_NAME} STREQUAL "sketches" AND NOT ${SKETCH_DIR_NAME} STREQUAL "examples")
    set(SKETCH_TARGET_NAME "${SKETCH_DIR_NAME}_${SKETCH_TARGET_NAME}")
  endif()

  if(EXISTS ${SKETCH_SOURCE_CPP})
    GENERATE_ARDUINO_FIRMWARE(${SKETCH_TARGET_NAME}
      SRCS ${SKETCH_SOURCE_CPP})
  elseif(EXISTS ${SKETCH_SOURCE_INO})
    GENERATE_ARDUINO_FIRMWARE(${SKETCH_TARGET_NAME}
      SKETCH ${SKETCH_SOURCE_INO})
  elseif(EXISTS ${SKETCH_SOURCE_PDE})
    GENERATE_ARDUINO_FIRMWARE(${SKETCH_TARGET_NAME}
      SKETCH ${SKETCH_SOURCE_PDE})
  endif()
endfunction(setup_arduino_sketch_firmware)

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# print_list(SETTINGS_LIST)
#
#      SETTINGS_LIST - Variables name of settings list
#
# Print list settings and names (see load_arduino_syle_settings()).
#=============================================================================#
function(PRINT_LIST SETTINGS_LIST)
  if (${SETTINGS_LIST})
    set(MAX_LENGTH 0)
    foreach (ENTRY_NAME ${${SETTINGS_LIST}})
      string(LENGTH "${ENTRY_NAME}" CURRENT_LENGTH)
      if (CURRENT_LENGTH GREATER MAX_LENGTH)
        set(MAX_LENGTH ${CURRENT_LENGTH})
      endif ()
    endforeach ()
    foreach (ENTRY_NAME ${${SETTINGS_LIST}})
      string(LENGTH "${ENTRY_NAME}" CURRENT_LENGTH)
      math(EXPR PADDING_LENGTH "${MAX_LENGTH}-${CURRENT_LENGTH}")
      set(PADDING "")
      foreach (X RANGE ${PADDING_LENGTH})
        set(PADDING "${PADDING} ")
      endforeach ()
      message(STATUS "   ${PADDING}${ENTRY_NAME}: ${${ENTRY_NAME}.name}")
    endforeach ()
  endif ()
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
#  arduino_debug_on()
#
# Enables Arduino module debugging.
#=============================================================================#
function(ARDUINO_DEBUG_ON)
  set(ARDUINO_DEBUG True PARENT_SCOPE)
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
#  arduino_debug_off()
#
# Disables Arduino module debugging.
#=============================================================================#
function(ARDUINO_DEBUG_OFF)
  set(ARDUINO_DEBUG False PARENT_SCOPE)
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# arduino_debug_msg(MSG)
#
#        MSG - Message to print
#
# Print Arduino debugging information. In order to enable printing
# use arduino_debug_on() and to disable use arduino_debug_off().
#=============================================================================#
function(ARDUINO_DEBUG_MSG MSG)
  if (ARDUINO_DEBUG)
    message("## ${MSG}")
  endif ()
endfunction()


#=============================================================================#
# [PRIVATE/INTERNAL]
#
# remove_comments(SRC_VAR OUT_VAR)
#
#        SRC_VAR - variable holding sources
#        OUT_VAR - variable holding sources with no comments
#
# Removes all comments from the source code.
#=============================================================================#
function(REMOVE_COMMENTS SRC_VAR OUT_VAR)
  string(REGEX REPLACE "[\\./\\\\]" "_" FILE "${NAME}")

  set(SRC ${${SRC_VAR}})

  #message(STATUS "removing comments from: ${FILE}")
  #file(WRITE "${CMAKE_BINARY_DIR}/${FILE}_pre_remove_comments.txt" ${SRC})
  #message(STATUS "\n${SRC}")

  # remove all comments
  string(REGEX REPLACE "([/][/][^\n]*)|([/][\\*]([^\\*]|([\\*]+[^/\\*]))*[\\*]+[/])" "" OUT "${SRC}")

  #file(WRITE "${CMAKE_BINARY_DIR}/${FILE}_post_remove_comments.txt" ${SRC})
  #message(STATUS "\n${SRC}")

  set(${OUT_VAR} ${OUT} PARENT_SCOPE)

endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# get_num_lines(DOCUMENT OUTPUT_VAR)
#
#        DOCUMENT   - Document contents
#        OUTPUT_VAR - Variable which will hold the line number count
#
# Counts the line number of the document.
#=============================================================================#
function(GET_NUM_LINES DOCUMENT OUTPUT_VAR)
  string(REGEX MATCHALL "[\n]" MATCH_LIST "${DOCUMENT}")
  list(LENGTH MATCH_LIST NUM)
  set(${OUTPUT_VAR} ${NUM} PARENT_SCOPE)
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# required_variables(MSG msg VARS var1 var2 .. varN)
#
#        MSG  - Message to be displayed in case of error
#        VARS - List of variables names to check
#
# Ensure the specified variables are not empty, otherwise a fatal error is emmited.
#=============================================================================#
function(REQUIRED_VARIABLES)
  cmake_parse_arguments(INPUT "" "MSG" "VARS" ${ARGN})
  error_for_unparsed(INPUT)
  foreach (VAR ${INPUT_VARS})
    if ("${${VAR}}" STREQUAL "")
      message(FATAL_ERROR "${VAR} not set: ${INPUT_MSG}")
    endif ()
  endforeach ()
endfunction()

#=============================================================================#
# [PRIVATE/INTERNAL]
#
# error_for_unparsed(PREFIX)
#
#        PREFIX - Prefix name
#
# Emit fatal error if there are unparsed argument from cmake_parse_arguments().
#=============================================================================#
function(ERROR_FOR_UNPARSED PREFIX)
  set(ARGS "${${PREFIX}_UNPARSED_ARGUMENTS}")
  if (NOT ("${ARGS}" STREQUAL ""))
    message(FATAL_ERROR "unparsed argument: ${ARGS}")
  endif ()
endfunction()

#=============================================================================#
#                          Initialization
#=============================================================================#
if (NOT ARDUINO_INITIALIZED)
  # Setup Toolchain
  set(TOOLCHAIN_FILE_PATH ${CMAKE_BINARY_DIR}/CMakeFiles/ArduinoInfomation.cmake)
  execute_process(COMMAND iotor cmake ${CMAKE_CURRENT_SOURCE_DIR} -o${TOOLCHAIN_FILE_PATH})
  include(${TOOLCHAIN_FILE_PATH})

  set(ARDUINO_LIBRARIES_PATHS)

  find_file(ARDUINO_BUILTIN_LIBRARIES_PATH
      NAMES libraries
      PATHS ${ARDUINO_SDK_PATH}
      DOC "Path to directory containing the Arduino builtin libraries."
      NO_SYSTEM_ENVIRONMENT_PATH)

  if (ARDUINO_BUILTIN_LIBRARIES_PATH)
    list(APPEND ARDUINO_LIBRARIES_PATHS ${ARDUINO_BUILTIN_LIBRARIES_PATH})
  endif ()

  find_file(ARDUINO_BOOK_LIBRARIES_PATH
      NAMES libraries
      PATHS ${ARDUINO_BOOK_PATH}
      DOC "Path to directory containing the Arduino custom libraries."
      NO_SYSTEM_ENVIRONMENT_PATH)

  if (ARDUINO_BOOK_LIBRARIES_PATH)
    list(APPEND ARDUINO_LIBRARIES_PATHS ${ARDUINO_BOOK_LIBRARIES_PATH})
  endif ()

  find_file(ARDUINO_PLATFORM_LIBRARIES_PATH
      NAMES libraries
      PATHS ${RUNTIME_PLATFORM_PATH}
      DOC "Path to directory containing the Arduino platform libraries."
      NO_SYSTEM_ENVIRONMENT_PATH)

  if (ARDUINO_PLATFORM_LIBRARIES_PATH)
    list(APPEND ARDUINO_LIBRARIES_PATHS ${ARDUINO_PLATFORM_LIBRARIES_PATH})
  endif ()

  set(ARDUINO_INITIALIZED True)
  mark_as_advanced(
      ARDUINO_BUILTIN_LIBRARIES_PATH
      ARDUINO_BOOK_LIBRARIES_PATH
      ARDUINO_PLATFORM_LIBRARIES_PATH
      ARDUINO_LIBRARIES_PATHS)
endif ()
