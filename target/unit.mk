
# Import the Target's makefile
# Save the resulted variables in SUBSRCS and SUBINCLUDES
$(eval $(call IMPORT_unitmk,$(PWD)/$(TARGET)/$(MKFILE),SUBSRCS,SUBINCLUDES))

SRCS := $(SUBSRCS)
INCLUDES := $(SUBINCLUDES)
