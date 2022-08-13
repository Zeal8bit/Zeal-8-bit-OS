        IFNDEF LOG_H
        DEFINE LOG_H

        ; Log levels
        DEFC LOG_LEVEL_NONE = 0
        DEFC LOG_LEVEL_ERR  = 1
        DEFC LOG_LEVEL_WARN = 2
        DEFC LOG_LEVEL_INFO = 3

        ; Log properties
        DEFC LOG_ON_STDOUT = 0
        DEFC LOG_IN_BUFFER = 1
        DEFC LOG_DISABLED  = 2

        ; Macros for logging with a prefix
        MACRO ZOS_LOG_ERROR
            IF CONFIG_KERNEL_LOG_LEVEL >= LOG_LEVEL_ERR
                call zos_log_error
            ENDIF
        ENDM

        MACRO ZOS_LOG_WARNING
            IF CONFIG_KERNEL_LOG_LEVEL >= LOG_LEVEL_WARN
                call zos_log_warning
            ENDIF
        ENDM

        MACRO ZOS_LOG_INFO
            IF CONFIG_KERNEL_LOG_LEVEL >= LOG_LEVEL_INFO
                call zos_log_info
            ENDIF
        ENDM

        ; Routines declaration
        EXTERN zos_log_init
        EXTERN zos_log_message
        EXTERN zos_log_error
        EXTERN zos_log_warning
        EXTERN zos_log_info

        ENDIF ; LOG_H