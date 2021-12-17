# OCR-D workflow configuration abstract makefile

# This file must be included by all concrete configuration makefiles.
# It can then run that workflow on a single workspace (non-recursively).
#
# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside and running
# `make` there (or including files from there).
#
# Call via:
# `make -f WORKFLOW-CONFIG.mk`
#
# To rebuild partially, you must pass -W to `make`:
# `make -f WORKFLOW-CONFIG.mk -W FILEGRP`
#
# To build in parallel, use `-j [CPUS] [-l [LOADLEVEL]]` etc.
#
# To get general help:
# `make -f WORKFLOW-CONFIG.mk help`
#
# To get a description of the workflow:
# `make -f WORKFLOW-CONFIG.mk info`

# Alternatively, install permanently by running:
# `make install`
# (in the git repo), which will copy this file (as `Makefile`), all
# preconfigured makefiles, and some shell scripts into
# a fixed target directory under the VIRTUAL_ENV prefix).
#
# Afterwards, just use `ocrd-make` (which can be used both for single
# workspaces and recursive parallel runs on multiple workspaces)
# instead of `make` as above.
#

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

# opt-in for any specific rules in the workspace/datadir FS
-include local.mk

CONFIGURATION := $(abspath $(firstword $(MAKEFILE_LIST)))

CONFIGDIR := $(dir $(CONFIGURATION))
CONFIGNAME := $(basename $(notdir $(CONFIGURATION)))

ifeq ($(filter-out Makefile workflow.mk,$(notdir $(MAKEFILE_LIST))),)
ifneq ($(MAKECMDGOALS),help)
$(error Did you forget to select a workflow configuration makefile?)
endif
endif

help:
	@echo "Running OCR-D workflow configurations on workspaces:"
	@echo
	@echo "  Usage:"
	@echo "  make [OPTIONS] [-f CONFIGURATION] [TARGETS] [VARIABLE-ASSIGNMENTS]"
	@echo
	@echo "  Targets (general):"
	@echo "  * help (this message)"
	@echo "  * info (short self-description of the selected configuration)"
	@echo "  * show (print command sequence that would be executed for the selected configuration)"
	@echo "  * server (start workflow server for the selected configuration; control via 'ocrd workflow client')"
	@echo
	@echo "  Targets (data processing):"
	@echo "  * % (name of the target fileGrp, overriding the default goal)"
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * LOGLEVEL: override global loglevel for all OCR-D processors"
	@echo "    (if unset, then default/configured logging levels apply)"
	@echo "  * PAGES: override pageId selection (comma-separated list)"
	@echo "    (if unset, then all pages will be processed)"

.PHONY: help info

show: $(.DEFAULT_GOAL)

export PATH VIRTUAL_ENV
server: PORT ?= 5000
server: HOST ?= 127.0.0.1
server: TIMEOUT ?= 0
server: WORKERS ?= 1
server:
	IFS=$$'\n' TASKS=($$($(MAKE) -s --no-print-directory -R -f $(CONFIGURATION) show | sed -n "s/'$$//;s/^'ocrd-//p")); \
	ocrd workflow server -j $(WORKERS) -t $(TIMEOUT) -h $(HOST) -p $(PORT) $(and $(LOGLEVEL),-l $(LOGLEVEL)) "$${TASKS[@]}" 2>&1 | tee -a _server.$(CONFIGNAME).log

.PHONY: show server

ifneq ($(wildcard $(CURDIR)/mets.xml),)
# we are inside workspace

# All operations use the normal date stamping to determine
# whether they must be updated. This allows the user control
# over incremental vs. re-builds (`-B` or `-W step`) etc.
#
# But we cannot trust the filesystem alone: it might be
# inconsistent with the METS representation (especially
# if written partially).
#
# So in the recipes, once we know some output is out of date,
# we must ensure it does not get in the way in the METS.
# Hence we always process with --overwrite.
# (That does not precisely account for the usage of --page-id
#  or PAGES, but it's a sacrifice we can make.)
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
	-I $(subst $(space),$(comma),$+) -p $@.json \
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
# FIXME: There still is a race condition here, because checking for availability
#        with active timeout and actually entering the semaphore is not atomic.
#        So in the worst case, when two GPU jobs enter at the same time,
#        they will each see a free sema and then both attempt to use it.
#        That means that one will have to wait for the other (instead of
#        falling back to CPU after 3 secs).
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
	$(if $(and $(TOOL),$<),$(info '$(TOOL) -I $(subst $(space),$(comma),$+) -O $@ -p "{ $(subst ",\",$(PARAMS)) }" $(OPTIONS)'))
else
%:
	@$(if $(and $(TOOL),$<),$(info building "$@" from "$<" with pattern rule for "$(TOOL)"),$(error No recipe to build "$@" from "$<" with "$(TOOL)"))
	$(file > $@.json, { $(PARAMS) })
	$(if $(GPU),$(gputoolrecipe),$(toolrecipe))
endif

# prevent parallel execution of recipes within one workspace
# (because that would require FS synchronization on the METS,
# and would make multi-output recipes harder to write):
.NOTPARALLEL:
else # (if not inside workspace)
ifeq ($(filter help info show server,$(MAKECMDGOALS)),)
$(error No workspaces in "$(CURDIR)", and no generic goals among "$(MAKECMDGOALS)")
endif # (if pseudo-target)
endif # (if inside workspace)

# do not search for implicit rules here:
%/Makefile: ;
Makefile: ;
local.mk: ;
$(CONFIGURATION): ;
