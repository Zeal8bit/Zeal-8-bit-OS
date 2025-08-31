cmake_minimum_required(VERSION 3.16)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/z88dk_toolchain.cmake)

project(Zeal8bitOS ASM)

# Load extra files
include(cmake/zos_config.cmake)
include(cmake/zos_utils.cmake)

# Global variables
set(OS_TARGET os)
set(CONFIG_FILE "os.conf")
set(CONFIG_ASM "include/osconfig.asm")
set(VERSION_FILE "${CMAKE_BINARY_DIR}/version.txt")

find_program(PYTHON NAMES python3 REQUIRED)

zos_get_python_path(PYTHON_PATH)
zos_get_tools_path(TOOLS_PATH)
zos_load_config(${CMAKE_SOURCE_DIR}/${CONFIG_FILE} ${CMAKE_SOURCE_DIR}/${CONFIG_ASM})
zos_generate_version(${VERSION_FILE})

# Create the final executable, sources will be populated later
add_executable("${OS_TARGET}")

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

# Make sure a linker script was provided
if(linkerscript STREQUAL "")
    message(FATAL_ERROR "A linker script must be defined and given to target_add_srcs")
endif()
target_sources(${OS_TARGET} PUBLIC ${linkerscript} ${kernel_srcs} ${target_srcs})

# Set the include directories
target_include_directories(${OS_TARGET} PUBLIC
                           "${CMAKE_SOURCE_DIR}/include/"
                           ${kernel_includes}
                           ${target_includes})

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

# Copy the real binary into the output name we want
add_custom_command(
    TARGET ${OS_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${OS_TARGET}_RST_VECTORS.bin ${OS_TARGET}.bin
    COMMENT "Renaming ${OS_TARGET}_RST_VECTORS.bin → ${OS_TARGET}.bin"
)
