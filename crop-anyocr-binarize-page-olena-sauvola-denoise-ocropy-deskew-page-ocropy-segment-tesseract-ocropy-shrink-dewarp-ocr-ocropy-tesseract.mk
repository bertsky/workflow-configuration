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
	@echo "and finally recognize lines with various Ocropus+Tesseract models."

INPUT = OCR-D-IMG

$(INPUT):
	ocrd workspace find -G $@ --download

CROP = OCR-D-SEG-PAGE-anyocr

$(CROP): $(INPUT)
$(CROP): TOOL = ocrd-anybaseocr-crop

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

CLIP = $(BLOCK)-CLIP

$(CLIP): $(BLOCK)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

LINE = OCR-D-SEG-LINE-tesseract-ocropy

$(LINE): $(CLIP)
$(LINE): TOOL = ocrd-cis-ocropy-segment
$(LINE): PARAMS = "spread": 2.4

TIGHT = OCR-D-SEG-BLOCK-tesseract-ocropy

$(TIGHT): $(LINE)
$(TIGHT): TOOL = ocrd-segment-repair
$(TIGHT): PARAMS = "sanitize": true

DEW = $(TIGHT)-DEWARP

$(DEW): $(TIGHT)
$(DEW): TOOL = ocrd-cis-ocropy-dewarp

OCR1 = OCR-D-OCR-OCRO-fraktur-$(DEW:OCR-D-%=%)
OCR2 = OCR-D-OCR-OCRO-frakturjze-$(DEW:OCR-D-%=%)
OCR3 = OCR-D-OCR-TESS-Fraktur-$(DEW:OCR-D-%=%)
OCR4 = OCR-D-OCR-TESS-Fraktur+Latin-$(DEW:OCR-D-%=%)
OCR5 = OCR-D-OCR-TESS-frk-$(DEW:OCR-D-%=%)
OCR6 = OCR-D-OCR-TESS-frk+deu-$(DEW:OCR-D-%=%)
OCR7 = OCR-D-OCR-TESS-gt4histocr-$(DEW:OCR-D-%=%)
OCR8 = OCR-D-OCR-CALA-gt4histocr-$(DEW:OCR-D-%=%)

$(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7) $(OCR8): $(DEW)

$(OCR1) $(OCR2): TOOL = ocrd-cis-ocropy-recognize
$(OCR1): PARAMS = "textequiv_level": "glyph", "model": "fraktur.pyrnn"
$(OCR2): PARAMS = "textequiv_level": "glyph", "model": "fraktur-jze.pyrnn"

$(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7): TOOL = ocrd-tesserocr-recognize
$(OCR3): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "script/Fraktur"
$(OCR4): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "script/Fraktur+script/Latin"
$(OCR5): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk"
$(OCR6): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk+deu"
$(OCR7): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "GT4HistOCR_2000000+GT4HistOCR_300000+GT4HistOCR_100000"

$(OCR8): TOOL = ocrd-calamari-recognize
$(OCR8): GPU = 1
$(OCR8): PARAMS = "checkpoint" : "$(VIRTUAL_ENV)/share/calamari/GT4HistOCR/*.ckpt.json"

.DEFAULT_GOAL = $(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7) $(OCR8)

# Down here, custom configuration ends.
###

include Makefile

