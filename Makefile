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
	@echo "  * test        (run test suite)"
	@echo "  * deps-ubuntu (install extra system packages needed here, beyond ocrd and processors)"
	@echo "  * install     (copy $(SHPROGS) and configuration makefiles to"
	@echo "  *              VIRTUAL_ENV=$(VIRTUAL_ENV)"
	@echo "  *              from repository workdir)"
	@echo "  * uninstall   (remove $(SHPROGS) and configuration makefiles from"
	@echo "  *              VIRTUAL_ENV=$(VIRTUAL_ENV))"
	@echo "  * %.mk        (any filename with suffix .mk not existing yet: spawn new makefile from pattern)"
	@echo "  * test        (run test suite)"
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * VIRTUAL_ENV: directory prefix to use for installation"

.PHONY: help

deps-ubuntu:
	apt-get -y install parallel xmlstarlet bc sed libdbd-sqlite3-perl

XSLPROGS =$(EXISTING_TRANSFORMS:%.xsl=%)
SHPROGS = ocrd-make ocrd-import ocrd-page-transform
PROGS = $(SHPROGS) $(XSLPROGS)
install-bin: $(PROGS:%=$(BINDIR)/%) | $(BINDIR)

$(SHPROGS:%=$(BINDIR)/%): $(BINDIR)/%: %
	sed 's,^SHAREDIR=.*,SHAREDIR="$(SHAREDIR)",' < $< > $@
	chmod +x $@

$(XSLPROGS:%=$(BINDIR)/%): %: xsl-transform
	sed 's,^SHAREDIR=.*,SHAREDIR="$(SHAREDIR)",' < $< > $@
	chmod +x $@

$(BINDIR) $(SHAREDIR):
	@mkdir $@

install: install-bin | $(SHAREDIR)
	cp -Lf $(EXISTING_MAKEFILES) $(EXISTING_TRANSFORMS) ocrd-tool.json $(SHAREDIR)
	mv $(SHAREDIR)/workflow.mk  $(SHAREDIR)/Makefile

uninstall:
	$(RM) $(PROGS:%=$(BINDIR)/%)
	$(RM) -r $(SHAREDIR)

define testrecipe =
function testfun { pushd `mktemp -d` && cp -pr $(abspath $^) . && /usr/bin/time ocrd-make -f all-tess-MODEL.mk MODEL=german_print LOGLEVEL=ERROR $(^F) "$$@" && $(RM) -r $$DIRSTACK; }; testfun
endef
test: test/data1 test/data2
	$(testrecipe)
	$(testrecipe) -j2
	$(testrecipe) -j2 METSSERV=1
	$(testrecipe) -j2 METSSERV=1 PAGEWISE=1
	$(testrecipe) METSSERV=1 PAGEWISE=1
	$(testrecipe) METSSERV=1
	$(testrecipe) TIMEOUT=4 FAILDUMMY=1
	! { $(testrecipe) TIMEOUT=4; }
# todo: test -X ...

test/data1:
	wget -P $@ https://digital.slub-dresden.de/data/kitodo/Brsfded_39946221X-18560530/Brsfded_39946221X-18560530_tif/jpegs/000000{01..04}.tif.original.jpg
	ocrd-import -P $@

test/data2:
	ocrd workspace -d $@ clone "https://digital.slub-dresden.de/oai/?verb=GetRecord&metadataPrefix=mets&identifier=oai:de:slub-dresden:db:id-39946221X-18560530"
	ocrd workspace -d $@ find -G ORIGINAL -g PHYS_0001..PHYS_0004 --download
	ocrd workspace -d $@ rename-group ORIGINAL OCR-D-IMG
	ocrd workspace -d $@ prune-files

TAG ?= bertsky/workflow-configuration
docker:
	docker build \
	-t $(TAG) \
	--build-arg VCS_REF=$(git rev-parse --short HEAD) \
	--build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") .

.PHONY: deps-ubuntu install install-bin uninstall test docker

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
