# This file can run a workflow on a single workspace (non-recursively).
#
# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside and running
# `make` there (or including files from there).
#
# Call via:
# `make -f WORKFLOW-CONFIG.mk`
#
# To rebuild partially, you must pass -W to `make`:
# `make -f WORKFLOW-CONFIG.mk -W FILEGRP`
#
# To build in parallel, use `-j [CPUS] [-l [LOADLEVEL]]` etc.
#
# To get general help:
# `make -f WORKFLOW-CONFIG.mk help`
#
# To get a description of the workflow:
# `make -f WORKFLOW-CONFIG.mk info`

###
# From here on, custom configuration begins.

INPUT = OCR-D-IMG

$(INPUT):
	ocrd workspace find -G $@ --download

OUTPUT = OCR-D-OCR-TESS
$(OUTPUT): $(INPUT)
$(OUTPUT): TOOL = ocrd-tesserocr-recognize
$(OUTPUT): PARAMS = "segmentation_level": "region", "model": "$(or $(MODEL),Fraktur+Latin)", "shrink_polygons": true #, "auto_model": true

info:
	@echo "This is a simple workflow with Tesseract segmentation+recognition"
	@echo "from $(INPUT) to $(OUTPUT) with recognition model MODEL=$(MODEL)"

.PHONY: info

.DEFAULT_GOAL = $(OUTPUT)

# Down here, custom configuration ends.
###

include Makefile
