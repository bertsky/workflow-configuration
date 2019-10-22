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

GT_FILEGRPS = $(shell test -f mets.xml && ocrd workspace list-group | fgrep -x -e OCR-D-IMG -e OCR-D-GT-SEG-PAGE -e OCR-D-GT-SEG-BLOCK -e OCR-D-GT-SEG-LINE)

all: $(GT_FILEGRPS)

$(GT_FILEGRPS):
	ocrd workspace find -G $@ --download

.PHONY: all

# Down here, custom configuration ends.
###

include Makefile

