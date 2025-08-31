set(CMAKE_MODULE_PATH "$ENV{ZOS_PATH}/cmake/Modules" ${CMAKE_MODULE_PATH})

set(CMAKE_SYSTEM_NAME ZOS)
set(CMAKE_SYSTEM_PROCESSOR Z80)

# Disable C++
set(CMAKE_CXX_COMPILER "" CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "")

# Force C language, even if the project only needs ASM
set(CMAKE_C_COMPILER sdcc)
set(CMAKE_C_DEPFILE_STYLE NONE)

set(CMAKE_ASM_COMPILER sdasz80)
set(CMAKE_ASM_COMPILER_ID sdasz80)

set(CMAKE_LINKER sdldz80)
set(CMAKE_OBJCOPY sdobjcopy)

# If CMake fails to auto-detect anything, uncomment these lines:
# set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "")
# set(CMAKE_C_COMPILER_FORCED TRUE CACHE INTERNAL "")
#set(CMAKE_ASM_COMPILER_WORKS TRUE CACHE INTERNAL "")


# Compilation and linking commands
# By default, provide kernel headers for SDCC and put the code in `TEXT` section
set(CMAKE_C_FLAGS_INIT "-mz80 -I$ENV{ZOS_PATH}/kernel_headers/sdcc/include/ --codeseg TEXT")

# Default linking options
set(SDCC_REL0 "$ENV{ZOS_PATH}/kernel_headers/sdcc/bin/zos_crt0.rel")
set(ZOS_LINK_FLAGS  "-n" # No echo of commands to STDOUT
                    "-b _HEADER=0x4000"
                    "-i" # Intel Hex output
                    "-y" # SDCDB Debug output
                    "-k $ENV{ZOS_PATH}/kernel_headers/sdcc/lib" # Library path
                    "-l z80" # Link the Z80 library
    )
# Concatenate the variable above since CMake wants a single string as init flags
string(REPLACE ";" " " CMAKE_EXE_LINKER_FLAGS_INIT "${ZOS_LINK_FLAGS}")

set(CMAKE_ASM_FLAGS_INIT "-I$ENV{ZOS_PATH}/kernel_headers/sdcc/include/")

# Default linker variables, can be overriden by the assembler
set(CMAKE_ASM_SOURCE_FILE_EXTENSIONS asm)
set(CMAKE_ASM_OUTPUT_EXTENSION ".rel")
set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>"
)
set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")
set(CMAKE_ASM_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <LINK_LIBRARIES> <TARGET> ${SDCC_REL0} <OBJECTS>")

