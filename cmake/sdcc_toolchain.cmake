set(CMAKE_MODULE_PATH "$ENV{ZOS_PATH}/cmake/Modules" ${CMAKE_MODULE_PATH})

set(CMAKE_SYSTEM_NAME ZOS)
set(CMAKE_SYSTEM_PROCESSOR Z80)

# Disable C++
set(CMAKE_CXX_COMPILER "" CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "")

# Force C language, even if the project only needs ASM
set(CMAKE_C_COMPILER sdcc)
set(CMAKE_C_DEPFILE_STYLE NONE)

set(CMAKE_ASM_COMPILER sdasz80)
set(CMAKE_ASM_COMPILER_ID sdasz80)

set(CMAKE_LINKER sdldz80)
set(CMAKE_OBJCOPY sdobjcopy)

# If CMake fails to auto-detect anything, uncomment these lines:
# set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "")
# set(CMAKE_C_COMPILER_FORCED TRUE CACHE INTERNAL "")
#set(CMAKE_ASM_COMPILER_WORKS TRUE CACHE INTERNAL "")


# Compilation and linking commands
# By default, provide kernel headers for SDCC and put the code in `TEXT` section
set(CMAKE_C_FLAGS_INIT "-mz80 -I$ENV{ZOS_PATH}/kernel_headers/sdcc/include/ --codeseg TEXT")

# Default linking options
set(SDCC_REL0 "$ENV{ZOS_PATH}/kernel_headers/sdcc/bin/zos_crt0.rel")
set(ZOS_LINK_FLAGS  "-n" # No echo of commands to STDOUT
                    "-b _HEADER=0x4000"
                    "-i" # Intel Hex output
                    "-y" # SDCDB Debug output
                    "-k $ENV{ZOS_PATH}/kernel_headers/sdcc/lib" # Library path
                    "-l z80" # Link the Z80 library
    )
# Concatenate the variable above since CMake wants a single string as init flags
string(REPLACE ";" " " CMAKE_EXE_LINKER_FLAGS_INIT "${ZOS_LINK_FLAGS}")

set(CMAKE_ASM_FLAGS_INIT "-I$ENV{ZOS_PATH}/kernel_headers/sdcc/include/")

# Default linker variables, can be overriden by the assembler
set(CMAKE_ASM_SOURCE_FILE_EXTENSIONS asm)
set(CMAKE_ASM_OUTPUT_EXTENSION ".rel")
set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>"
)
set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")
set(CMAKE_ASM_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")

# Link CMake target libraries with sdld
function(zos_link_libraries target visibility)
    # Parse arguments, skipping visibility keywords
    set(libs ${ARGN})

    foreach(lib ${libs})
        # Skip visibility keywords if they appear in the list
        if(lib STREQUAL "PRIVATE" OR lib STREQUAL "PUBLIC" OR lib STREQUAL "INTERFACE")
            continue()
        endif()

        # Check if it's a target AND if it's a library we're building (not imported)
        if(TARGET ${lib})
            get_target_property(lib_type ${lib} TYPE)
            get_target_property(is_imported ${lib} IMPORTED)

            # Only use special SDCC handling for our own static libraries
            if(lib_type STREQUAL "STATIC_LIBRARY" AND NOT is_imported)
                # Get the library output directory
                get_target_property(lib_dir ${lib} ARCHIVE_OUTPUT_DIRECTORY)
                if(NOT lib_dir)
                    set(lib_dir ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY})
                endif()

                # Get library name
                get_target_property(lib_name ${lib} OUTPUT_NAME)
                if(NOT lib_name)
                    set(lib_name ${lib})
                endif()

                set(lib_path "${lib_dir}/${lib_name}.lib")

                # Add each library with its own -k and -l flags
                target_link_options(${target} ${visibility}
                    "SHELL:-k ${lib_dir}"
                    "SHELL:-l ${lib_name}.lib"
                )

                # Add include directories from the library
                get_target_property(lib_includes ${lib} INTERFACE_INCLUDE_DIRECTORIES)
                if(lib_includes)
                    target_include_directories(${target} ${visibility} ${lib_includes})
                endif()

                # Add dependency
                add_dependencies(${target} ${lib})
                set_source_files_properties(${lib_path} PROPERTIES EXTERNAL_OBJECT true)
                target_sources(${target} PRIVATE ${lib_path})

            else()
                # Use the ORIGINAL command, not the macro
                target_link_libraries(${target} ${visibility} ${lib})
            endif()
        else()
            # Use the ORIGINAL command, not the macro
            target_link_libraries(${target} ${visibility} ${lib})
        endif()
    endforeach()
endfunction()
