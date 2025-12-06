
function(zos_get_python_path PYTHON_PATH)
    set(python_path "")
    execute_process(
        COMMAND ${PYTHON} -m site --user-base
        OUTPUT_VARIABLE python_path
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(PYTHON_PATH "${python_path}/bin" PARENT_SCOPE)
endfunction()

function(zos_get_tools_path TOOLS_PATH)
    set(TOOLS_PATH "${CMAKE_SOURCE_DIR}/tools" PARENT_SCOPE)
endfunction()


function(zos_load_config CONFIG_FILE CONFIG_ASM)
    # If the configuration file doesn't exist, we need to force the user to create it
    if(NOT EXISTS "${CONFIG_FILE}")
        message(STATUS "Configuration file not found, generating a default configuration")
        execute_process(
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            COMMAND env KCONFIG_CONFIG=${CONFIG_FILE} ${PYTHON_PATH}/alldefconfig
            ERROR_VARIABLE err1
        )
        if(NOT "${err1}" STREQUAL "")
            message(FATAL_ERROR "Error occurred: ${err1}")
        endif()
    endif()

    # Make the CMake build config depend on this file. We don't actually need to use the copy.
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CONFIG_FILE})
    file(READ "${CONFIG_FILE}" CONFIG_RAW)

    # Match all lines like CONFIG_FOO=bar
    string(REGEX MATCHALL "CONFIG_[A-Za-z0-9_]*=[^\n\r]+" CONFIG_MATCHES "${CONFIG_RAW}")

    foreach(match IN LISTS CONFIG_MATCHES)

        # Extract key and value
        string(REGEX REPLACE "^([^=]+)=(.*)" "\\1" name "${match}")
        # Get rid of the quotes if any
        string(REGEX REPLACE "^([^=]+)=\"?([^\"]*)\"?" "\\2" value "${match}")

        # Define the variable
        set(${name} "${value}" PARENT_SCOPE)
    endforeach()
endfunction()


function(zos_generate_version file)
    set(CONTENT "Zeal 8-bit OS")

    execute_process(
        COMMAND git describe --tags
        OUTPUT_VARIABLE GIT_DESC
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE GIT_RESULT
    )

    if(NOT GIT_RESULT EQUAL 0)
        message(WARNING "Cannot get version, not in a git repository")
        set(GIT_DESC "unversioned")
    endif()


    set(CONTENT "${CONTENT} ${GIT_DESC}\n")

    if(NOT(CONFIG_KERNEL_REPRODUCIBLE_BUILD))
        string(TIMESTAMP BUILD_DATE "%Y-%m-%d %H:%M")
        set(CONTENT "${CONTENT}Build time: ${BUILD_DATE}\n")
    endif()

    file(WRITE ${file} "${CONTENT}")
endfunction()