

if(NOT DEFINED ZOS_TOOLCHAIN)
    set(ZOS_TOOLCHAIN sdcc)
	message(WARNING "ZOS_TOOLCHAIN is not defined, defaulting to SDCC.")
endif()

# Fallback to build dir if CMAKE_RUNTIME_OUTPUT_DIRECTORY is empty
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
endif()

set(CMAKE_TOOLCHAIN_FILE $ENV{ZOS_PATH}/cmake/${ZOS_TOOLCHAIN}_toolchain.cmake)

# Helper to convert an ELF file to a raw binary
function(elf_to_bin target)
    set(bin_file "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${target}.bin")
    add_custom_target(${target}_bin ALL
        COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${target}> ${bin_file}
        DEPENDS $<TARGET_FILE:${target}>
        COMMENT "Converting ELF to raw binary"
        VERBATIM
    )
    set_property(TARGET ${target}_bin PROPERTY RAW_BINARY ${bin_file})
endfunction()

# Helper to convert an IHX file to a raw binary
function(ihx_to_bin target)
    set(bin_file "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${target}.bin")

    add_custom_target(${target}_bin ALL
        COMMAND ${CMAKE_OBJCOPY} --input-target=ihex --output-target=binary $<TARGET_FILE:${target}> ${bin_file}
        DEPENDS $<TARGET_FILE:${target}>
        COMMENT "Converting IHX to raw binary"
        VERBATIM
    )
    set_property(TARGET ${target}_bin PROPERTY RAW_BINARY ${bin_file})
endfunction()


function(zos_add_asset target asset_file)
    get_filename_component(asset_name "${asset_file}" NAME_WE)
    set(asm_dir "${CMAKE_CURRENT_BINARY_DIR}/assets")
    file(MAKE_DIRECTORY "${asm_dir}")
    set(asm_file_path "${asm_dir}/${asset_name}.asm")
    set(bin_file "${CMAKE_SOURCE_DIR}/${asset_file}")

    add_custom_command(
        OUTPUT "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "\t.area .rodata"                >  "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "\t.globl __${asset_name}_start" >> "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "\t.globl __${asset_name}_end"   >> "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "__${asset_name}_start:"         >> "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "\t.incbin \"${bin_file}\""      >> "${asm_file_path}"
        COMMAND ${CMAKE_COMMAND} -E echo "__${asset_name}_end:"           >> "${asm_file_path}"
        DEPENDS "${bin_file}"
        COMMENT "Generating ASM file for asset ${asset_name}"
        VERBATIM
    )

    # Add the generated ASM file to the target
    set_source_files_properties("${asm_file_path}" PROPERTIES GENERATED TRUE)
    target_sources("${target}" PRIVATE "${asm_file_path}")
endfunction()

# Add a list of assets to the current project: this function will generate one assembly file
# per asset and add it to the current project source files
function(zos_add_assets target)
    foreach(file IN LISTS ARGN)
        zos_add_asset(${target} ${file})
    endforeach()
endfunction()

# Convert the generated binary (IHX, ELF, ...) into a raw binary
function(zos_add_outputs target)
    if(ZOS_TOOLCHAIN STREQUAL "sdcc")
        ihx_to_bin(${target})
    elseif(ZOS_TOOLCHAIN STREQUAL "gnu")
        elf_to_bin(${target})
    endif()
endfunction()


function(zos_use_search)
    cmake_parse_arguments(PARSE_ARGV 0 ZOS_USE_SEARCH
        "" "OUT" "")

    if(NOT ZOS_USE_SEARCH_OUT)
        message(FATAL_ERROR "zos_use_search: OUT <varname> mus tbe provided")
    endif()

    set(result "")

    foreach(libname IN LISTS ZOS_USE_SEARCH_UNPARSED_ARGUMENTS)
        # Extract the prefix (before first underscore) or whole name
        string(REGEX MATCH "^[^_]+" prefix ${libname})

        # Uppercase the prefix for env var lookup
        string(TOUPPER "${prefix}" prefix_upper)

        # Build possible env var names
        set(env_candidates "${prefix_upper}_SDK_PATH" "${prefix_upper}_PATH")

        # Find the first existing env var
        unset(sdk_path)
        foreach(env_var IN LISTS env_candidates)
            if(DEFINED ENV{${env_var}})
                set(sdk_path $ENV{${env_var}})
                break()
            endif()
        endforeach()

        if(NOT sdk_path)
            message(FATAL_ERROR "Cannot find environment variable for package '${libname}' (tried ${env_candidates})")
        else()
            list(APPEND result "${sdk_path}/cmake/${prefix}_init.cmake")
        endif()
    endforeach()

    # Export result to caller's scope
    set(${ZOS_USE_SEARCH_OUT} "${result}" PARENT_SCOPE)
endfunction()


# Try to find a Zeal 8-bit OS SDK (or package/libraries) via a name.
# This macro takes a string list as a parameter and will try to check any ENV variable as
# UPPER(PARAM)_PATH or UPPER(PARAM)_SDK_PATH. If any exists, it will load the file:
# FOUND_PATH/cmake/UPPER(PARAM).cmake
#
# Since the included cmake files may want to set global variables (package or toolcahin related),
# this must be a macro.
macro(zos_use)
    zos_use_search(${ARGV} OUT sdk_paths)
    foreach(path IN LISTS sdk_paths)
        include(${path})
    endforeach()
endmacro()
