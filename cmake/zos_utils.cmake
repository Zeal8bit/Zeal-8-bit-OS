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


# Adds sources and include directories to the target build.
#
# This function can also be used to define a linkerscript, which must be set.
function(zos_target_add)
    cmake_parse_arguments(ARG "" "" "SRCS;INCLUDE;FLAGS;LINKFLAGS;LINKERSCRIPT" ${ARGN})

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

    if (ARG_LINKFLAGS)
        zos_append_property("TARGET_LINKFLAGS" "${ARG_LINKFLAGS}")
    endif()

    if(ARG_LINKERSCRIPT)
        set(result "")
        foreach(ld ${ARG_LINKERSCRIPT})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${ld}")
        endforeach()
        zos_append_property("TARGET_LINKERSCRIPTS" "${result}")
    endif()
endfunction()


# Adds sources and include directories to the kernel build.
function(zos_kernel_add)
    cmake_parse_arguments(ARG "" "" "SRCS;INCLUDE;LINKFLAGS;LINKERSCRIPT" ${ARGN})

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

    if (ARG_LINKFLAGS)
        zos_append_property("KERNEL_LINKFLAGS" "${ARG_LINKFLAGS}")
    endif()

    if(ARG_LINKERSCRIPT)
        set(result "")
        foreach(ld ${ARG_LINKERSCRIPT})
            list(APPEND result "${CMAKE_CURRENT_SOURCE_DIR}/${ld}")
        endforeach()
        zos_append_property("KERNEL_LINKERSCRIPTS" "${result}")
    endif()

endfunction()
