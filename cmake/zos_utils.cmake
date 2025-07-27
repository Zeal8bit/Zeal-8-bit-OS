# Append values to a global property (list)
function(zos_append_property prop_name new_values)
    get_property(old_values GLOBAL PROPERTY ${prop_name})
    if(old_values)
        set(updated_values "${old_values};${new_values}")
    else()
        set(updated_values "${new_values}")
    endif()
    set_property(GLOBAL PROPERTY ${prop_name} "${updated_values}")
endfunction()


function(zos_add_main_dependencies files)
    zos_append_property("CUSTOM_DEPENDENCY" "${files}")
endfunction()


# Adds sources and include directories to the target build.
#
# This function can also be used to define a linkerscript, which must be set.
#
# Arguments:
#   LINKERSCRIPT - Source file that acts as a linker script
#   SOURCES - A list of source files to be added to the kernel build.
#   INCLUDE_DIRS - A list of include directories to be added to the kernel build.
function(zos_target_add)
    cmake_parse_arguments(ARG "" "LINKERSCRIPT" "SRCS;INCLUDE;FLAGS" ${ARGN})

    if(ARG_SRCS)
        set(result "")
        foreach(src ${ARG_SRCS})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${src}")
        endforeach()
        zos_append_property("TARGET_SRCS" "${result}")
    endif()

    if(ARG_INCLUDE)
        set(result "")
        foreach(inc ${ARG_INCLUDE})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${inc}")
        endforeach()
        zos_append_property("TARGET_INCLUDES" "${result}")
    endif()

    if(ARG_FLAGS)
        zos_append_property("TARGET_FLAGS" "${ARG_FLAGS}")
    endif()

    if (ARG_LINKERSCRIPT)
        set_property(GLOBAL PROPERTY LINKERSCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_LINKERSCRIPT}")
        # set(LINKERSCRIPT "${ARG_LINKERSCRIPT}" CACHE INTERNAL "Target LinkerScript" FORCE)
    endif()
endfunction()


# Adds sources and include directories to the kernel build.
#
# Arguments:
#   SOURCES - A list of source files to be added to the kernel build.
#   INCLUDE_DIRS - A list of include directories to be added to the kernel build.
function(zos_kernel_add)
    cmake_parse_arguments(ARG "" "" "SRCS;INCLUDE" ${ARGN})

    if(ARG_SRCS)
        set(result "")
        foreach(src ${ARG_SRCS})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${src}")
        endforeach()
        zos_append_property("KERNEL_SRCS" "${result}")
    endif()

    if(ARG_INCLUDE)
        set(result "")
        foreach(inc ${ARG_INCLUDE})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${inc}")
        endforeach()
        zos_append_property("KERNEL_INCLUDES" "${result}")
    endif()

endfunction()

# Create a ROM image that will contain the OS image and the romdisk (`init.bin` + EXTRA_ROMDISK_FILES)
#
# Arguments: name of the file ROM image to flash
function(zos_create_rom_image)
    cmake_parse_arguments(ARG "" "OUTPUT;DISK_OFFSET" "" ${ARGN})

    if(NOT ARG_OUTPUT OR NOT ARG_DISK_OFFSET)
        message(FATAL_ERROR "Both OUTPUT and DISK_OFFSET arguments must be provided to zos_create_rom_image.")
    endif()

    # Create a custom target for the romdisk
    set(ROMDISKFILE "${CMAKE_BINARY_DIR}/disk.img")
    set(INITBINFILE "${CMAKE_SOURCE_DIR}/romdisk/build/init.bin")

    # Custom command to create the `init.bin` binary
    add_custom_command(
        OUTPUT "${INITBINFILE}"
        COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_SOURCE_DIR}/romdisk make
        COMMENT "Compile init.bin"
    )

    # Pack the romdisk with the init.bin binary and the extra files
    add_custom_command(
        OUTPUT "${ROMDISKFILE}"
        COMMAND ${CMAKE_COMMAND} -E echo "Packing  ${INITBINFILE} $ENV{EXTRA_ROMDISK_FILES}"
        COMMAND ${PYTHON} ${TOOLS_PATH}/pack.py ${ROMDISKFILE} ${INITBINFILE} $ENV{EXTRA_ROMDISK_FILES}
        DEPENDS ${INITBINFILE}
        COMMENT "Pack the romdisk"
    )
    add_custom_target(romdisk
        DEPENDS "${ROMDISKFILE}"
    )
    zos_add_main_dependencies(romdisk)

    # Create a custom target for the final ROM image
    add_custom_command(
        OUTPUT  ${ARG_OUTPUT}
        COMMAND ${PYTHON} ${TOOLS_PATH}/concat.py
                ${ARG_OUTPUT}
                0x0000 $<TARGET_FILE:${COMPILE_OUTPUT}>
                ${ARG_DISK_OFFSET} ${ROMDISKFILE}
        DEPENDS $<TARGET_FILE:${COMPILE_OUTPUT}> ${ROMDISKFILE}
        COMMENT "Create the OS image with disk"
    )
    add_custom_target(os_image ALL DEPENDS ${ARG_OUTPUT})
endfunction()