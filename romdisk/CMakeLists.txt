if (NOT CONFIG_ENABLE_ROMDISK)
    return()
endif()

if(NOT DEFINED CONFIG_ROMDISK_OFFSET_PAGES)
    message(FATAL_ERROR "Configuration option ROMDISK_OFFSET_PAGES was not found, please remove os.conf file and retry")
endif()

# Create a ROM image that will contain the OS image and the romdisk
#
# Arguments: name of the file ROM image to flash
function(zos_create_rom_image)
    cmake_parse_arguments(ARG "IGNORE_HIDDEN" "OUTPUT;DISK_OFFSET" "FILES" ${ARGN})

    if(NOT ARG_OUTPUT OR NOT ARG_DISK_OFFSET)
        message(FATAL_ERROR "Parameters OUTPUT and DISK_OFFSET and must be provided to zos_create_rom_image.")
    endif()

    # Create a custom target for the romdisk
    set(ROMDISKFILE "${CMAKE_BINARY_DIR}/disk.img")

    if (ARG_IGNORE_HIDDEN)
        set(SKIP_HIDDEN "--skip-hidden")
    endif()

    # Pack the romdisk with the init.bin binary and the extra files
    add_custom_command(
        OUTPUT "${ROMDISKFILE}"
        COMMAND ${CMAKE_COMMAND} -E echo "Packing ${ARG_FILES}"
        COMMAND ${PYTHON} ${TOOLS_PATH}/pack.py ${SKIP_HIDDEN} ${ROMDISKFILE} ${ARG_FILES}
        DEPENDS ${ARG_FILES}
        COMMENT "Pack the romdisk"
    )
    add_custom_target(romdisk DEPENDS "${ROMDISKFILE}")

    # Create a custom target for the final ROM image
    add_custom_command(
        OUTPUT  ${ARG_OUTPUT}
        COMMAND ${PYTHON} ${TOOLS_PATH}/concat.py
                ${ARG_OUTPUT}
                0x0000 $<TARGET_FILE:${OS_TARGET}>
                ${ARG_DISK_OFFSET} ${ROMDISKFILE}
        DEPENDS $<TARGET_FILE:${OS_TARGET}> ${ROMDISKFILE}
        COMMENT "Create the OS image with disk"
    )
    add_custom_target(os_image ALL DEPENDS ${ARG_OUTPUT})
endfunction()

# Generate init.bin if selected from the configuration
if(CONFIG_ROMDISK_INCLUDE_INIT_BIN)
    set(cmake_args "")

    if (CONFIG_INITBIN_ENABLE_COREUTILS)
        set(cmake_args "-DCONFIG_INITBIN_ENABLE_COREUTILS=1")
    endif()

    include(ExternalProject)

    ExternalProject_Add(init_bin
        SOURCE_DIR    ${CMAKE_SOURCE_DIR}/romdisk/init
        BINARY_DIR    ${CMAKE_BINARY_DIR}/romdisk/init/build
        CMAKE_ARGS    ${cmake_args}
        BUILD_BYPRODUCTS ${CMAKE_BINARY_DIR}/romdisk/init/build/init.bin
        INSTALL_COMMAND ""
    )
    set(INITBINFILE "${CMAKE_BINARY_DIR}/romdisk/init/build/init.bin")

endif()

# Calculate the offset of the ROMDISK given the 16KB-block distance configuration
math(EXPR ROMDISK_OFFSET "${CONFIG_ROMDISK_OFFSET_PAGES} * 0x4000")

if(CONFIG_ROMDISK_OFFSET_PAGES LESS 0)
    # Only values that put the romdisk AFTER the kernel for now
    message(WARNING "Generating an image where the romdisk is before the kernel is currently not supported.\n"
                    "Only the OS binary will be generated.")
else()
    if(CONFIG_ROMDISK_OFFSET_PAGES EQUAL 0)
        message(WARNING "ROMDISK page offset cannot be 0! Automatically setting it to 1.")
        set(ROMDISK_OFFSET "16384")
    endif()

    set(files_to_include_str "")
    if (ENV{EXTRA_ROMDISK_FILES})
        string(APPEND files_to_include_str
                      "\n      From environment variable: $ENV{EXTRA_ROMDISK_FILES}")
    endif()
    if (CONFIG_EXTRA_ROMDISK_FILES)
        string(APPEND files_to_include_str
                      "\n      From configuration: ${CONFIG_EXTRA_ROMDISK_FILES}")
    endif()

    message(STATUS "From configuration: ${CONFIG_EXTRA_ROMDISK_FILES}")

    if (NOT files_to_include_str STREQUAL "")
        message(STATUS "Files to include in the romdisk:${files_to_include_str}")
    endif()

    # Pass the parameter IGNORE_HIDDEN if the CONFIG_ROMDISK_IGNORE_HIDDEN is set
    if (CONFIG_ROMDISK_IGNORE_HIDDEN)
        set(IGNORE_HIDDEN "IGNORE_HIDDEN")
    endif()

    # Create a ROM image that will contain the OS binary with the romdisk
    zos_create_rom_image(OUTPUT      "${CMAKE_BINARY_DIR}/os_with_romdisk.img"
                         FILES       ${INITBINFILE} $ENV{EXTRA_ROMDISK_FILES} ${CONFIG_EXTRA_ROMDISK_FILES}
                         DISK_OFFSET "${ROMDISK_OFFSET}"
                         ${IGNORE_HIDDEN}
    )
endif()
