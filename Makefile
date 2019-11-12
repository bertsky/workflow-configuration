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

# This file must be included by all specific configuration makefiles.

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

WORKSPACES = $(patsubst %/mets.xml,%,$(wildcard */data/mets.xml */mets.xml))

ifeq ($(notdir $(MAKEFILE_LIST)),Makefile)
ifeq ($(filter repair,$(MAKECMDGOALS)),)
$(error Did you forget to select a workflow configuration makefile?)
endif
endif

ifneq ($(strip $(WORKSPACES)),)
# we are in the top-level directory
.DEFAULT_GOAL = all # overwrite configuration's default for workspaces

all: $(WORKSPACES)
	@cat $(patsubst %,%.$(CONFIGNAME).log,$(WORKSPACES)) > _all.$(CONFIGNAME).log
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
	$(MAKE) -R -C $@ -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) 2>&1 | tee $@.$(CONFIGNAME).log

.PHONY: all $(WORKSPACES)

repair: $(WORKSPACES:%=repair-%)

$(WORKSPACES:%=repair-%):
	$(MAKE) -R -C $(@:repair-%=%) -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) repair

.PHONY: repair $(WORKSPACES:%=repair-%)

view: $(WORKSPACES:%=view/%)

# prepare for export
$(WORKSPACES:%=view/%): view/%: %
	@mkdir -p view
# delete local file IDs not existing in the filesystem:
	ocrd workspace -d $< prune-files
# bag, but do no zip yet (because we must still filter and path prefixing and filename suffixing):
	ocrd -l WARN zip bag -d $< -i $(@:%/data=%) -Z $(@:%/data=%)
	$(MAKE) -R -C $@ -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) view
# bag again and zip:
	ocrd -l WARN zip bag -d $@ -i $(@:%/data=%) $(@:%/data=%).zip

.PHONY: view $(WORKSPACES:%=view/%)

help:
	@echo "Running OCR-D workflow configurations on workspaces:"
	@echo
	@echo "  Targets:"
	@echo "  * help (this message)"
	@echo "  * info (short self-description of the configuration)"
	@echo "  * view (clone workspaces, filter current config, prepare for JPageViewer)"
	@echo "  * repair (fix workspaces by ensuring PAGE-XML file MIME types and correct imageFilename)"
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

.PHONY: help

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
# To get help on available goals:
# `make help`

###
# From here on, custom configuration begins.

INPUT = OCR-D-IMG

OUTPUT = foo
$$(OUTPUT): $$(INPUT)
	touch $$@

info:
	@echo "This is a dummy configuration that creates an empty file $$(OUTPUT)"

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
# Likewise, when errors occur during processing, leaving
# a partial annotation in the workspace, we need to remove
# all that from the filesystem in order to make way for
# re-entry. Due to GNU make's #16372, we cannot use builtin
# .DELETE_ON_ERROR for that.
# FIXME: Also, this does not cover multiple output filegrps
# (ignoring them will give side effects!)
TOOL =
PARAMS = 
%:
	-ocrd workspace remove-group -r $@ 2>/dev/null
	$(file > $@.json, { $(PARAMS) })
	$(TOOL) -I $< -O $@ -p $@.json 2>&1 | tee $@.log && \
		touch $@ || { \
		rm -fr $@.json $@; exit 1; }

view:
# filter out file groups we do not need for current configuration:
	ocrd workspace remove-group -fr $$(ocrd workspace list-group | \
		fgrep -xv -f <(LC_MESSAGES=C \
			$(MAKE) -R -nd -I $(CONFIGDIR) -f $(CONFIGURATION) |& \
			fgrep -e 'Considering target file' -e 'Trying rule prerequisite' | \
			cut -d\' -f2 | { cat; echo OCR-D-IMG* | tr ' ' '\n'; }))
# change imageFilename paths from METS-relative to PAGE-relative for JPageViewer,
# also ensure all files have valid filename suffixes:
	ocrd workspace find -m application/vnd.prima.page+xml | \
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
	@find . -type d -empty -delete

repair:
# repair badly published workspaces:
# fix MIME type of PAGE-XML files:
	sed -i 's|MIMETYPE="image/jpeg" ID="OCR-D-GT|MIMETYPE="application/vnd.prima.page+xml" ID="OCR-D-GT|' mets.xml
ifeq ($(findstring 1000pages,$(CURDIR)),)
# fix imageFilename (relative to METS, not to PAGE)
	for file in $$(ocrd workspace find -m application/vnd.prima.page+xml -k local_filename); do \
		test -f $$file || continue; \
		sed -i 's|imageFilename="../|imageFilename="|' $$file; \
	done
else
# fix imageFilename (find PAGE filename in METS, find image filename via same pageId in METS):
	for page in $$(ocrd workspace find -k pageId | sort -u); do \
		img=$$(ocrd workspace find -G OCR-D-IMG -g $$page -k local_filename); \
		for file in $$(ocrd workspace find -m application/vnd.prima.page+xml -g $$page -k local_filename); do \
			test -f $$file || continue; \
			sed -i "s|imageFilename=\"[^\"]*\"|imageFilename=\"$$img\"|" $$file; \
		done; \
	done
endif

.PHONY: view repair info

# prevent parallel execution of recipes within one workspace
# (because that would require FS synchronization on the METS,
# and would make multi-output recipes harder to write):
.NOTPARALLEL:
endif

# do not search for implicit rules here:
Makefile: ;
EXISTING_MAKEFILES = $(wildcard $(CONFIGDIR)/*.mk)
$(EXISTING_MAKEFILES): ;


