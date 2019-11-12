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
	@echo "Read GT segmentation (on any level, merely for page frame),"
	@echo "or if not available, then read image files and crop,"
	@echo "then binarize+denoise+deskew pages,"
	@echo "then segment into regions and lines,"
	@echo "then shrink regions into the hull polygon of its lines,"
	@echo "and finally extract page images and region coordinates"
	@echo "(including meta-data) into one directory,"
	@echo "with corresponding filename suffixes for segmentation training."

INPUT = OCR-D-IMG

CROP = OCR-D-SEG-PAGE-anyocr

$(CROP): $(INPUT)
$(CROP): TOOL = ocrd-anyocrbase-crop

# search GT for page segmentation, otherwise use cropped image:
INPUT2 = $(firstword $(foreach GRP,OCR-D-GT-SEG-PAGE OCR-D-GT-SEG-BLOCK OCR-D-GT-SEG-LINE,$(wildcard $(GRP))) $(CROP))

BIN = $(INPUT2)-BINPAGE-sauvola

$(BIN): $(INPUT2)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "sauvola-ms-split"

DEN = $(BIN)-DENOISE-ocropy

$(DEN): $(BIN)
$(DEN): TOOL = ocrd-cis-ocropy-denoise
$(DEN): PARAMS = "level-of-operation": "page", "noise_maxsize": 3.0

DESK = $(DEN)-DESKEW-ocropy

$(DESK): $(DEN)
$(DESK): TOOL = ocrd-cis-ocropy-deskew
$(DESK): PARAMS = "level-of-operation": "page", "maxskew": 5

BLOCK = OCR-D-SEG-BLOCK-tesseract

$(BLOCK): $(DESK)
$(BLOCK): TOOL = ocrd-tesserocr-segment-region
$(BLOCK): PARAMS = "operation_level": "region"

CLIP = $(BLOCK)-CLIP

$(CLIP): $(BLOCK)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

DESK2 = $(CLIP)-DESKEW-tesseract

$(DESK2): $(CLIP)
$(DESK2): TOOL = ocrd-tesserocr-deskew
$(DESK2): PARAMS = "operation_level": "region"

RESEG = OCR-D-SEG-LINE-tesseract-ocropy

$(RESEG): $(CLIP)
$(RESEG): TOOL = ocrd-cis-ocropy-segment
$(RESEG): PARAMS = "spread": 2.4

TIGHT = OCR-D-SEG-BLOCK-tesseract-ocropy

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

