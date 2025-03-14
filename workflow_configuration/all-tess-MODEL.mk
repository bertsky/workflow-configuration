INPUT := $(or $(OUTPUT),$(INPUT),OCR-D-IMG)

$(INPUT):
	ocrd workspace find -G $@ --download

OCR-D-OCR-TESS: $(INPUT)
OCR-D-OCR-TESS: TOOL = ocrd-tesserocr-recognize
OCR-D-OCR-TESS: MODEL ?= Fraktur+Latin
OCR-D-OCR-TESS: OPTIONS = -P segmentation_level region -P model $(MODEL) -P shrink_polygons true # -P auto_model true

OUTPUT := OCR-D-OCR-TESS
