# to be included by all specific configuration makefiles

# make all targets as intermediate and not to be removed
# (because we must remove via METS):
.SECONDARY:

# remove all failed targets, so we can re-enter
# (this does not work in GNU make -- #16372):
#.DELETE_ON_ERROR:

CONFIGURATION = $(abspath $(firstword $(MAKEFILE_LIST)))

CONFIGNAME = $(basename $(notdir $(CONFIGURATION)))

WORKSPACES = $(patsubst %/mets.xml,%,$(wildcard */data/mets.xml))

all: SHELL = /bin/bash # we need associative arrays
all: $(WORKSPACES)
	@cat $(patsubst %/data,%.$(CONFIGNAME).log,$(WORKSPACES)) > _all.$(CONFIGNAME).log
	@cat _all.$(CONFIGNAME).log | sed -ne 's|^.* CER overall / [A-Za-z+_0-9-]* vs \([^:]*\): \([0-9.]*\)$$|\1 \2|p' | { \
		declare -A RESULTS COUNTS; \
		while read OCR RATE; do \
			RESULTS[$$OCR]="$${RESULTS[$$OCR]:=0}+$$RATE"; \
			let COUNTS[$$OCR]++; \
		done; \
		for OCR in $${!RESULTS[*]}; do \
			echo -n "$$OCR: "; \
			echo "($${RESULTS[$$OCR]})/$${COUNTS[$$OCR]}" | bc -l; \
		done; }
	@echo "all done with $(CONFIGNAME)"

$(WORKSPACES):
# workaround for GNU make #16372:
# - delete all files which are not managed by METS
# - then delete all empty directories
	@find $@ -type f -not -name mets.xml -printf "%P\n" | \
		fgrep -xv -f <(ocrd workspace -d $@ find -k url) | \
		while read name; do rm -v $@/$$name; done
	@find $@ -type d -empty -delete
# FIXME: using OUTPUT as explicit goal is just a workaround here:
	$(MAKE) -C $@ -I $(dir $(CONFIGURATION)) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) $(OUTPUT) 2>&1 | tee $(@:/data=).$(CONFIGNAME).log

# All operations use the normal date stamping to determine
# whether they must be updated. This allows the user control
# over incremental vs. re-builds (`-B` or `-W step`).
# But we cannot trust the filesystem alone: it might be
# inconsistent with the METS representation (especially
# if written partially).
# So in the recipes, once we know some output is out of date,
# we must ensure it does not get in the way.
# As long as the processors have no option --overwrite, we
# thus must add a remove command everywhere.
# However, `remove-group -f` does not behave like `rm -f`
# at the moment, so we have to intercept any errors from it.
TOOL =
PARAMS = 
%:
	-ocrd workspace remove-group -rf $@ 2>/dev/null
	$(file > $@.json, { $(PARAMS) })
	$(TOOL) -I $< -O $@ -p $@.json

help:
	@echo "Running OCR-D workflow configurations on workspaces:"
	@echo
	@echo "  Targets:"
	@echo "  * help (this message)"
	@echo "  * all (build all of the following workspaces)"
	@for workspace in $(WORKSPACES); do echo "  * $$workspace"; done
	@echo
	@echo "  Makefiles:"
	@echo "  (Any specific workflow configuration makefiles that live here (*.mk)."
	@echo "   Select a configuration via '-f makefile'.)"
	@echo
	@for makefile in $(wildcard *.mk); do echo "  * $$makefile"; done
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * EXTRA_MAKEFLAGS: pass these options to recursive make (e.g. -W OCR-D-GT-SEG-LINE)"

# spawn a new configuration
define skeleton =
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

OUTPUT = foo
$$(OUTPUT):
	touch $@
endef
export skeleton

%.mk:
	@echo >$@ "$$skeleton"

.PHONY: all help $(WORKSPACES)

# do not search for implicit rules here:
Makefile: ;
