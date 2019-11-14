# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside. Then
# chdir to that location.

# Call via:
# `make -f WORKFLOW-CONFIG.mk WORKSPACE-DIRS` or
# `make -f WORKFLOW-CONFIG.mk all` or just
# `make -f WORKFLOW-CONFIG.mk`
# To rebuild partially, you must pass -W to recursive make:
# `make -f WORKFLOW-CONFIG.mk EXTRA_MAKEFLAGS="-W FILEGRP"`

###
# From here on, custom configuration begins.

info:
	@echo "Read GT line segmentation,"
	@echo "then binarize+denoise+deskew pages,"
	@echo "then clip+deskew regions,"
	@echo "then resegment+dewarp lines,"
	@echo "then recognize lines with various Ocropus+Tesseract models,"
	@echo "and finally evaluate OCR quality by measuring"
	@echo "character error rates on line texts w.r.t. GT."

INPUT = OCR-D-GT-SEG-LINE

BIN = $(INPUT)-BINPAGE-sauvola

$(BIN): $(INPUT)
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

CLIP = $(DESK)-CLIP

$(CLIP): $(DESK)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

DESK2 = $(CLIP)-DESKEW-tesseract

$(DESK2): $(CLIP)
$(DESK2): TOOL = ocrd-tesserocr-deskew
$(DESK2): PARAMS = "operation_level": "region", "min_orientation_confidence": 1.5

RESEG = $(DESK2)-RESEG

$(RESEG): $(DESK2)
$(RESEG): TOOL = ocrd-cis-ocropy-resegment

DEW = $(RESEG)-DEWARP

$(DEW): $(RESEG)
$(DEW): TOOL = ocrd-cis-ocropy-dewarp

OCR1 = $(DEW:$(INPUT)-%=OCR-D-OCR-OCRO-fraktur-%)
OCR2 = $(DEW:$(INPUT)-%=OCR-D-OCR-OCRO-frakturjze-%)
OCR3 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-Fraktur-%)
OCR4 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-Fraktur+Latin-%)
OCR5 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-frk-%)
OCR6 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-frk+deu-%)
OCR7 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-gt4histocr-%)
OCR8 = $(DEW:$(INPUT)-%=OCR-D-OCR-CALA-gt4histocr-%)

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

OUTPUT = $(DEW)-OCR

$(OUTPUT): $(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6) $(OCR7) $(OCR8)
# must be last to become first:
$(OUTPUT): $(INPUT)
	ocrd-cor-asv-ann-evaluate -I $(call concatcomma,$^)

.DEFAULT_GOAL = $(OUTPUT)

.PHONY: $(OUTPUT)

comma = ,
concatcomma = $(subst $() $(),$(comma),$(1))

# Down here, custom configuration ends.
###

include Makefile

