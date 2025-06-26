#
# SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#

if(NOT DEFINED ENV{ZOS_PATH})
    message(FATAL_ERROR "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif()

# Tell CMake that we are going to use Z80 version of GNU AS
include($ENV{ZOS_PATH}/kernel_headers/gnu-as/z80-toolchain-settings.cmake)

# We will need OBJCPY to extract a raw binary out of the generated ELF file
find_program(OBJCOPY NAMES ${CMAKE_C_COMPILER_PREFIX}objcopy REQUIRED)

set(ZOS_INCLUDE "$ENV{ZOS_PATH}/kernel_headers/gnu-as/")
set(CRT0_FLAGS "-T" "${CMAKE_SOURCE_DIR}/z80.ld")

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


# @param[in]           NAME name of the final binary
# @param[in, optional] SRCS (multivalue) list of source files for the component
# @param[in, optional] SRC_DIRS (multivalue) list of source directories to look for source files in (.c and .asm)
#                      ignored when SRCS is specified.
# @param[in, optional] EXCLUDE_SRCS (multivalue) used to exclude source files for the specified SRC_DIRS
# @param[in, optional] INCLUDES (multivalue) include directories
# @param[in, optional] COMPILE_FLAGS (multivalue)
# @param[in, optional] LINKER_FLAGS (multivalue)
# @param[in, optional] SECTIONS (multivalue) Sections to extract from the ELF file, .text and .data by default
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
        file(GLOB_RECURSE srcs CONFIGURE_DEPENDS ${EXEC_SRC_DIRS}/*.asm)
        if(EXEC_EXCLUDE_SRCS)
            list(REMOVE_ITEM srcs ${EXEC_EXCLUDE_SRCS})
        endif()
    else()
        message(FATAL_ERROR "Either SRCS or SRC_DIRS must be specified for zos_create_executable.")
    endif()

    # Prepare the compiler flags
    list(APPEND CMAKE_ASM_FLAGS ${EXEC_COMPILE_FLAGS})
    list(APPEND CMAKE_EXE_LINKER_FLAGS ${EXEC_LINKER_FLAGS})

    # Create the target right now
    set(ELF_NAME "${EXEC_NAME}.elf")
    add_executable(${ELF_NAME} ${srcs})

    # Prepare the included directories, prepend "-I" option
    set(include_dirs ${ZOS_INCLUDE} ${EXEC_INCLUDES})
    abs_path(include_dirs abs_include_dirs)
    target_include_directories(${ELF_NAME} PRIVATE ${abs_include_dirs})

    # Prepend all the libraries to include with `-l`
    target_link_libraries(${ELF_NAME} PUBLIC ${EXEC_REQUIRES})

    # Determine the sections to extract
    set(sections ${EXEC_SECTIONS})

    # Append sections to objcopy command
    foreach(section IN LISTS sections)
        list(APPEND objcopy_flags "--only-section=${section}")
    endforeach()

    set(output_bin "${CMAKE_BINARY_DIR}/${EXEC_NAME}.bin")
    add_custom_command(
        OUTPUT ${output_bin}
        COMMAND ${OBJCOPY} ${sections} -O binary ${ELF_NAME} ${output_bin}
        DEPENDS ${ELF_NAME}
        COMMENT "Extracting binary from ${ELF_NAME}"
    )

    add_custom_target(${EXEC_NAME} ALL DEPENDS ${output_bin})
endfunction()