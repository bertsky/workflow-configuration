# OCR-D workflow configuration main makefile
#
# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside. Then
# chdir to that location.
#
# Call via:
# `make -f WORKFLOW-CONFIG.mk WORKSPACE-DIRS` or
# `make -f WORKFLOW-CONFIG.mk all` or just
# `make -f WORKFLOW-CONFIG.mk`
#
# To rebuild partially, you must pass -W to recursive make:
# `make -f WORKFLOW-CONFIG.mk EXTRA_MAKEFLAGS="-W FILEGRP"`
#
# To build in parallel, use `-j [CPUS] [-l [LOADLEVEL]]`.
#
# To get help on available goals:
# `make help`

# Alternatively, install permanently by running:
# `make install`
# (which will copy the makefiles and shell scripts under the
#  VIRTUAL_ENV prefix).
# Afterwards, just use `ocrd-make` (which will do all the symlinking)
# instead of `make` as above.
#
# For installation via shell-script:
VIRTUAL_ENV ?= $(CURDIR)/local
# copy `ocrd-make` here:
BINDIR = $(abspath $(VIRTUAL_ENV))/bin
# copy the makefiles here:
SHAREDIR = $(abspath $(VIRTUAL_ENV))/share/workflow-configuration

# This file must be included by all specific configuration makefiles.

# make all targets as intermediate and not to be removed
# (because we must remove via METS):
.SECONDARY:

.EXPORT_ALL_VARIABLES:

# remove all failed targets, so we can re-enter
# (this does not work in GNU make -- #16372):
#.DELETE_ON_ERROR:

# we need associative arrays, process substitution etc.
# also, fail on failed intermediates as well:
SHELL = bash -o pipefail

CONFIGURATION := $(abspath $(firstword $(MAKEFILE_LIST)))

CONFIGDIR := $(dir $(CONFIGURATION))
CONFIGNAME := $(basename $(notdir $(CONFIGURATION)))

WORKSPACES := $(patsubst %/mets.xml,%,$(wildcard */data/mets.xml */mets.xml))

ifeq ($(filter help clean cleanup info repair deps-ubuntu install uninstall %.mk,$(MAKECMDGOALS)),)
ifeq ($(notdir $(MAKEFILE_LIST)),Makefile)
$(error Did you forget to select a workflow configuration makefile?)
else
ifeq ($(strip $(WORKSPACES)),)
WORKSPACES := $(foreach GOAL,$(MAKECMDGOALS),$(patsubst %/mets.xml,%,$(wildcard $(GOAL)/data/mets.xml $(GOAL)/mets.xml)))
endif
endif
endif

help:
	@echo "Running OCR-D workflow configurations on workspaces:"
	@echo
	@echo "  Usage:"
	@echo "  make [OPTIONS] [-f CONFIGURATION] [TARGETS] [VARIABLE-ASSIGNMENTS]"
	@echo "  make [OPTIONS] NEW-CONFIGURATION.mk"
	@echo
	@echo "  Targets (general):"
	@echo "  * help (this message)"
	@echo "  * deps-ubuntu (install extra system packages needed here, beyond ocrd and processors)"
	@echo "  * install (copy 'ocrd-make' script and configuration makefiles to"
	@echo "  *          VIRTUAL_ENV=$(VIRTUAL_ENV) from repository workdir)"
	@echo "  * uninstall (remove 'ocrd-make' script and configuration makefiles from"
	@echo "  *            VIRTUAL_ENV=$(VIRTUAL_ENV))"
	@echo "  * clean (remove installed configuration makefiles previously symlinked/copied from"
	@echo "  *        PWD=$(CURDIR))"
	@echo
	@echo "  Targets (data processing):"
	@echo "  * repair (fix workspaces by ensuring PAGE-XML file MIME types and correct imageFilename)"
	@echo "  * info (short self-description of the selected configuration)"
	@echo "  * show (print command sequence that would be executed for the selected configuration)"
	@echo "  * server (start workflow server for the selected configuration; control via 'ocrd workflow client')"
	@echo "  * view (clone workspaces into subdirectories view/, filtering file groups for the"
	@echo "          selected configuration, then prepare PAGE-XML for JPageViewer)"
	@echo "  * larex (build default target plus LAREX export in all of the workspaces)"
	@echo "  * all (build default target in all of the following workspaces...)"
	@for workspace in $(WORKSPACES); do echo "  * $$workspace"; done
	@echo
	@echo "  Makefiles (i.e. configurations; select via '-f CONFIGURATION.mk')"
	@echo
	@for makefile in $(EXISTING_MAKEFILES); do echo "  * $$makefile"; done
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * VIRTUAL_ENV: directory prefix to use for installation"
	@echo "  * EXTRA_MAKEFLAGS: pass these options to recursive make (e.g. -W OCR-D-GT-SEG-LINE)"
	@echo "  * LOGLEVEL: override global loglevel for all OCR-D processors"
	@echo "    (if unset, then default/configured logging levels apply)"
	@echo "  * PAGES: override pageId selection (comma-separated list)"
	@echo "    (if unset, then all pages will be processed)"

.PHONY: help

show: $(.DEFAULT_GOAL)

export PATH VIRTUAL_ENV
server: PORT ?= 5000
server: HOST ?= 127.0.0.1
server:
	IFS=$$'\n' TASKS=($$($(MAKE) -s --no-print-directory -R -f $(CONFIGURATION) show | sed -n "s/'$$//;s/^'ocrd-//p")); \
	ocrd workflow server -h $(HOST) -p $(PORT) $(and $(LOGLEVEL),-l $(LOGLEVEL)) "$${TASKS[@]}" 2>&1 | tee -a _server.$(CONFIGNAME).log

.PHONY: show server

deps-ubuntu:
	apt-get -y install parallel xmlstarlet bc sed

install:
	mkdir -p $(BINDIR) $(SHAREDIR)
	cp -Lf Makefile $(EXISTING_MAKEFILES) $(SHAREDIR)
	sed 's,^SHAREDIR=.*,SHAREDIR="$(SHAREDIR)",' < ocrd-make > $(BINDIR)/ocrd-make
	cp -Lf ocrd-import $(BINDIR)
	cp -Lf ocrd-export-larex $(BINDIR)
	chmod +x $(BINDIR)/ocrd-make $(BINDIR)/ocrd-import $(BINDIR)/ocrd-export-larex

uninstall:
	$(RM) $(BINDIR)/ocrd-make
	$(RM) -r $(SHAREDIR)

clean cleanup:
	find $(SHAREDIR) \( -name 'Makefile' -or -name '*.mk' \) -exec basename {} \; |xargs rm -v

.PHONY: deps-ubuntu install uninstall cleanup clean

# spawn a new configuration
define skeleton =
# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside. Then
# chdir to that location.
# 
# Call via:
# `make -f WORKFLOW-CONFIG.mk WORKSPACE-DIRS` or
# `make -f WORKFLOW-CONFIG.mk all` or just
# `make -f WORKFLOW-CONFIG.mk`
#
# To rebuild partially, you must pass -W to recursive make:
# `make -f WORKFLOW-CONFIG.mk EXTRA_MAKEFLAGS="-W FILEGRP"`
#
# To build in parallel, use `-j [CPUS] [-l [LOADLEVEL]]`.
#
# To get help on available goals:
# `make help`

###
# From here on, custom configuration begins.

INPUT = OCR-D-IMG

$$(INPUT):
	ocrd workspace find -G $$@ --download

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

ifneq ($(if $(filter info show server deps-ubuntu install uninstall %.mk,$(MAKECMDGOALS)),,$(strip $(WORKSPACES))),)
# we are in the top-level directory
.DEFAULT_GOAL = all # overwrite configuration's default for workspaces

# use --keep-going on top level (workspaces are independent of each other)
# (does not affect command-line choices; these will be automatically added
#  by make via MAKEOVERRIDES)
# will be suppressed unconditionally for recursive level below
# (since processors and recipe steps depend on each other)
MAKEFLAGS = k

# suppress built-in pattern rules (we are not compiling source code):
.SUFFIXES:

# short-hand for workspace targets written with trailing slash:
$(WORKSPACES:%=%/): %/: %

all: $(WORKSPACES)
	@cat $(patsubst %,%.$(CONFIGNAME).log,$(WORKSPACES)) > _all.$(CONFIGNAME).log
	@cat _all.$(CONFIGNAME).log | sed -ne 's|^.*\([0-9]\+\) lines \([0-9.]\+\)±\([0-9.]\+\) CER overall / [A-Za-z+_0-9-]* vs \(.*\)$$|\4 \1 \2 \3|p' | { \
		declare -A LENGTHS MEANS VARIAS; \
		while read OCR LENGTH MEAN VARIA; do \
			(($$LENGTH)) || continue; \
			COUNT=$$(($${LENGTHS[$$OCR]:=0}+$$LENGTH)); \
			DELTA=$$(bc -l <<<"$$MEAN-$${MEANS[$$OCR]:=0}"); \
			VARIA=$$(bc -l <<<"$$VARIA^2"); \
			MEANS[$$OCR]=$$(bc -l <<<"($$LENGTH*$$MEAN+$${LENGTHS[$$OCR]}*$${MEANS[$$OCR]:=0})/$$COUNT"); \
			VARIAS[$$OCR]=$$(bc -l <<<"($$LENGTH*$$VARIA+$${LENGTHS[$$OCR]}*$${VARIAS[$$OCR]:=0}+$$DELTA^2*$$LENGTH*$${LENGTHS[$$OCR]}/$$COUNT)/$$COUNT"); \
			LENGTHS[$$OCR]=$$COUNT; \
		done; \
		for OCR in $${!LENGTHS[*]}; do \
			MEAN=$$(bc -l <<<"scale=4; $${MEANS[$$OCR]}"); \
			VARIA=$$(bc -l <<<"scale=4; sqrt($${VARIAS[$$OCR]})"); \
			echo "$$OCR: $$MEAN±$$VARIA"; \
		done; }
	@echo "all done with $(CONFIGNAME)"

$(WORKSPACES):
	$(MAKE) -R -C $@ -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) MAKEFLAGS=$(subst k,,$(MAKEFLAGS)) 2>&1 | tee -a $@.$(CONFIGNAME).log

.PHONY: all $(WORKSPACES)

repair: $(WORKSPACES:%=repair-%)

$(WORKSPACES:%=repair-%):
	$(MAKE) -R -C $(@:repair-%=%) -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) MAKEFLAGS=$(subst k,,$(MAKEFLAGS)) repair

.PHONY: repair $(WORKSPACES:%=repair-%)

view: $(WORKSPACES:%=view/%)

# prepare for export
$(WORKSPACES:%=view/%): view/%: %
	@mkdir -p view
# delete local file IDs not existing in the filesystem:
	ocrd workspace -d $< prune-files
# bag, but do no zip yet (because we must still filter and path prefixing and filename suffixing):
	ocrd -l WARN zip bag -d $< -i $(@:%/data=%) -Z $(@:%/data=%)
	$(MAKE) -R -C $(@:%/data=%)/data -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) prune-view
# bag again and zip:
	ocrd -l WARN zip bag -d $(@:%/data=%)/data -i $(@:%/data=%) $(@:%/data=%).zip
	@echo new workspace can be viewed under $(@:%/data=%)/data or $(@:%/data=%).zip

.PHONY: view $(WORKSPACES:%=view/%)

larex:
	$(MAKE) -R -C $@ -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) MAKEFLAGS=$(subst k,,$(MAKEFLAGS)) larex 2>&1 | tee -a $@.$(CONFIGNAME).log

.PHONY: larex

else
ifneq ($(if $(filter info show,$(MAKECMDGOALS)),true,$(wildcard $(CURDIR)/mets.xml)),)
# we are inside workspace during recursive make

# All operations use the normal date stamping to determine
# whether they must be updated. This allows the user control
# over incremental vs. re-builds (`-B` or `-W step`) etc.
# (However, unfortunately, `-W` does not carry across recursive
#  invocation or appear in MAKEFLAGS, hence the introduction
#  of EXTRA_MAKEFLAGS.)
#
# But we cannot trust the filesystem alone: it might be
# inconsistent with the METS representation (especially
# if written partially).
#
# So in the recipes, once we know some output is out of date,
# we must ensure it does not get in the way in the METS.
# Hence we always process with --overwrite.
#
# Likewise, when errors occur during processing, leaving
# a partial annotation in the workspace, we need to remove
# all that from the filesystem in order to make way for
# re-entry. Due to GNU make's #16372, we cannot use builtin
# .DELETE_ON_ERROR for that.
# For the same reason (i.e. poor support for directories as
# targets), we must update the timestamp of the target when
# the processor succeeded, because it might not actually
# create new files (but merely overwrite them).
#
# Moreover, the default rule must not catch file groups that
# were never meant to be rebuilt (like image or GT input),
# but happen to be outdated / inexisting in the file system.
# We must at least prevent removing/updating file groups which
# have no preqrequisites at all or no TOOL definition.
#
# So overall, the last-resort pattern recipe for processors
# comprises:
# 1. line: a check failing the recipe when no TOOL/prereqs were set
# 2. line: generating the parameter JSON file
# 3. line: the actual TOOL execution, with `touch` on success,
#          and `rm -r` on failure.
#
# Further, when processors have more than 1 input file group
# (i.e. their output target has more than 1 input prerequisite),
# we must concatenate this space delimited list with the OCR-D
# comma syntax for multiple file groups.
#
# FIXME: This currently uses wild contortions to allow multiple output file groups.
#        (You have to run with a phony target in comma-concatenated form
#         to avoid interpreting them as multiple independent targets, but then need
#         an auxiliary rule connecting that form to its constituent directories.
#         Below recipe became unreadable due to the many space/comma substitutions.)
# usage example:
# OUT1,OUT2: IN
# OUT1,OUT2: TOOL = ocrd-tool-name
# .PHONY: OUT1,OUT2
# OUT1 OUT2: OUT1,OUT2 ; touch -c $@

space = $() $()
comma = ,
define toolrecipe =
	$(TOOL) $(and $(LOGLEVEL),-l $(LOGLEVEL)) $(and $(PAGES),-g $(PAGES)) \
	-I $(subst $(space),$(comma),$^) -p $@.json \
	-O $@ --overwrite $(OPTIONS) 2>&1 | tee $@.log && \
	touch -c $(subst $(comma),$(space),$@) || { \
	$(if $(wildcard $(firstword $(subst $(comma),$(space),$@))), \
	     touch -c -d "$(shell date -Ins -r $(firstword $(subst $(comma),$(space),$@)))" \
		$(subst $(comma),$(space),$@), \
	     rm -fr $(subst $(comma),$(space),$@)); false; }
endef
# Extra recipe to control allocation of GPU resources
# (for processors explicitly configured as CUDA-enabled):
# If not enough GPUs are available for a new processor
# at any given time, then invocation should fallback to CPU.
# (This requires CUDA toolkit and GNU parallel.)
gputoolrecipe = $(toolrecipe)
ifneq ($(shell which nvidia-smi),)
ifneq ($(shell which sem),)
NGPUS = $(shell nvidia-smi -L | wc -l)
define gputoolrecipe =
if sem --nn --id OCR-D-GPUSEM -j $(NGPUS) --st -3 true 2>/dev/null; then \
   sem --nn --id OCR-D-GPUSEM -j $(NGPUS) --fg -u $(toolrecipe); else \
   CUDA_VISIBLE_DEVICES= $(toolrecipe); fi
endef
else
$(warning You risk running into GPU races. Install GNU parallel to synchronize CUDA-enabled processors.)
endif
endif

%: TOOL =
%: GPU =
%: PARAMS =
%: OPTIONS =
ifeq ($(MAKECMDGOALS),show)
# prevent any existing recipes to be executed
override MAKEFLAGS = n
%:
	$(if $(and $(TOOL),$<),$(info '$(TOOL) -I $(subst $(space),$(comma),$^) -O $@ -p "{ $(subst ",\",$(PARAMS)) }" $(OPTIONS)'))
else
%:
	@$(if $(and $(TOOL),$<),$(info building "$@" from "$<" with pattern rule for "$(TOOL)"),$(error No recipe to build "$@" from "$<" with "$(TOOL)"))
	$(file > $@.json, { $(PARAMS) })
	$(if $(GPU),$(gputoolrecipe),$(toolrecipe))
endif

# suppress other multiscalar mechanisms in parallel mode
# (mostly related to Python numpy and Tesseract OpenMP:)
NPROCS != nproc
NPROCS2 != echo $$(( $(NPROCS)/2 ))
NTHREADS ?= $(if $(filter 0,$(NPROCS2)),1,$(NPROCS2))
export OMP_THREAD_LIMIT=$(if $(filter -j,$(MAKEFLAGS)),1,$(NTHREADS))
export OMP_NUM_THREADS=$(if $(filter -j,$(MAKEFLAGS)),1,$(NTHREADS))
export OPENBLAS_NUM_THREADS=$(if $(filter -j,$(MAKEFLAGS)),1,$(NTHREADS))
export VECLIB_MAXIMUM_THREADS=$(if $(filter -j,$(MAKEFLAGS)),1,$(NTHREADS))
export NUMEXPR_NUM_THREADS=$(if $(filter -j,$(MAKEFLAGS)),1,$(NTHREADS))
# FIXME: how about multiprocessing/threading in Tensorflow?

# define JPageViewer export target on top of workflow
view:
# clone into a new directory
	@mkdir -p view
# delete local file IDs not existing in the filesystem:
	ocrd workspace prune-files
# bag, but do no zip yet (because we must still filter and path prefixing and filename suffixing):
	ocrd -l WARN zip bag -i $(notdir $(CURDIR:%/data=%)) -Z view
	$(MAKE) -R -C view/data -I $(CONFIGDIR) -f $(CONFIGURATION) $(EXTRA_MAKEFLAGS) prune-view
	@echo new workspace can be viewed under view/data

prune-view:
# filter out file groups we do not need for current configuration:
	ocrd workspace remove-group -fr $$(ocrd workspace list-group | \
		fgrep -xv -f <(LC_MESSAGES=C \
			$(MAKE) -R -nd -I $(CONFIGDIR) -f $(CONFIGURATION) |& \
			fgrep -e 'Considering target file' -e 'Trying rule prerequisite' | \
			cut -d\' -f2 | { cat; echo OCR-D-IMG* | tr ' ' '\n'; }))
# change imageFilename paths from METS-relative to PAGE-relative for JPageViewer:
	ocrd workspace find -m application/vnd.prima.page+xml | \
		while read name; do \
		test -f $$name || continue; \
		sed -i 's|imageFilename="\([^/]\)|imageFilename="../\1|' $$name; \
		done
	@find . -type d -empty -delete

# define LAREX export target on top of workflow
larex: $(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP-LAREX

$(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP-LAREX: $(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP
$(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP-LAREX: TOOL = ocrd-export-larex

# redefine imageFilename from cropped/deskewed page
$(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP: $(.DEFAULT_GOAL:%-CROP-LAREX=%)
$(.DEFAULT_GOAL:%-CROP-LAREX=%)-CROP: TOOL = ocrd-segment-replace-original

.PHONY: larex

repair:
# repair badly published workspaces:
# fix MIME type of PAGE-XML files:
	sed -i 's|MIMETYPE="image/jpeg" ID="OCR-D-GT|MIMETYPE="application/vnd.prima.page+xml" ID="OCR-D-GT|' mets.xml
# fix imageFilename (relative to METS, not to PAGE)
	for file in $$(ocrd workspace find -m application/vnd.prima.page+xml -k local_filename); do \
		test -f $$file || continue; \
		sed -i 's|imageFilename="../|imageFilename="|' $$file; \
	done
# fix imageFilename (find PAGE filename in METS, find image filename via same pageId in METS):
	for page in $$(ocrd workspace find -k pageId | sort -u); do \
		img=$$(ocrd workspace find -G OCR-D-IMG -g $$page -k local_filename); \
		test -f $$img || continue; \
		for file in $$(ocrd workspace find -m application/vnd.prima.page+xml -g $$page -k local_filename); do \
			test -f $$file || continue; \
			img0=$$(sed -n "s|^.*imageFilename=\"\([^\"]*\)\".*$$|\1|p" $$file); \
			test -f $$img0 && continue; \
			sed -i "s|imageFilename=\"$$img0\"|imageFilename=\"$$img\"|" $$file; \
		done; \
	done

.PHONY: view prune-view repair info

# prevent parallel execution of recipes within one workspace
# (because that would require FS synchronization on the METS,
# and would make multi-output recipes harder to write):
.NOTPARALLEL:
else # (if not found workspaces and not inside workspace)
ifeq ($(filter help info show server deps-ubuntu install uninstall %.mk,$(MAKECMDGOALS)),)
$(error No workspaces in "$(CURDIR)" or among "$(MAKECMDGOALS)")
endif # (if pseudo-target)
endif # (if inside workspace)
endif # (if found workspaces)

# do not search for implicit rules here:
%/Makefile: ;
Makefile: ;
$(CONFIGURATION): ;
EXISTING_MAKEFILES := $(patsubst $(CONFIGDIR)/%,%,$(wildcard $(CONFIGDIR)/*.mk))
$(EXISTING_MAKEFILES): ;
