# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside. Then
# chdir to that location.

# Call via:
# `make -f WORKFLOW-CONFIG.mk WORKSPACE-DIRS` or
# `make -f WORKFLOW-CONFIG.mk all` or just
# `make -f WORKFLOW-CONFIG.mk`
# To rebuild partially, you must pass -W to recursive make:
# `make -f WORKFLOW-CONFIG.mk EXTRA_MAKEFLAGS="-W FILEGRP"`
# To get help on available goals:
# `make help`

###
# From here on, custom configuration begins.

info:
	@echo "Read GT line segmentation,"
	@echo "then binarize+denoise+deskew pages,"
	@echo "then clip regions,"
	@echo "then shrink regions into the hull polygon of its lines,"
	@echo "and finally extract page images and region coordinates"
	@echo "(including meta-data) into one directory,"
	@echo "with corresponding filename suffixes for segmentation training."

INPUT = OCR-D-GT-SEG-LINE

$(INPUT):
	ocrd workspace find -G $@ --download
	ocrd workspace find -G OCR-D-IMG --download # just in case

BIN = $(INPUT)-BINPAGE-sauvola

$(BIN): $(INPUT)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "sauvola-ms-split"

DEN = $(BIN)-DENOISE-ocropy

$(DEN): $(BIN)
$(DEN): TOOL = ocrd-cis-ocropy-denoise
$(DEN): PARAMS = "level-of-operation": "page", "noise_maxsize": 3.0

FLIP = $(DEN)-DESKEW-tesseract

$(FLIP): $(DEN)
$(FLIP): TOOL = ocrd-tesserocr-deskew
$(FLIP): PARAMS = "operation_level": "page"

DESK = $(FLIP)-DESKEW-ocropy

$(DESK): $(FLIP)
$(DESK): TOOL = ocrd-cis-ocropy-deskew
$(DESK): PARAMS = "level-of-operation": "page", "maxskew": 5

CLIP = $(DESK)-CLIP

$(CLIP): $(DESK)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

RESEG = OCR-D-SEG-LINE

$(RESEG): $(CLIP)
$(RESEG): TOOL = ocrd-cis-ocropy-segment
$(RESEG): PARAMS = "spread": 2.4

TIGHT = OCR-D-SEG-BLOCK

$(TIGHT): $(RESEG)
$(TIGHT): TOOL = ocrd-segment-repair
$(TIGHT): PARAMS = "sanitize": true

OUTPUT = OCR-D-IMG-REGIONS

$(OUTPUT): $(TIGHT)
$(OUTPUT): TOOL = ocrd-segment-extract-regions
$(OUTPUT): PARAMS = "transparency": true

.DEFAULT_GOAL = $(OUTPUT)

# Down here, custom configuration ends.
###

include Makefile

