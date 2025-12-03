cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN z88dk)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(z88dk_example ASM)

set(SRCS init.asm parse.asm opt.asm errors.asm uart.asm date.asm misc.asm
         cd.asm sleep.asm expr.asm)

add_executable(init ${SRCS})

# Optional coreutils
if(CONFIG_INITBIN_ENABLE_COREUTILS)
    target_compile_options(init PRIVATE -DCONFIG_ENABLE_COREUTILS=1)
else()
    target_sources(init PRIVATE cat.asm mkdir.asm rm.asm cp.asm hexdump.asm echo.asm less.asm xfer.asm ls.asm)
endif()

# Provide the path for libstrutils
target_include_directories(init PRIVATE $ENV{ZOS_PATH}/kernel_headers/z88dk-z80asm/include)
target_link_directories(init PRIVATE $ENV{ZOS_PATH}/kernel_headers/z88dk-z80asm/lib)
target_link_libraries(init PRIVATE strutils.lib)

# We need to generate a .map file, to ease debugging
target_link_options(init PRIVATE -m)

# z88dk-z80asm produces the binary named <target>_TEXT.bin
set(OUTPUT_BIN "${CMAKE_CURRENT_BINARY_DIR}/$<TARGET_FILE_BASE_NAME:init>_TEXT.bin")
set(FINAL_BIN  "${CMAKE_CURRENT_BINARY_DIR}/$<TARGET_FILE_BASE_NAME:init>.bin")

add_custom_command(
    TARGET init POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${OUTPUT_BIN}" "${FINAL_BIN}"
    COMMENT "Fixing z88dk output filename"
)
