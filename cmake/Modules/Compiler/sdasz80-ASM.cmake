message(STATUS "ZOS SDASZ80 assembler detected.")

set(CMAKE_ASM_SOURCE_FILE_EXTENSIONS asm)
set(CMAKE_ASM_OUTPUT_EXTENSION ".rel")

set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>"
)

# Assembly-only libraries also need an SDCC archive symbol index. The host
# ar/ranlib tools do not understand .rel objects. Find sdar independently of
# the C language setup so projects enabling only ASM use the correct tool too.
get_filename_component(SDASZ80_COMPILER_DIR "${CMAKE_ASM_COMPILER}" DIRECTORY)
find_program(SDASZ80_AR_EXECUTABLE NAMES sdar HINTS "${SDASZ80_COMPILER_DIR}")
if(NOT SDASZ80_AR_EXECUTABLE)
    message(FATAL_ERROR "sdar is required to create SDCC assembly libraries")
endif()

set(CMAKE_ASM_CREATE_STATIC_LIBRARY
    "\"${CMAKE_COMMAND}\" -E remove <TARGET>"
    "\"${SDASZ80_AR_EXECUTABLE}\" -rcs <TARGET> <LINK_FLAGS> <OBJECTS>"
)

# The way the final binary (C or ASM) is linked highly depends on the assembler.
set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")

set(CMAKE_ASM_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")

set(CMAKE_EXECUTABLE_SUFFIX ".ihx")

set(CMAKE_LINK_LIBRARY_FLAG "-l ")
set(CMAKE_LIBRARY_PATH_FLAG "-k ")
