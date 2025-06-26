cmake_minimum_required(VERSION 3.20)
project(Zeal8bitOS NONE)

# Load extra files
include(cmake/zos_config.cmake)
include(cmake/zos_utils.cmake)

# Global variables
set(COMPILE_OUTPUT os.bin)
set(CONFIG_FILE "os.conf")
set(CONFIG_ASM "include/osconfig.asm")
set(VERSION_FILE "${CMAKE_BINARY_DIR}/version.txt")
set(OUTPUT_OS_BIN "${CMAKE_BINARY_DIR}/${COMPILE_OUTPUT}")

find_program(Z80ASM NAMES z88dk-z80asm z88dk.z88dk-z80asm REQUIRED)
find_program(PYTHON NAMES python3 REQUIRED)

zos_get_python_path(PYTHON_PATH)
zos_get_tools_path(TOOLS_PATH)
zos_load_config(${CMAKE_SOURCE_DIR}/${CONFIG_FILE} ${CMAKE_SOURCE_DIR}/${CONFIG_ASM})
zos_generate_version(${VERSION_FILE})

# Browse the kernel
add_subdirectory(kernel)
# Target sources
add_subdirectory("target/${CONFIG_TARGET}")

# Retrieve all the properties and make them variables, let's keep the local variables in lower case.
get_property(linkerscript GLOBAL PROPERTY LINKERSCRIPT)
get_property(kernel_srcs GLOBAL PROPERTY KERNEL_SRCS)
get_property(kernel_includes GLOBAL PROPERTY KERNEL_INCLUDES)
get_property(target_srcs GLOBAL PROPERTY TARGET_SRCS)
get_property(target_flags GLOBAL PROPERTY TARGET_FLAGS)
get_property(target_link_flags GLOBAL PROPERTY TARGET_LINK_FLAGS)
get_property(target_includes GLOBAL PROPERTY TARGET_INCLUDES)
get_property(custom_dependency GLOBAL PROPERTY CUSTOM_DEPENDENCY)


# Make sure a linker script was provided
if(linkerscript STREQUAL "")
    message(FATAL_ERROR "A linker script must be defined and given to target_add_srcs")
endif()
# Append all the sources together
set(srcs ${linkerscript})
list(APPEND srcs ${kernel_srcs} ${target_srcs})

# Do the same for the included directories and prepend "-I" option
set(include_dirs "${CMAKE_SOURCE_DIR}/include/")
list(APPEND include_dirs ${kernel_includes} ${target_includes})
list(TRANSFORM include_dirs PREPEND "-I")


####### RULES #######

# Create object files, the simplest solution for the configuration file is to make them all depend on it
set(obj_files "")
foreach(src IN LISTS srcs)
    set(obj "")
    # Replace the extension with .o
    cmake_path(REPLACE_EXTENSION src ".o" OUTPUT_VARIABLE obj)
    # Keep the structure of the source files, get the path relatively to the base dir
    cmake_path(RELATIVE_PATH obj
               BASE_DIRECTORY ${CMAKE_SOURCE_DIR})
    set(obj ${CMAKE_BINARY_DIR}/${obj})
    add_custom_command(
        OUTPUT ${obj}
        COMMAND ${Z80ASM} ${include_dirs} ${target_flags} -o${obj} ${src}
        DEPENDS ${src} ${CMAKE_SOURCE_DIR}/${CONFIG_ASM}
        COMMENT "Assembling ${src}"
    )
    list(APPEND obj_files ${obj})
endforeach()

# Optional menuconfig integration
add_custom_target(menuconfig
    COMMAND env MENUCONFIG_STYLE=aquatic KCONFIG_CONFIG=${CONFIG_FILE} ${PYTHON_PATH}/menuconfig
    COMMAND echo "Converting ${CONFIG_FILE} to ${CONFIG_ASM}..."
    COMMAND ${PYTHON} ${CMAKE_SOURCE_DIR}/tools/config_to_asm.py ${CMAKE_SOURCE_DIR}/${CONFIG_FILE} ${CMAKE_SOURCE_DIR}/${CONFIG_ASM}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Launch menuconfig"
)

add_custom_target(alldefconfig
    COMMAND ${PYTHON_PATH}/alldefconfig
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Set default config"
)

# Link all the object files into a single binary
add_custom_command(
    OUTPUT ${OUTPUT_OS_BIN}
    COMMAND ${Z80ASM} -b ${target_flags} -o${OUTPUT_OS_BIN} -m -s ${obj_files}
    # Fixme: z88dk generates an empty binary file
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/os_RST_VECTORS.bin ${OUTPUT_OS_BIN}
    DEPENDS ${obj_files}
    COMMENT "Linking OS binary"
)

message(STATUS "Dependencies: ${OUTPUT_OS_BIN} ${custom_dependency}")
add_custom_target(zeal8bitos ALL DEPENDS ${OUTPUT_OS_BIN} "${custom_dependency}")
