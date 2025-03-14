INPUT := OCR-D-IMG

$(INPUT):
	ocrd workspace find -G $@ --download

info:
	@echo "This is a partial workflow just downloading the INPUT=$(INPUT) fileGrp"

.PHONY: info

OUTPUT := $(INPUT)
