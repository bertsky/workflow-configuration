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
	@echo "then binarize+deskew pages,"
	@echo "then clip regions,"
	@echo "then resegment+dewarp lines,"
	@echo "then recognize lines with various Ocropus+Tesseract models,"
	@echo "and finally evaluate OCR quality by measuring"
	@echo "character error rates on line texts w.r.t. GT."

INPUT = OCR-D-GT-SEG-LINE

BIN = $(INPUT)-BINPAGE-sauvola

$(BIN): $(INPUT)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "sauvola-ms-split"

DESK = $(BIN)-DESKEW-ocropy

$(DESK): $(BIN)
$(DESK): TOOL = ocrd-cis-ocropy-deskew
$(DESK): PARAMS = "level-of-operation": "page", "maxskew": 5

CLIP = $(DESK)-CLIP

$(CLIP): $(DESK)
$(CLIP): TOOL = ocrd-cis-ocropy-clip

RESEG = $(CLIP)-RESEG

$(RESEG): $(CLIP)
$(RESEG): TOOL = ocrd-cis-ocropy-resegment

DEW = $(RESEG)-DEWARP

$(DEW): $(RESEG)
$(DEW): TOOL = ocrd-cis-ocropy-dewarp

OCR1 = $(DEW:$(INPUT)-%=OCR-D-OCR-OCRO-fraktur-%)
OCR2 = $(DEW:$(INPUT)-%=OCR-D-OCR-OCRO-frakturjze-%)
OCR3 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-Fraktur-%)
OCR4 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-frk-%)
OCR5 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-frk+deu-%)
OCR6 = $(DEW:$(INPUT)-%=OCR-D-OCR-TESS-gt4histocr-%)

$(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6): $(DEW)

$(OCR1) $(OCR2): TOOL = ocrd-cis-ocropy-recognize
$(OCR1): PARAMS = "textequiv_level": "glyph", "model": "fraktur.pyrnn"
$(OCR2): PARAMS = "textequiv_level": "glyph", "model": "fraktur-jze.pyrnn"

$(OCR3) $(OCR4) $(OCR5) $(OCR6): TOOL = ocrd-tesserocr-recognize
$(OCR3): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "Fraktur"
$(OCR4): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk"
$(OCR5): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "frk+deu"
$(OCR6): PARAMS = "textequiv_level" : "glyph", "overwrite_words": true, "model" : "GT4HistOCR_2000000"

OUTPUT = $(DEW)-OCR

$(OUTPUT): $(OCR1) $(OCR2) $(OCR3) $(OCR4) $(OCR5) $(OCR6)
# must be last to become first:
$(OUTPUT): $(INPUT)
	ocrd-cor-asv-ann-evaluate -I `echo $^ | tr ' ' ,`

.DEFAULT_GOAL = $(OUTPUT)

.PHONY: $(OUTPUT)

# Down here, custom configuration ends.
###

include Makefile

