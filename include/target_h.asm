        IFNDEF TARGET_H
        DEFINE TARGET_H

        ; Function called as soon as the MMU and the stack are set up 
        EXTERN target_coldboot

        ; Function called after program exit
        EXTERN target_exit

        ENDIF