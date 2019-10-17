# to be included by all specific configuration makefiles

# make all targets as intermediate and not to be removed
# (because we must remove via METS):
.SECONDARY:

# remove all failed targets, so we can re-enter
# (this does not work in GNU make -- #16372):
#.DELETE_ON_ERROR:

# we need associative arrays, process substitution etc.
# also, fail on failed intermediates as well:
SHELL = /bin/bash -o pipefail

CONFIGURATION = $(abspath $(firstword $(MAKEFILE_LIST)))

CONFIGDIR = $(dir $(CONFIGURATION))
CONFIGNAME = $(basename $(notdir $(CONFIGURATION)))

WORKSPACES = $(patsubst %/mets.xml,%,$(wildcard *.ocrd/data/mets.xml))

ifeq ($(MAKEFILE_LIST),Makefile)
$(error Did you forget to select a workflow configuration makefile?)
endif

ifneq ($(WORKSPACES),)
# we are in the top-level directory
.DEFAULT_GOAL = all # overwrite configuration's default for workspaces

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
		{ fgrep -xv -f <(ocrd workspace -d $@ find -k local_filename) || true; } | \
		while read name; do rm -v $@/$$name; done
	@find $@ -type d -empty -delete
	$(MAKE) -R -C $@ -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) 2>&1 | tee $(@:/data=).$(CONFIGNAME).log

view: $(WORKSPACES:%.ocrd/data=%.ocrd.view/data)

# prepare for export
$(WORKSPACES:%.ocrd/data=%.ocrd.view/data): %.ocrd.view/data: %.ocrd/data
# delete local file IDs not existing in the filesystem:
	ocrd workspace -d $< prune-files
# bag, but do no zip yet (because we must still filter and path prefixing and filename suffixing):
	ocrd -l WARN zip bag -d $< -i $(@D) -Z $(@D)
# filter out file groups we do not need for current configuration:
	cd $@ && ocrd workspace remove-group -fr $$(ocrd workspace list-group | \
		fgrep -xv -f <(LC_MESSAGES=C \
			$(MAKE) -R -nd -I $(CONFIGDIR) -f $(CONFIGURATION) |& \
			fgrep -e 'Considering target file' -e 'Trying rule prerequisite' | \
			cut -d\' -f2 | { cat; echo OCR-D-IMG* | tr ' ' '\n'; }))
# change imageFilename paths from METS-relative to PAGE-relative for JPageViewer,
# also ensure all files have valid filename suffixes:
	cd $@ && ocrd workspace find -m application/vnd.prima.page+xml | \
		while read name; do \
		test -f $$name || continue; \
		sed -i 's|imageFilename="\([^/]\)|imageFilename="../\1|' $$name; \
		namespace=$$(xmlstarlet sel -t -m '/*[1]' -v 'namespace-uri()' $$name); \
		xmlstarlet --no-doc-namespace ed --inplace -N pc="$$namespace" \
			-u '/pc:PcGts/pc:Page/@imageFilename[contains(.,"OCR-D-IMG/") and not(contains(.,".tif"))]' \
			-x 'concat(.,".tif")' $$name; \
		done; \
		xmlstarlet sel -N mets=http://www.loc.gov/METS/ -t \
			-v '//mets:fileGrp[@USE="OCR-D-IMG"]/mets:file/mets:FLocat/@xlink:href[not(contains(.,".tif"))]' \
			mets.xml | \
		while read name; do \
		test -f $$name || continue; \
		mv $$name $$name.tif; \
		done; \
		xmlstarlet ed --inplace -N mets=http://www.loc.gov/METS/ \
			-u '//mets:fileGrp[@USE="OCR-D-IMG"]/mets:file/mets:FLocat/@xlink:href[not(contains(.,".tif"))]' \
			-x 'concat(.,".tif")' mets.xml
	@find $@ -type d -empty -delete
# bag again and zip:
	ocrd -l WARN zip bag -d $@ -i $(@D) $(@D).zip

help:
	@echo "Running OCR-D workflow configurations on workspaces:"
	@echo
	@echo "  Targets:"
	@echo "  * help (this message)"
	@echo "  * view (clone workspaces, filter current config, prepare for JPageViewer)"
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

INPUT = OCR-D-IMG

OUTPUT = foo
$$(OUTPUT): $(INPUT)
	touch $$@

.DEFAULT_GOAL = $$(OUTPUT)

# Down here, custom configuration ends.
###

include Makefile
endef

export skeleton

%.mk:
	@echo >$@ "$$skeleton"

else
# we are inside workspace during recursive make

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
# FIXME: Also, this does not cover multiple output filegrps
# (ignoring them will give side effects!)
TOOL =
PARAMS = 
%:
	-ocrd workspace remove-group -rf $@ 2>/dev/null
	$(file > $@.json, { $(PARAMS) })
	$(TOOL) -I $< -O $@ -p $@.json

# prevent parallel execution of recipes within one workspace
# (because that would require FS synchronization on the METS,
# and would make multi-output recipes harder to write):
.NOTPARALLEL:
endif

# do not search for implicit rules here:
Makefile: ;
EXISTING_MAKEFILES = $(wildcard $(CONFIGDIR)/*.mk)
$(EXISTING_MAKEFILES): ;

.PHONY: all view help $(WORKSPACES)

