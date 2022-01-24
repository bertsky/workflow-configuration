# OCR-D workflow configuration installation makefile
#
# Install workflow configurations persistently by running:
# `make install`
# (in the git repo), which will copy workflow.mk (as `Makefile`), all
# preconfigured makefiles, and some shell scripts into
# a fixed target directory under the VIRTUAL_ENV prefix).
#
# For installation via shell-script:
VIRTUAL_ENV ?= $(CURDIR)/local
# copy `ocrd-make` here:
BINDIR = $(abspath $(VIRTUAL_ENV))/bin
# copy the makefiles here:
SHAREDIR = $(abspath $(VIRTUAL_ENV))/share/workflow-configuration

# we need associative arrays, process substitution etc.
# also, fail on failed intermediates as well:
SHELL = bash -o pipefail

CONFIGURATION := $(abspath $(firstword $(MAKEFILE_LIST)))

CONFIGDIR := $(dir $(CONFIGURATION))

EXISTING_MAKEFILES = $(patsubst $(CONFIGDIR)/%,%,$(wildcard $(CONFIGDIR)/*.mk))
EXISTING_TRANSFORMS = $(patsubst $(CONFIGDIR)/%,%,$(wildcard $(CONFIGDIR)/*.xsl))

ifeq ($(filter workflow.mk,$(EXISTING_MAKEFILES)),)
$(error "Found no .mk makefiles in source directory $(CONFIGDIR)")
endif
ifeq ($(EXISTING_TRANSFORMS),)
$(error "Found no .xsl transforms in source directory $(CONFIGDIR)")
endif

help:
	@echo "Installing OCR-D workflow configurations:"
	@echo
	@echo "  Usage:"
	@echo "  make [OPTIONS] TARGET"
	@echo
	@echo "  Targets:"
	@echo "  * help        (this message)"
	@echo "  * deps-ubuntu (install extra system packages needed here, beyond ocrd and processors)"
	@echo "  * install     (copy 'ocrd-make' script and configuration makefiles to"
	@echo "  *              VIRTUAL_ENV=$(VIRTUAL_ENV)"
	@echo "  *              from repository workdir)"
	@echo "  * uninstall   (remove 'ocrd-make' script and configuration makefiles from"
	@echo "  *              VIRTUAL_ENV=$(VIRTUAL_ENV))"
	@echo "  * %.mk        (any filename with suffix .mk not existing yet: spawn new makefile from pattern)"
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * VIRTUAL_ENV: directory prefix to use for installation"

.PHONY: help

deps-ubuntu:
	apt-get -y install parallel xmlstarlet bc sed

XSLPROGS =$(EXISTING_TRANSFORMS:%.xsl=%)
SHPROGS = ocrd-make ocrd-import ocrd-page-transform
PROGS = $(SHPROGS) $(XSLPROGS)
install-bin: $(PROGS:%=$(BINDIR)/%) | $(BINDIR)

$(SHPROGS:%=$(BINDIR)/%): $(BINDIR)/%: %
	sed 's,^SHAREDIR=.*,SHAREDIR="$(SHAREDIR)",' < $< > $@
	chmod +x $@

$(XSLPROGS:%=$(BINDIR)/%): %: page-transform
	sed 's,^SHAREDIR=.*,SHAREDIR="$(SHAREDIR)",' < $< > $@
	chmod +x $@

$(BINDIR) $(SHAREDIR):
	@mkdir $@

install: install-bin | $(SHAREDIR)
	cp -Lf -t $(SHAREDIR) $(EXISTING_MAKEFILES) $(EXISTING_TRANSFORMS) ocrd-tool.json
	mv $(SHAREDIR)/workflow.mk  $(SHAREDIR)/Makefile

uninstall:
	$(RM) $(PROGS:%=$(BINDIR)/%)
	$(RM) -r $(SHAREDIR)


.PHONY: deps-ubuntu install install-bin uninstall

# spawn a new configuration
define skeleton =
# This file can run a workflow on a single workspace (non-recursively).
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

###
# From here on, custom configuration begins.

INPUT = OCR-D-IMG

$$(INPUT):
	ocrd workspace find -G $$@ --download

OUTPUT = OCR-D-OUT
$$(OUTPUT): $$(INPUT)
$$(OUTPUT): TOOL = ocrd-dummy
$$(OUTPUT): PARAMS = 

info:
	@echo "This is a dummy configuration that creates a copy $$(OUTPUT) of the input fileGrp $$(INPUT)"

.PHONY: info

.DEFAULT_GOAL = $$(OUTPUT)

# Down here, custom configuration ends.
###

SELFDIR := $$(dir $$(abspath $$(firstword $$(MAKEFILE_LIST))))
include $$(SELFDIR)/Makefile
endef

export skeleton

%.mk:
	@echo >$@ "$$skeleton"

# do not search for implicit rules here:
%/Makefile: ;
Makefile: ;
local.mk: ;
ocrd-tool.json: ;
$(CONFIGURATION): ;
$(EXISTING_MAKEFILES): ;
$(EXISTING_TRANSFORMS): ;
$(PROGS): ;
