#
# SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#

if(NOT DEFINED ENV{ZOS_PATH})
    message(FATAL_ERROR "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif()

# Need find our compiler: SDCC
find_program(SDCC NAMES sdcc REQUIRED)
find_program(SDLD NAMES sdldz80 REQUIRED)
find_program(SDAS NAMES sdasz80 REQUIRED)
find_program(OBJCOPY NAMES sdobjcopy objcopy gobjcopy REQUIRED)
# For Zeal 8-bit Computer we have a custom CRT0
set(SDCC_REL0 "$ENV{ZOS_PATH}/kernel_headers/sdcc/bin/zos_crt0.rel")
set(SDCC_FLAGS "-mz80" "-c" "--codeseg" "TEXT")
set(SDCC_INCLUDES "$ENV{ZOS_PATH}/kernel_headers/sdcc/include/")

set(SDLD_REQUIRES "z80")
set(SDLD_FLAGS "-n" "-mjwx" "-i" "-b" "_HEADER=0x4000" "-k" "$ENV{ZOS_PATH}/kernel_headers/sdcc/lib")


function(abs_path paths out_paths)
    set(abs_paths "")
    foreach(path IN LISTS ${paths})
        cmake_path(IS_ABSOLUTE path is_abs)
        if(NOT is_abs)
            list(APPEND abs_paths "${CMAKE_CURRENT_SOURCE_DIR}/${path}")
        else()
            list(APPEND abs_paths "${path}")
        endif()
    endforeach()
    set(${out_paths} "${abs_paths}" PARENT_SCOPE)
endfunction()


# Split the given source list into two: the C files and the assembly files
function(separate_source_files srcs c_files asm_files)
    set(loc_c_files "")
    set(loc_asm_files "")
    foreach(file IN LISTS srcs)
        if(file MATCHES "\\.c$")
            list(APPEND loc_c_files ${file})
        elseif(file MATCHES "\\.asm$")
            list(APPEND loc_asm_files ${file})
        endif()
    endforeach()

    abs_path(loc_c_files abs_c_files)
    abs_path(loc_asm_files abs_asm_files)

    set(${c_files} "${abs_c_files}" PARENT_SCOPE)
    set(${asm_files} "${abs_asm_files}" PARENT_SCOPE)
endfunction()


function(generate_rel_path src rel_path)
    set(obj "")
    # Replace the extension with .rel
    # Keep the structure of the source files, get the path relatively to the base dir
    cmake_path(REPLACE_EXTENSION src ".rel" OUTPUT_VARIABLE obj)
    # Make it relative to the base directory
    cmake_path(RELATIVE_PATH obj BASE_DIRECTORY ${CMAKE_SOURCE_DIR})
    set(${rel_path} "${CMAKE_BINARY_DIR}/${obj}" PARENT_SCOPE)
    # Make sure the file is inside our source, print an error else (absolute path)
    if(obj MATCHES "^\\.\\./")
        message(FATAL_ERROR "Source file ${src} is outside the project (${CMAKE_SOURCE_DIR}).")
    endif()
endfunction()

# @param[in]           NAME name of the final binary
# @param[in, optional] SRCS (multivalue) list of source files for the component
# @param[in, optional] SRC_DIRS (multivalue) list of source directories to look for source files in (.c and .asm)
#                      ignored when SRCS is specified.
# @param[in, optional] EXCLUDE_SRCS (multivalue) used to exclude source files for the specified SRC_DIRS
# @param[in, optional] INCLUDES (multivalue) include directories
# @param[in, optional] COMPILE_FLAGS (multivalue)
# @param[in, optional] LINKER_FLAGS (multivalue)
# @param[in, optional] REQUIRES (multivalue) required libraries to link
function(zos_create_executable)
    set(multiValueArgs SRCS SRC_DIRS EXCLUDE_SRCS INCLUDES REQUIRES DEPENDS COMPILE_FLAGS LINKER_FLAGS)
    cmake_parse_arguments(EXEC "" "NAME" "${multiValueArgs}" ${ARGN})

    if(NOT EXEC_NAME)
        message(FATAL_ERROR "The NAME parameter is required for zos_create_executable.")
    endif()

    # Get the list of all the source files
    set(srcs "")
    if(EXEC_SRCS)
        set(srcs ${EXEC_SRCS})
    elseif(EXEC_SRC_DIRS)
        file(GLOB_RECURSE srcs CONFIGURE_DEPENDS
            ${EXEC_SRC_DIRS}/*.c
            ${EXEC_SRC_DIRS}/*.asm
        )
        if(EXEC_EXCLUDE_SRCS)
            list(REMOVE_ITEM srcs ${EXEC_EXCLUDE_SRCS})
        endif()
    else()
        message(FATAL_ERROR "Either SRCS or SRC_DIRS must be specified for zos_create_executable.")
    endif()

    # Prepare the sources into two lists: C files and assembly files
    set(c_srcs "")
    set(asm_srcs "")
    if("${srcs}" STREQUAL "")
        message(FATAL_ERROR "No source file was provided!")
    endif()
    separate_source_files("${srcs}" c_srcs asm_srcs)

    # Prepare the compiler flags
    set(compiler_flags ${SDCC_FLAGS})
    list(APPEND compiler_flags ${EXEC_COMPILE_FLAGS})

    # Prepare the included directories, prepend "-I" option
    set(include_dirs ${SDCC_INCLUDES})
    list(APPEND include_dirs ${EXEC_INCLUDES})
    abs_path(include_dirs abs_include_dirs)
    list(TRANSFORM abs_include_dirs PREPEND "-I")

    # Create object (REL) files for the C sources
    set(obj_files "")
    foreach(src IN LISTS c_srcs)
        set(obj "")
        generate_rel_path("${src}" obj)
        add_custom_command(
            OUTPUT ${obj}
            COMMAND ${SDCC} ${SDCC_FLAGS} ${abs_include_dirs} ${compiler_flags} -o ${obj} ${src}
            DEPENDS ${src}
            COMMENT "Compiling ${src}"
        )
        list(APPEND obj_files ${obj})
    endforeach()

    # Do the same for the assembly files
    foreach(src IN LISTS asm_srcs)
        set(obj "")
        # Replace the extension with .rel
        cmake_path(REPLACE_EXTENSION src ".rel" OUTPUT_VARIABLE obj)
        # Keep the structure of the source files, get the path relatively to the base dir
        cmake_path(RELATIVE_PATH obj BASE_DIRECTORY ${CMAKE_SOURCE_DIR})
        set(obj ${CMAKE_BINARY_DIR}/${obj})
        add_custom_command(
            OUTPUT ${obj}
            COMMAND ${SDAS} ${SDCC_FLAGS} ${abs_include_dirs} ${compiler_flags} -o ${obj} ${src}
            DEPENDS ${src}
            COMMENT "Assembling ${src}"
        )
        list(APPEND obj_files ${obj})
    endforeach()

    # Prepend all the libraries to include with `-l`
    set(libraries "")
    foreach(lib IN LISTS SDLD_REQUIRES EXEC_REQUIRES)
        list(APPEND libraries "-l" "${lib}")
    endforeach()

    # Link all the object files into a single binary
    set(output_hex "${CMAKE_BINARY_DIR}/${EXEC_NAME}.ihx")
    add_custom_command(
        OUTPUT ${output_hex}
        COMMAND ${SDLD} ${SDLD_FLAGS} ${LINKER_FLAGS} ${libraries} ${output_hex} ${SDCC_REL0} ${obj_files}
        DEPENDS ${SDCC_REL0} ${obj_files} ${EXEC_DEPENDS}
        COMMENT "Linking binary"
    )

    set(output_bin "${CMAKE_BINARY_DIR}/${EXEC_NAME}.bin")
    add_custom_command(
        OUTPUT ${output_bin}
        COMMAND ${OBJCOPY} --input-target=ihex --output-target=binary ${output_hex} ${output_bin}
        DEPENDS ${output_hex}
        COMMENT "Extracting binary from hex"
    )

    add_custom_target(${EXEC_NAME} ALL DEPENDS ${output_bin})
endfunction()