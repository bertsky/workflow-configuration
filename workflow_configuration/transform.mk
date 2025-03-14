INPUT := $(or $(OUTPUT),$(INPUT),OCR-D-IMG)

$(INPUT)-XSL: $(INPUT)
$(INPUT)-XSL: TOOL = ocrd-page-transform
$(INPUT)-XSL: TROPTIONS ?= -P xsl page-extract-text.xsl -P xslt-params "-s level=line" -P mimetype text/plain
$(INPUT)-XSL: OPTIONS = $(TROPTIONS)

OUTPUT := $(INPUT)-XSL
