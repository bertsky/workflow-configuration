## OCR-D workflow configurations based on makefiles

This provides a first attempt at running [OCR-D](https://ocr-d.github.io) workflows configured and controlled via GNU makefiles. Makefilization offers the following _advantages_:

- incremental builds (steps already processed for another configuration or in a failed run need not be repeated) and automatic dependencies (new files will force all their dependents to update)
- persistency of configuration and results
- encapsulation and ease of use
- sharing configurations and repeating experiments
- less writing effort, fast templating
- parallelization across workspaces

Nevertheless, there are also some _disadvantages_:

- depends on directories (fileGrps) as targets, which is hard to get correct under all circumstances
- must mediate between filesystem perspective (understood by `make`) and METS perspective
- `make` **cannot** handle _target names with spaces_ in them ([at all](https://savannah.gnu.org/bugs/?712))  
  (This means that fileGrp directories must not have spaces.
   Local file paths may contain spaces though, if the respective processors support that.)

Contents:
 * [Dependencies](#dependencies)
 * [Installation](#installation)
    * [For direct invocation of make](#for-direct-invocation-of-make)
    * [For invocation via shell script](#for-invocation-via-shell-script)
 * [Usage](#usage)
 * [Customisation](#customisation)
    * [Recommendations](#recommendations)
    * [Example](#example)
 * [Results](#results)
    * [OCR-D ground truth](#ocr-d-ground-truth)
 * [Implementation](#implementation)
    * [GPU vs CPU parallelism](#gpu-vs-cpu-parallelism)
    * [workspace vs page parallelism](#workspace-vs-page-parallelism)

### Dependencies

To install system dependencies for this package, run...

    make deps-ubuntu


...in a privileged context for Ubuntu (like a Docker container).

Or equivalently, install the following packages:
- `parallel` (GNU parallel)
- `xmlstarlet`
- `bc` and `sed`

Additionally, you must of course install [ocrd](https://github.com/OCR-D/core) itself along with its dependencies in the current shell environment. Moreover, depending on the specific configurations you want to use (i.e. the processors it contains), additional modules must be installed. See [OCR-D setup guide](https://ocr-d.github.io/docs/setup) for instructions. (Yes, `workflow-configuration` is already part of [ocrd_all](https://github.com/OCR-D/ocrd_all).)


### Installation

You have 2 options, depending on your usage preferences:

#### For direct invocation of make

Simply copy or symlink all makefiles (i.e. both the specific workflow configurations `*.mk` and the general `Makefile`) to the __target directory__.

(The target directory is the directory where your OCR workspace directories can be found. A workspace directory is one which contains a `data/mets.xml` or `mets.xml`.)

You can then run workflows in the target directory by calling...

    make [OPTIONS] -f WORKFLOW-CONFIG.mk WORKSPACES...


...where
- _OPTIONS_ are the usual options controlling GNU make (e.g. `-j` for parallel processing).
- _WORKFLOW_CONFIG.mk_ is one of the configuration makefiles you find here.
- _WORKSPACES_ is a list of workspace directories, or `all` (the default) for all workspaces make can find.

#### For invocation via shell script

Run...

    make install


... if you are in a (Python) virtual environment. Otherwise specify the installation prefix directory via environment variable `VIRTUAL_ENV`.

Assuming `$VIRTUAL_ENV/bin` is in your `PATH`, you can now call...

    ocrd-make [OPTIONS] -f WORKFLOW-CONFIG.mk WORKSPACES...


... in the target directory with the same interface as above (only without the need for copying makefiles).


### Usage

Workflows are processed like _software builds_: File groups (depending on one another) are the targets to be built in each workspace, and all workspaces are built recursively. A build is finished when all targets exist and none are older than their respective prerequisites (e.g. image files).

To run a configuration...
1. Activate working environment (virtualenv) and change to the target directory.
2. Choose (or create) a workflow configuration makefile.  
   (Yes, you can have to look inside and browse its rules!)
3. Execute: 

        [ocrd-]make -f CONFIGURATION.mk [all]

(The special target `all` (which is also the default goal) will look for all workspaces in the current directory.)

You can also run on a subset of workspaces by passing these as goals on the command line...

    [ocrd-]make -f CONFIGURATION.mk PATH/TO/WORKSPACE1 PATH/TO/WORKSPACE2 ...


To get help:

    [ocrd-]make help


To get a short description of the chosen configuration:

    [ocrd-]make -f CONFIGURATION.mk info


To see the command sequence that would be executed for the chosen configuration (in the format of `ocrd process`):

    [ocrd-]make -f CONFIGURATION.mk show


To remove the configuration makefiles in the current/target directory:

    [ocrd-]make clean


To prepare workspaces for processing by fixing certain flaws that kept happening during publication:

    [ocrd-]make repair


To create workspaces from directories which contain image files:

    ocrd-import DIRECTORY


To get help for the import tool:

    ocrd-import --help


To derive flat directories from workspaces suitable for LAREX annotation:

    ocrd-export-larex -I FILEGRP -O DIR


To get help for the LAREX export tool:

    ocrd-export-larex --help


To spawn a new configuration file:

    [ocrd-]make NEW-CONFIGURATION.mk


Furthermore, you can add any options that `make` understands (see `make --help` or `info make 'Options Summary'`). For example,
- `-n` or `--dry-run` to just simulate the run
- `-q` or `--question` to just check whether anything needs to be built at all
- `-s` or `--silent` to suppress echoing recipes
- `-j` or `--jobs` to run on workspaces in parallel
- `-B` or `--always-make` to consider all targets out-of-date (i.e. unconditionally rebuild)

Note, that because workspaces are built by recursive invocation, and `make` does not pass on those `MAKEFLAGS` which can affect dependency calculation, you cannot _directly_ use the following options:
- `-o` or `--old-file` to consider some target up-to-date w.r.t. its prerequisites (i.e. unconditionally keep) but older than its dependents (i.e. unconditionally ignore)
- `-W` or `--new-file` to consider some target newer than its dependents (i.e. unconditionally update them)

However, you can wrap them in a special variable __`EXTRA_MAKEFLAGS`__ which gets expanded at the workspace level. For example, to rebuild anything _after_ the fileGrp `OCR-D-BIN`, do:

    [ocrd-]make -f CONFIGURATION.mk all EXTRA_MAKEFLAGS="-W OCR-D-BIN"

You can also use that variable to specify any other than the `.DEFAULT_GOAL` of your configuration as the overall target. For example, to build anything _up to_ the fileGrp `OCR-D-SEG-LINE`, do:

    [ocrd-]make -f CONFIGURATION.mk all EXTRA_MAKEFLAGS="OCR-D-SEG-LINE"

(If you chdir into some workspace yourself, `make` won't run recursively, so no `all` target exists and no `EXTRA_MAKEFLAGS` is necessary.)

There are 2 more special variables besides `EXTRA_MAKEFLAGS`. To process only a subset of pages in all fileGrps, use `PAGES`. For example, to only consider pages `PHYS_0005` and `PHYS_0007`, do:

    [ocrd-]make -f CONFIGURATION.mk all PAGES=PHYS_0005,PHYS_0007

And to override the default (or configured) log levels for all processors and libraries, use `LOGLEVEL`. For example, to get debugging everywhere, do:

    [ocrd-]make -f CONFIGURATION.mk all LOGLEVEL=DEBUG


### Customisation

To write new configurations, first choose a (sufficiently descriptive) makefile name, and spawn a new file for that: `[ocrd-]make NEW-CONFIGURATION.mk` (or copy from an existing configuration).

Next, edit the file to your needs: Write rules using file groups as prerequisites/targets in the normal GNU make syntax. The first target defined must be the default goal that builds the very last file group for that configuration, or else a variable `.DEFAULT_GOAL` pointing to that target must be set anywhere in the makefile.

#### Recommendations

- Keep the comments and the `include Makefile` directive in the file.
- Change/customize at least the `info` target, and the `INPUT` and `OUTPUT` name/rule.
- Copy/paste rules from the existing configurations.
- Define variables with the names of all target/prerequisite file groups, so rules and dependent targets can re-use them (and the names can be easily changed later).
- Try to utilise the provided static pattern rule (which takes the target as output file group and the prerequisite as input file group) for all processing steps. The rule covers any OCR-D compliant processor with no more than 1 output file group. Use it by simply defining the target-specific variable `TOOL` (and optionally `PARAMS` or `OPTIONS`) and giving no recipe whatsoever.
- When any of your processors use GPU resources, you must prevent races for GPU memory during parallel execution.
  
  You can achieve this by simply setting `GPU = 1` for that target when using the static pattern rule, or by using `sem --id OCR-D-GPUSEM` when writing your own recipes.
  
  Alternatively, you can either prevent using GPUs globally by (un)setting `CUDA_VISIBLE_DEVICES=`, or prevent running parallel jobs (on multiple CPUs) by passing `-j`.

#### Example

```make
INPUT = OCR-D-GT-SEG-LINE

$(INPUT):
	ocrd workspace find -G $@ --download
	ocrd workspace find -G OCR-D-IMG --download # just in case

# You can use variables for file group names to keep the rules brief:
BIN = $(INPUT)-BINPAGE

# This is how you use the pattern rule from Makefile (included below):
# The prerequisite will become the input file group,
# the target will become the output file group,
# the recipe will call the executable given by TOOL,
# also generating a JSON parameter file from PARAMS:
$(BIN): $(INPUT)
$(BIN): TOOL = ocrd-olena-binarize
$(BIN): PARAMS = "impl": "sauvola-ms-split"
# or equivalently:
$(BIN): OPTIONS = -P impl sauvola-ms-split

# You can also use the file group names directly:
OCR-D-OCR-TESS: $(BIN)
OCR-D-OCR-TESS: TOOL = ocrd-tesserocr-recognize
OCR-D-OCR-TESS: PARAMS = "textequiv_level": "glyph", "model": "frk+deu"
# or equivalently:
OCR-D-OCR-TESS: OPTIONS = -P textequiv_level glyph -P model frk+deu

# This uses more than 1 input file group and no output file group,
# which works with the standard recipe as well (but mind the ordering):
EVAL: $(INPUT) OCR-D-OCR-TESS
EVAL: TOOL = ocrd-cor-asv-ann-evaluate

# Because the first target in this file was $(BIN),
# we must override the default goal to be our desired overall target:
.DEFAULT_GOAL = EVAL

# ALWAYS necessary:
include Makefile
```

### Results

#### OCR-D ground truth

For the `data_structure_text/dta` repository, which includes both layout and text annotation down to the textline level, but very coarse segmentation, the following _character error rate_ (CER) was measured:

| *pipeline configuration* | *CER* |
| ---------- | ----- |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .243 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.241** |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .255 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .252 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .263 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .248 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .262 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .273 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .266 |
| | |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .290 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.287** |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .301 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .296 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .317 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .292 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .314 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .325 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .318 |
| | |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .114 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.113** |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP| .127 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .121 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .122 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .118 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .122 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .124 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .123 |
| | |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .117 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.116** |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP| .131 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .121 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .126 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .122 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .124 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .128 |
| OCR-D-OCR-TESS-Fraktur+Latin-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .126 |
| | |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .110 |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.109** |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .126 |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .119 |
| OCR-D-OCR-TESS-frk-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .118 |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP| .115 |
| OCR-D-OCR-TESS-frk-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .116 |
| OCR-D-OCR-TESS-frk-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .120 |
| OCR-D-OCR-TESS-frk-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .119 |
| | |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .106 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.106** |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .122 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .114 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .113 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .111 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .112 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .117 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .115 |
| | |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-CLIP-RESEG-DEWARP | **.078** |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | .081 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .094 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .085 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .089 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP| .084 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .090 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .091 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .094 |
| | |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-CLIP-RESEG-DEWARP | .081 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-DESKEW-ocropy-CLIP-RESEG-DEWARP | **.074** |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .087 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-CLIP-RESEG-DEWARP | .084 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-CLIP-RESEG-DEWARP | .085 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP| .086 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .109 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-sauvola-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .090 |
| OCR-D-OCR-CALA-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .110 |

Hence, it appears that consistently (across different OCRs) ...
- denoising with Ocropy (with `noise_maxsize=3.0`) does _not_ help
- deskewing with Ocropy on the page level usually helps
- additional deskewing and flipping with Tesseract on the region level usually deteriorates
- binarization with `sauvola-ms-split` is better than `wolf`

However, this result is still _preliminary_. Both the processor implementations evolve and the GT annotations get fixed over time.

### Implementation

To make writing (and reading) configurations as simple as possible, they are expressed as rules operating on METS file groups (i.e. workspace-local). For convenience, the most common recipe pattern involving only 1 input and 1 output file group via some OCR-D CLI is available via static pattern rule, which merely takes the target-specific variables `TOOL` (the CLI executable) and optionally `PARAMS` (a JSON-formatted list of parameter assignments) or `OPTIONS` (a white-space separated list of parameter assignments). Custom rules are possible as well. If the makefile does not start with the overall target, it must specify its `.DEFAULT_GOAL`, so callers can run without knowledge of the target names.

Rules that are not configuration-specific (like the static pattern rule) are all shared by including a common `Makefile` at the end of configuration makefiles. That file has 2 sets of rules:
- a top-level set operating in the target directory (possibly in parallel),
  targets are the available workspaces, and the global default goal `all`,
- a low-level set operating in the workspace directory (always sequentially),
  targets are the configured file groups, including the local default goal.

The former calls the latter recursively for each workspace.

#### GPU vs CPU parallelism

When executing workflows in parallel across workspaces (with `--jobs`) on multiple CPUs, it must be ensured that not too many OCR-D processors which use GPU resources are running concurrently (to prevent over-allocation of GPU memory). Thus, make needs to know:
1. which processors (have/want to) use GPU resources, and
2. how many such processors can run in parallel.

It can then synchronize these processors with a semaphore. This is achieved by expanding the static pattern rule with a synchronisation mechanism (based on GNU parallel). Workflow configurations can use that by setting the target-specific variable `GPU` to a non-empty value for the respective rules. (Custom recipes will have to use `sem --id OCR-D-GPUSEM`.)

That way, races are prevented, but also GPUs cannot become the bottleneck: When all GPUs are busy, processors will fall back to CPU.

#### workspace vs page parallelism

When executing workflows in parallel across workspaces (with `--jobs`) on multiple CPUs, it must be ensured that OCR-D processors do not use local multiprocessing facilities themselves (to prevent over-allocation of CPUs).

In the current state of affairs, OCR-D processors cannot be run in parallel across pages via multiprocessing. (At least, they are never implemented that way.) That may change in the future with a [new OCR-D API](https://github.com/OCR-D/core/issues/322). But still, many processors do already use libraries like OpenMP or OpenBLAS which use multiprocessing locally within pages. This can be controlled via _environment variables_ like `OMP_THREAD_LIMIT`.

This is achieved by exporting these variables to all recipes with a value of `1` when `-j` is in `MAKEFLAGS` or half the number of physical CPUs (unless `NTHREADS` is explicitly given) otherwise.
