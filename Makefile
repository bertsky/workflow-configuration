# OCR-D workflow configuration installation makefile
#
# Install workflow configurations persistently by running:
# `make install` or `pip install .` (in the git repo),
# which will copy all distribution files (`Makefile` and all
# preconfigured makefiles `*.mk`, as well as some Python
# scripts and XSL transforms `*.xsl`) into the Python
# site directory.
# Using venv is recommended.

PYTHON = python3
PIP = pip3
PYTHONIOENCODING=utf8

SHELL = bash -o pipefail

DOCKER_BASE_IMAGE ?= docker.io/ocrd/core:latest
DOCKER_TAG ?= ocrd/workflow-configuration
DOCKER ?= docker

help:
	@echo "Installing OCR-D workflow configurations:"
	@echo
	@echo "  Usage:"
	@echo "  make [OPTIONS] TARGET"
	@echo
	@echo "  Targets:"
	@echo "  * help        (this message)"
	@echo "  * deps-ubuntu (install system packages needed here, beyond ocrd and processors)"
	@echo "  * deps        (install Python packages needed here)"
	@echo "  * install     (install this package via $(PIP)"
	@echo "    build       (build source and binary distribution)"
	@echo "  * uninstall   (remove this package via $(PIP)"
	@echo "  * %.mk        (any filename with suffix .mk not existing yet: spawn new makefile from pattern)"
	@echo "  * test        (run test suite)"
	@echo
	@echo "  Variables:"
	@echo
	@echo "  * PYTHON      (name of Python version binary [$(PYTHON)])"
	@echo "  * PIP         (name of Python pip version binary [$(PIP)])"

.PHONY: help

deps-ubuntu:
	apt-get update
	apt-get -y install parallel xmlstarlet bc sed libdbd-sqlite3-perl

deps: requirements.txt
	$(PIP) install -r $<

install:
	$(PIP) install .

install-dev:
	$(PIP) install -e .

build:
	$(PIP) install build
	$(PYTHON) -m build .

uninstall:
	$(PIP) uninstall workflow_configuration

TEST_WORKFLOW = -f all-tess-MODEL.mk MODEL=german_print \
                -f transform.mk TROPTIONS="-P xsl page-extract-text.xsl \
                  -P xslt-params '-s level=line' -P mimetype text/plain" \
                -f cat-files.mk
define testrecipe =
function testfun { pushd `mktemp -d` && cp -pr $(abspath $^) . && /usr/bin/time ocrd-make $(TEST_WORKFLOW) LOGLEVEL=ERROR $(^F) "$$@" && cat $(^F:%=%.*.log) && $(RM) -r $$DIRSTACK; }; testfun
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

docker:
	$(DOCKER) build \
	-t $(DOCKER_TAG) \
	--build-arg DOCKER_BASE_IMAGE=$(DOCKER_BASE_IMAGE) \
	--build-arg VCS_REF=$(git rev-parse --short HEAD) \
	--build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
	.

.PHONY: deps-ubuntu deps install install-dev build uninstall test docker

# spawn a new configuration
define skeleton =
# This file can run a workflow on a single workspace (non-recursively).
#
# Install by copying (or symlinking) makefiles into a directory
# where all OCR-D workspaces (unpacked BagIts) reside and running
# `ocrd-make` there (or including files from there).
#
# Call via:
# `ocrd-make -f WORKFLOW-CONFIG.mk`
#
# To rebuild partially, you must pass -W to `make`:
# `ocrd-make -f WORKFLOW-CONFIG.mk -W FILEGRP`
#
# To build in parallel, use `-j [CPUS] [-l [LOADLEVEL]]` etc.
#
# To get general help:
# `ocrd-make --help`
#
# To get a description of the workflow:
# `ocrd-make -f WORKFLOW-CONFIG.mk info`

INPUT = OCR-D-IMG

$$(INPUT):
	ocrd workspace find -G $$@ --download

OUTPUT = OCR-D-OUT
$$(OUTPUT): $$(INPUT)
$$(OUTPUT): TOOL = ocrd-dummy
$$(OUTPUT): OPTIONS =

info:
	@echo "This is a dummy configuration that creates a copy $$(OUTPUT) of the input fileGrp $$(INPUT)"

.PHONY: info

.DEFAULT_GOAL = $$(OUTPUT)

endef

export skeleton

%.mk:
	@echo >$@ "$$skeleton"


# do not search for implicit rules here:
%/Makefile: ;
Makefile: ;
ocrd-tool.json: ;
local.mk: ;
