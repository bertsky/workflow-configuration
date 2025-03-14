INPUT := $(or $(OUTPUT),$(INPUT),OCR-D-IMG)

OCR-D-OCR-TESS-FRAK2021: $(INPUT)
OCR-D-OCR-TESS-FRAK2021: TOOL = ocrd-tesserocr-recognize
OCR-D-OCR-TESS-FRAK2021: OPTIONS = -P segmentation_level region \
                                   -P model frak2021+GT4HistOCR+frk+deu-frak+deu+Fraktur+Latin \
                                   -P shrink_polygons true # -P auto_model true

OUTPUT := OCR-D-OCR-TESS-FRAK2021
