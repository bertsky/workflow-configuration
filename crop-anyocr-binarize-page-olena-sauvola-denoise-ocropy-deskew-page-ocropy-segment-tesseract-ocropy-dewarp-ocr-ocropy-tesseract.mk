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
	@echo "or if not available, then read image files and binarize+crop,"
	@echo "then binarize+denoise+deskew pages,"
	@echo "then segment into regions with Tesseract, deskew and post-process,"
	@echo "then segment into lines with Ocropy and dewarp,"
	@echo "and finally recognize lines with various Ocropus+Tesseract models."

INPUT = OCR-D-IMG

$(INPUT):
	ocrd workspace find -G $@ --download

BIN = $(INPUT)-BINPAGE-sauvola

$(BIN): $(INPUT)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "sauvola-ms-split"

CROP = OCR-D-SEG-PAGE-anyocr

$(CROP): $(BIN)
$(CROP): TOOL = ocrd-anybaseocr-crop

# search GT for page segmentation, otherwise use cropped image:
INPUT2 = $(firstword $(foreach GRP,OCR-D-GT-SEG-PAGE OCR-D-GT-SEG-BLOCK OCR-D-GT-SEG-LINE,$(wildcard $(GRP))) $(CROP))

BIN2 = $(INPUT2)-BINPAGE-sauvola

$(BIN2): $(INPUT2)
$(BIN2): TOOL = ocrd-olena-binarize
$(BIN2): PARAMS = "impl": "sauvola-ms-split"

DEN = $(BIN2)-DENOISE-ocropy

$(DEN): $(BIN2)
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

BLOCK = OCR-D-SEG-BLOCK-tesseract

$(BLOCK): $(DESK)
$(BLOCK): TOOL = ocrd-tesserocr-segment-region
$(BLOCK): PARAMS = "padding": 5, "find_tables": false

PLAUSIBLE = $(BLOCK)-plausible

$(PLAUSIBLE): $(BLOCK)
$(PLAUSIBLE): TOOL = ocrd-segment-repair
$(PLAUSIBLE): PARAMS = "plausibilize": true, "plausibilize_merge_min_overlap": 0.7

CLIP = $(BLOCK)-CLIP

$(CLIP): $(PLAUSIBLE)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

FLIPR = $(CLIP)-DESKEW-tesseract

$(FLIPR): $(CLIP)
$(FLIPR): TOOL = ocrd-tesserocr-deskew
$(FLIPR): PARAMS = "operation_level": "region"

LINE = OCR-D-SEG-LINE-tesseract-ocropy

$(LINE): $(FLIPR)
$(LINE): TOOL = ocrd-cis-ocropy-segment
$(LINE): PARAMS = "spread": 2.4

DEW = $(LINE)-DEWARP

$(DEW): $(LINE)
$(DEW): TOOL = ocrd-cis-ocropy-dewarp

OCR1 = OCR-D-OCR-OCRO-fraktur-$(DEW:OCR-D-%=%)
OCR2 = OCR-D-OCR-OCRO-frakturjze-$(DEW:OCR-D-%=%)
OCR3 = OCR-D-OCR-TESS-Fraktur-$(DEW:OCR-D-%=%)
OCR4 = OCR-D-OCR-TESS-Fraktur-Latin-$(DEW:OCR-D-%=%)
OCR5 = OCR-D-OCR-TESS-frk-$(DEW:OCR-D-%=%)
OCR6 = OCR-D-OCR-TESS-frk-deu-$(DEW:OCR-D-%=%)
OCR7 = OCR-D-OCR-TESS-gt4histocr-$(DEW:OCR-D-%=%)
OCR8 = OCR-D-OCR-CALA-gt4histocr-$(DEW:OCR-D-%=%)

$(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7) $(OCR8): $(DEW)

$(OCR1) $(OCR2): TOOL = ocrd-cis-ocropy-recognize
$(OCR1): PARAMS = "textequiv_level": "glyph", "model": "fraktur.pyrnn.gz"
$(OCR2): PARAMS = "textequiv_level": "glyph", "model": "fraktur-jze.pyrnn.gz"

$(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7): TOOL = ocrd-tesserocr-recognize
$(OCR3): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "script/Fraktur"
$(OCR4): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "script/Fraktur+script/Latin"
$(OCR5): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk"
$(OCR6): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk+deu"
$(OCR7): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "GT4HistOCR_2000000+GT4HistOCR_300000+GT4HistOCR_100000"

$(OCR8): TOOL = ocrd-calamari-recognize
$(OCR8): GPU = 1
$(OCR8): PARAMS = "checkpoint" : "$(VIRTUAL_ENV)/share/calamari/GT4HistOCR/*.ckpt.json"

OUTPUT: $(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7) $(OCR8) ;

.PHONY: OUTPUT
.DEFAULT_GOAL = OUTPUT

# Down here, custom configuration ends.
###

include Makefile

