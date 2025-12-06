cmake_minimum_required(VERSION 3.16)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/z88dk_toolchain.cmake)

project(Zeal8bitOS ASM)

# Load extra files
include(cmake/zos_config.cmake)
include(cmake/zos_utils.cmake)

# Global variables
set(OS_TARGET os)
if(NOT DEFINED config)
    set(CONFIG_FILE "${CMAKE_SOURCE_DIR}/os.conf")
else()
    set(CONFIG_FILE "${CMAKE_SOURCE_DIR}/${config}")
    unset(config CACHE)  # Clear it so it's not reused
endif()
message(STATUS "Using config file: ${CONFIG_FILE}")
set(CONFIG_ASM "include/osconfig.asm")
set(VERSION_FILE "${CMAKE_BINARY_DIR}/version.txt")

find_program(PYTHON NAMES python3 REQUIRED)

zos_get_python_path(PYTHON_PATH)
zos_get_tools_path(TOOLS_PATH)
zos_load_config(${CONFIG_FILE})
zos_generate_version(${VERSION_FILE})

# Create the final executable, sources will be populated later
add_executable("${OS_TARGET}")

# Browse the kernel
add_subdirectory(kernel)
# Target sources
add_subdirectory("target/${CONFIG_TARGET}")
# Romdisk project
add_subdirectory(romdisk)


# Retrieve all the properties and make them variables, let's keep the local variables in lower case.
get_property(linkerscript GLOBAL PROPERTY LINKERSCRIPT)
get_property(kernel_srcs GLOBAL PROPERTY KERNEL_SRCS)
get_property(kernel_includes GLOBAL PROPERTY KERNEL_INCLUDES)
get_property(kernel_link_flags GLOBAL PROPERTY KERNEL_LINKFLAGS)
get_property(target_srcs GLOBAL PROPERTY TARGET_SRCS)
get_property(target_flags GLOBAL PROPERTY TARGET_FLAGS)
get_property(target_link_flags GLOBAL PROPERTY TARGET_LINKFLAGS)
get_property(target_includes GLOBAL PROPERTY TARGET_INCLUDES)

# Make sure a linker script was provided
if(linkerscript STREQUAL "")
    message(FATAL_ERROR "A linker script must be defined and given to target_add_srcs")
endif()
target_sources(${OS_TARGET} PUBLIC ${linkerscript} ${kernel_srcs} ${target_srcs})
set_source_files_properties(${linkerscript} ${kernel_srcs} ${target_srcs}
                            OBJECT_DEPENDS ${CMAKE_SOURCE_DIR}/${CONFIG_ASM})

# Set the include directories
target_include_directories(${OS_TARGET} PUBLIC
                           "${CMAKE_SOURCE_DIR}/include/"
                           ${kernel_includes}
                           ${target_includes})

target_compile_options(${OS_TARGET} PUBLIC ${target_flags})
target_link_options(${OS_TARGET} PUBLIC ${kernel_link_flags} ${target_link_flags})

# Optional menuconfig integration
add_custom_target(menuconfig
    COMMAND env MENUCONFIG_STYLE=aquatic KCONFIG_CONFIG="os.conf" ${PYTHON_PATH}/menuconfig
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Launch menuconfig"
)
# Add a target for alldefconfig so that `make alldefconfig` is valid and executes the proper command
add_custom_target(alldefconfig
    COMMAND env KCONFIG_CONFIG="os.conf" ${PYTHON_PATH}/alldefconfig
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Generating default configuration"
)
# Also make `alldefconfig` a command so that the asm config is linked to it. If `make` is launched without
# having the config asm file, this command will be used
add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/${CONFIG_ASM}
    COMMAND ${PYTHON} ${CMAKE_SOURCE_DIR}/tools/config_to_asm.py ${CONFIG_FILE} ${CMAKE_SOURCE_DIR}/${CONFIG_ASM}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    DEPENDS ${CONFIG_FILE}
    COMMENT "Generate osconfig.asm"
)

# Copy the real binary into the output name we want
add_custom_command(
    TARGET ${OS_TARGET} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy ${OS_TARGET}_RST_VECTORS.bin ${OS_TARGET}.bin
    COMMENT "Renaming ${OS_TARGET}_RST_VECTORS.bin → ${OS_TARGET}.bin"
)
