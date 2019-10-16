include Makefile

# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside. Then
# chdir to that location.

# Call via:
# `make -f workflow-config.mk WORKSPACE-DIRS` or
# `make -f workflow-config.mk all` or just
# `make -f workflow-config.mk`

###
# From here on, custom configuration begins.

INPUT = OCR-D-GT-SEG-LINE

BIN = $(INPUT)-BINPAGE-wolf

$(BIN): $(INPUT)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "wolf"

DEN = $(BIN)-DENOISE-ocropy

$(DEN): $(BIN)
$(DEN): TOOL = ocrd-cis-ocropy-denoise
$(DEN): PARAMS = "level-of-operation": "page", "noise_maxsize": 2

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
$(DESK2): PARAMS = "operation_level": "region"

RESEG = $(DESK2)-RESEG

$(RESEG): $(DESK2)
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

# we should try switching default goal
# between `all` outside
# and `$(OUTPUT)` inside of workspaces
# for now, let's just assume all configs
# use $(OUTPUT)
#.DEFAULT_GOAL := $(OUTPUT)

.PHONY: $(OUTPUT)

