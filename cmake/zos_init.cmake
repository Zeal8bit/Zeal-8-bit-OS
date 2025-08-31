

if(NOT DEFINED ZOS_TOOLCHAIN)
    set(ZOS_TOOLCHAIN sdcc)
	message(WARNING "ZOS_TOOLCHAIN is not defined, defaulting to SDCC.")
endif()

set(CMAKE_TOOLCHAIN_FILE $ENV{ZOS_PATH}/cmake/${ZOS_TOOLCHAIN}_toolchain.cmake)

# Helper to convert an ELF file to a raw binary
function(elf_to_bin target)
    set(bin_file "${CMAKE_CURRENT_BINARY_DIR}/${target}.bin")
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
    set(bin_file "${CMAKE_CURRENT_BINARY_DIR}/${target}.bin")

    add_custom_target(${target}_bin ALL
        COMMAND ${CMAKE_OBJCOPY} --input-target=ihex --output-target=binary $<TARGET_FILE:${target}> ${bin_file}
        DEPENDS $<TARGET_FILE:${target}>
        COMMENT "Converting IHX to raw binary"
        VERBATIM
    )
    set_property(TARGET ${target}_bin PROPERTY RAW_BINARY ${bin_file})
endfunction()


function(create_asset target asset_file)
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
