[![CircleCI](https://dl.circleci.com/status-badge/img/gh/bertsky/workflow-configuration/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/bertsky/workflow-configuration/tree/master)

## OCR-D workflow configurations based on makefiles

This provides an attempt at running [OCR-D](https://ocr-d.de) workflows
configured and controlled via makefiles using [GNU bash](http://www.gnu.org/software/bash),
[GNU make](http://www.gnu.org/software/make/) and [GNU parallel](http://www.gnu.org/software/parallel).

Makefilization offers the following _advantages_:

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
 * [Docker Image](#docker-image)
 * [Usage](#usage)
    * [ocrd-import](#ocrd-import)
    * [PAGE transformations and ocrd-page-transform](#ocrd-page-transform)
    * [METS transformations](#mets-transformations)
    * [ocrd-make](#ocrd-make)
      * [LOGLEVEL](#loglevel)
      * [PAGES](#pages)
      * [TIMEOUT](#timeout)
      * [FAILRETRY](#failretry)
      * [FAILDUMMY](#faildummy)
      * [METSSERV](#metsserv)
      * [PAGEWISE](#pagewise)
      * [JOBDB](#jobdb)
      * [Remote distribution](#remote-distribution)
 * [Customisation](#customisation)
    * [Recommendations](#recommendations)
    * [Example](#example)
 * [Testing](#testing)
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
- `parallel` ([GNU parallel](http://www.gnu.org/software/parallel))
- `make` ([GNU make](http://www.gnu.org/software/make))
- `xmlstarlet`
- `bc` and `sed`

Additionally, you must of course install [ocrd](https://github.com/OCR-D/core) itself
along with its dependencies in the current Python virtual environment (venv). Moreover,
depending on the specific configurations you want to use (i.e. the processors it contains),
additional modules must be installed. See [OCR-D setup guide](https://ocr-d.de/en/setup)
for instructions.

(Yes, `workflow-configuration` is already part of [ocrd_all](https://github.com/OCR-D/ocrd_all),
which is also available on [Dockerhub](https://hub.docker.com/r/ocrd/all).)


### Installation

Run:

    make install

... if you are in a (Python) virtual environment, which is recommended.

You can then call:

    ocrd-make [OPTIONS] -f WORKFLOW-CONFIG.mk WORKSPACE...

... for processing any number of workspace directories.

Where:

- _`OPTIONS`_ are the usual options controlling GNU make (e.g. `-j` for parallel processing).
- _`WORKFLOW_CONFIG.mk`_ is one of the configuration makefiles you find here or created yourself.
- _`WORKSPACE`_ is a directory with a `mets.xml`, or `all` (the default) for all such directories that we can `find`.

Calling workflows is possible from anywhere in your filesystem, but for the `WORKFLOW_CONFIG.mk` you may need to:

- either provide the `*.mk` configurations in the source directory at installation time
  (to ensure they are installed under the site prefix and can always be found by file name)
- or provide full paths at runtime (by absolute path name, or relative to the CWD).

(The previous version of `ocrd-make` tried to copy or symlink all makefiles to the runtime directory.
 You can still use those, but should remove the old `Makefile`.)

### Docker Image

Instead of the above native installation steps, you can use the prebuilt image from Docker Hub:

    docker pull bertsky/workflow-configuration
    docker run -V /path/to/data:/data bertsky/workflow-configuration ocrd-make ...

For general guidance on using Docker with OCR-D, see
[User Guide](https://ocr-d.de/en/user_guide#translating-native-commands-to-docker-calls).

### Usage

#### ocrd-import

To create workspaces from directories which contain image files:

    ocrd-import DIRECTORY


To get help for the import tool:

    ocrd-import --help

<details><summary>standalone CLI</summary>


<pre>
Usage: ocrd-import [OPTIONS] WORKSPACE_DIR

  Create OCR-D workspace meta-data (mets.xml) in WORKSPACE_DIR (or $PWD), importing...
  * all image files (with known file extension or convertible via ImageMagick) under fileGrp `image_group`
  * all .xml files (if they validate as PAGE-XML) under fileGrp `pagexml_group`
  * all .xml files (if they validate as ALTO-XML) under fileGrp `altoxml_group`
  ...but failing otherwise (unless `ignore` is set)

Options:
  -l, --log-level [OFF|ERROR|WARN|INFO|DEBUG|TRACE]
                                  Log level
  -i, --ignore                    keep going after unknown file types
  -s, --skip SUFFIX               ignore file names ending in given SUFFIX
                                  (repeatable)
  -R, --regex EXPR                only include paths matching given EXPR
                                  (repeatable)
  -C, --no-convert                do not attempt to convert image file types
  -r, --render DPI                when converting PDFs, render at DPI pixel
                                  density  [default: 300]
  -P, --nonnum-ids                do not use numeric pageIds but basename
                                  patterns
  -B, --basename                  only use basename for IDs
  -n, --dry-run                   only show resulting METS to stdout via pager
  -I, --image-group TEXT          fileGrp to place detected or converted
                                  images into  [default: OCR-D-IMG]
  -X, --pagexml-group TEXT        fileGrp to place detected PAGE-XML into
                                  [default: OCR-D-PAGE]
  -A, --altoxml-group TEXT        fileGrp to place detected ALTO-XML into
                                  [default: OCR-D-ALTO]
  -G, --directory-groups          instead of assigning files to `image_group`
                                  or `pagexml_group`, and trying to convert
                                  everything else to images, create a group
                                  for every subdirectory and auto-detect its
                                  MIME types
  -h, --help                      Show this message and exit.
</pre>

</details>

#### ocrd-page-transform

To perform various tasks via XSLT on PAGE-XML files (these all share the same options, including `--help`):

    page-add-nsprefix-pc # adds namespace prefix 'pc:'
    page-rm-nsprefix-pc # removes namespace prefix 'pc:'
    page-set-nsversion-2019 # update the PAGE namespace schema version to 2019
    page-fix-coords # replace negative values in coordinates by zero
    page-flatten-tableregions # move recursive TableRegion cells to top level for editing in LAREX
    page-unflatten-tableregions # move flattened TableRegion cells back to hierarchy after editing in LAREX
    page-move-alternativeimage-below-page # try to push page-level AlternativeImage back to subsegments
    page-remove-alternativeimages # remove $which [last] AlternativeImage entries at hierarchy $level [page]
    page-remove-metadataitem # remove all MetadataItem entries
    page-remove-dead-regionrefs # remove non-existing regionRefs
    page-remove-empty-readingorder # remove empty ReadingOrder or groups
    page-remove-empty-text-regions # remove empty TextRegion entries
    page-remove-empty-lines # remove empty TextLine entries
    page-remove-all-regions # remove all *Region (and TextLine and Word and Glyph) entries
    page-remove-text-regions # remove all TextRegion (and TextLine and Word and Glyph) entries
    page-remove-regions # remove all *Region (and TextLine and Word and Glyph) entries of $type
    page-remove-lines # remove all TextLine (and Word and Glyph) entries
    page-remove-words # remove all Word (and Glyph) entries
    page-remove-glyphs # remove all Glyph entries
    page-remove-textequiv # remove all TextEquiv entries for selected levels and @index
    page-rename-id-clashes # reassign new @id of segments that clash with other existing @id
    page-ensure-readingorder # generate ReadingOrder hierarchy from recursive document order if empty
    page-ensure-textequiv-conf # set TextEquiv/@conf attributes if missing
    page-ensure-textequiv-index # set TextEquiv/@index attributes from element order
    page-ensure-textequiv-unicode # create empty TextEquiv/Unicode elements if empty
    page-sort-textequiv-index # sort TextEquiv by @index
    page-textequiv-lines-to-regions # project text from TextLines to TextRegions (concat with LF in between)
    page-textequiv-words-to-lines # project text from Words to TextLines (concat with spaces in between)
    page-extract-text # extract TextEquiv/Unicode from TextRegion|TextLine|Word|Glyph $level [highest] consecutively, in $order [reading-order], interspersed by $pb and $lb
    page-extract-lines # extract TextEquiv/Unicode from TextLine consecutively, in $order [reading-order]
    page-extract-words # extract TextEquiv/Unicode from Word consecutively
    page-extract-glyphs # extract TextEquiv/Unicode from Glyph consecutively


<details><summary>standalone CLI</summary>


<pre>
Usage: NAME [OPTIONS] [FILE]

  Open PAGE file XMLFILE (or stdin) and apply the XSL transformation "page-add-nsprefix-pc.xsl"
  Write the result to stdout, unless...
  -i / --inplace is given - in which case the result is written back to the
                            file silently, or
  -d / --diff is given    - in which case the result will be compared to the
                            input and a patch shown on stdout.

Options:
  -l, --log-level [OFF|ERROR|WARN|INFO|DEBUG|TRACE]
                                  Log level
  -s, --string-param NAME=VALUE   set param NAME to string literal VALUE
  -p, --xpath-param NAME=VALUE    set param NAME to XPath expression VALUE
  -i, --inplace                   overwrite input file with result of
                                  transformation
  -P, --pretty                    pretty-print output (line breaks with
                                  indentation
  -d, --diff                      show diff between input and output via pager
  -D, --dump                      just print the transformation stylesheet
                                  (XSL)
  -h, --help                      Show this message and exit.
</pre>


</details>

To perform the same transformations, but as a [workspace processor](https://ocr-d.de/en/spec/cli),
use `ocrd-page-transform` and pass the filename of the transformation as parameter, e.g.:

    ocrd-page-transform -P xsl page-extract-lines.xsl -P xslt-params "-s order=reading-order"
    ocrd-page-transform -P xsl page-remove-alternativeimages.xsl -P xslt-params "-s level=line -s which=dewarped"
    cat <<'EOF' > my-transform.xsl
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
      <xsl:output method="xml" standalone="yes" encoding="UTF-8" omit-xml-declaration="no"/>
      <xsl:template match="//pc:Word"/>
      <xsl:template match="node()|text()|@*">
        <xsl:copy>
          <xsl:apply-templates select="node()|text()|@*"/>
        </xsl:copy>
      </xsl:template>
    </xsl:stylesheet>
    EOF
    ocrd-page-transform -P xsl my-transform.xsl


<details><summary>OCR-D CLI</summary>


<pre>
Usage: ocrd-page-transform [worker|server] [OPTIONS]

  apply arbitrary XSL transformation file for PAGE-XML

  > Transform pages with the given XSLT.

  > Open the input PAGE element hierarchy and process it with the XSLT
  > processor parsed from the `xsl` resource file, passing `xslt-params`
  > as XSLT parameters (if any).

  > Generate a new PAGE object from the resulting hierarchy, finally
  > serialise and add it as new output file.

Subcommands:
    worker      Start a processing worker rather than do local processing
    server      Start a processor server rather than do local processing

Options for processing:
  -m, --mets URL-PATH             URL or file path of METS to process [./mets.xml]
  -w, --working-dir PATH          Working directory of local workspace [dirname(URL-PATH)]
  -I, --input-file-grp USE        File group(s) used as input
  -O, --output-file-grp USE       File group(s) used as output
  -g, --page-id ID                Physical page ID(s) to process instead of full document []
  --overwrite                     Remove existing output pages/images
                                  (with "--page-id", remove only those).
                                  Short-hand for OCRD_EXISTING_OUTPUT=OVERWRITE
  --debug                         Abort on any errors with full stack trace.
                                  Short-hand for OCRD_MISSING_OUTPUT=ABORT
  --profile                       Enable profiling
  --profile-file PROF-PATH        Write cProfile stats to PROF-PATH. Implies "--profile"
  -p, --parameter JSON-PATH       Parameters, either verbatim JSON string
                                  or JSON file path
  -P, --param-override KEY VAL    Override a single JSON object key-value pair,
                                  taking precedence over --parameter
  -U, --mets-server-url URL       URL of a METS Server for parallel incremental access to METS
                                  If URL starts with http:// start an HTTP server there,
                                  otherwise URL is a path to an on-demand-created unix socket
  -l, --log-level [OFF|ERROR|WARN|INFO|DEBUG|TRACE]
                                  Override log level globally [INFO]
  --log-filename LOG-PATH         File to redirect stderr logging to (overriding ocrd_logging.conf).

Options for information:
  -C, --show-resource RESNAME     Dump the content of processor resource RESNAME
  -L, --list-resources            List names of processor resources
  -J, --dump-json                 Dump tool description as JSON
  -D, --dump-module-dir           Show the 'module' resource location path for this processor
  -h, --help                      Show this message
  -V, --version                   Show version

Parameters:
   "xsl" [string - REQUIRED]
    File path of the XSL transformation script (see `ocrd resmgr` for
    prepackaged and user-installed files available by file name)
   "xslt-params" [string - ""]
    Assignment of XSL transformation parameter values, given as in
    `xmlstarlet` (which differentiates between `-s name=value` for
    literal `value` and `-p name=value` for XPath expression `value`),
    white-space separated.
   "pretty-print" [number - 0]
    Reformat with line breaks and this many spaces of indentation after
    XSL transformation (unless zero).
   "mimetype" [string - "application/vnd.prima.page+xml"]
    MIME type to register the output files under (should correspond to
    `xsl` result)

</pre>


</details>

#### METS transformations

Besides the transformations for PAGE-XML above, which are wrapped both as OCR-D CLI `ocrd-page-transform`
and standlone CLIs `page-...`, this module installs some XSL transformations for METS-XML, which are
likewise wrapped as standalone CLIs `mets-...`:

    mets-add-nsprefix-mets # add namespace prefix mets:
    mets-alias-filegrp # zero-cost copy of fileGrp $input [FULLTEXT] as fileGrp $output [ALTO]
    mets-copy-agents # copy all metsHdr/agent from $other-mets [mets.xml]

<details><summary>standalone CLI</summary>


<pre>
Usage: NAME [OPTIONS] [FILE]

  Open METS file XMLFILE (or stdin) and apply the XSL transformation "mets-copy-agents.xsl"
  Write the result to stdout, unless...
  -i / --inplace is given - in which case the result is written back to the
                            file silently, or
  -d / --diff is given    - in which case the result will be compared to the
                            input and a patch shown on stdout.

Options:
  -l, --log-level [OFF|ERROR|WARN|INFO|DEBUG|TRACE]
                                  Log level
  -s, --string-param NAME=VALUE   set param NAME to string literal VALUE
  -p, --xpath-param NAME=VALUE    set param NAME to XPath expression VALUE
  -i, --inplace                   overwrite input file with result of
                                  transformation
  -P, --pretty                    pretty-print output (line breaks with
                                  indentation
  -d, --diff                      show diff between input and output via pager
  -D, --dump                      just print the transformation stylesheet
                                  (XSL)
  -h, --help                      Show this message and exit.
</pre>


</details>

#### ocrd-make

Workflows are processed like _software builds_: File groups (depending on one another) are the targets to be built in each workspace, and all workspaces are built recursively. A build is finished when all targets exist and none are older than their respective prerequisites (e.g. image files).

To run a configuration...
1. Activate working environment (virtualenv) and change to the target directory.
2. Choose (or create) a workflow configuration makefile.  
   (Yes, you can have to look inside and browse its rules!)
3. Execute:

        ocrd-make [OPTIONS] -f WORKFLOW-CONFIG.mk all

    (The special target `all` (which is also the default goal) will search for all workspaces
    in the current directory recursively.) You can also run on a subset of workspaces
    by passing these as goals on the command line...

        ocrd-make -f WORKFLOW-CONFIG.mk PATH/TO/WORKSPACE1 PATH/TO/WORKSPACE2 ...

<details><summary>Full CLI summary</summary>

 <pre>
Running OCR-D workflow configurations on multiple workspaces:

  Usage:
  ocrd-make [OPTIONS] [-f CONFIGURATION] [TARGETS] [VARIABLE-ASSIGNMENTS]

  Options (ocrd-specific):
  -X|--transfer HOST:DIR  run workflow on remote HOST in remote DIR
  --remote-init CMD  run CMD before the workflow on remote host

  Options (make-specific):
  -j|--jobs [N]   number of jobs to run simultaneously
  -l|--load-average|--max-load N  system load limit for -j without N
  -I|--include-dir DIR  extra search directory for included makefiles
  -C|--directory DIR  change to directory before reading makefiles

  Targets (general):
  * help (this message)
  * info (short self-description of the selected configuration)
  * show (print command sequence that would be executed for the selected configuration)
  * server (start workflow server for the selected configuration; control via 'ocrd workflow client')

  Targets (data processing):
  * all (recursively find all directories with a mets.xml, default goal)
  * % (name of the workspace directory, overriding the default goal)

  Variables:
  * LOGLEVEL: override global loglevel for all OCR-D processors
    (if unset, then default/configured logging levels apply)
  * PAGES: override page selection (comma-separated list)
    (if unset, then all pages will be processed)
  * TIMEOUT: per-processor timeout (in seconds or with unit suffix)
    (if unset, then processors may run forever)
  * FAILRETRY: per-processor number of attempts on processing errors
    (if unset, then the first attempt exits, passing the error on)
  * FAILDUMMY: use ocrd-dummy (just copy -I to -O grp) on processing errors
    (if unset, then failed processors terminate the workflow)
  * METSSERV   start/use/stop METS Servers before/during/after workflows
    (if unset, the METS file will have to be de/serialised between each call)
  * PAGEWISE   call processors separately per page during workflows
    (if unset, processors are called on the whole document)

(This will merely delegate to `make` on the given working directories
from the installation directory "/data/ocr-d/ocrd_all/venv38/share/workflow-configuration".
All options except -C and -I are allowed and passed through.
Options -j and -l are intercepted.)
 </pre>

 </details>

To get help:

    ocrd-make help


To get a short description of the chosen configuration:

    ocrd-make -f CONFIGURATION.mk info


To see the command sequence that would be executed for the chosen configuration (in the format of `ocrd process`):

    ocrd-make -f CONFIGURATION.mk show


To run a workflow server for the command sequence that would be executed for the chosen configuration (to be controlled via `ocrd workflow client` or HTTP):

    ocrd-make -f CONFIGURATION.mk server

To spawn a new configuration file, in the directory of the source repository, do:

    ocrd-make NEW-CONFIGURATION.mk


Furthermore, you can add any options that `make` understands (see `make --help` or `info make 'Options Summary'`). For example,
- `-n` or `--dry-run` to just simulate the run
- `-q` or `--question` to just check whether anything needs to be built at all
- `-s` or `--silent` to suppress echoing recipes
- `-j` or `--jobs` to run on workspaces in parallel
- `-l` or `--max-load` to set the maximum load level in parallel mode
- `-B` or `--always-make` to consider all targets out-of-date (i.e. unconditionally rebuild)
- `-o` or `--old-file` to consider some target up-to-date w.r.t. its prerequisites (i.e. unconditionally keep) but older than its dependents (i.e. unconditionally ignore)
- `-W` or `--new-file` to consider some target newer than its dependents (i.e. unconditionally update them)

For example, to rebuild anything _after_ the fileGrp `OCR-D-BIN`, do:

    ocrd-make -f CONFIGURATION.mk -W OCR-D-BIN all

You can also use that pattern to specify any fileGrp other than the `.DEFAULT_GOAL` of your configuration as the overall target. For example, to build anything _up to_ the fileGrp `OCR-D-SEG-LINE`, do:

    ocrd-make -f CONFIGURATION.mk .DEFAULT_GOAL=OCR-D-SEG-LINE all

There are 6 **special variables** and 1 **additional option**:

##### LOGLEVEL

To override the default (or configured) log levels for all processors and libraries, use `LOGLEVEL`. For example, to get debugging everywhere, do:

    ocrd-make -f CONFIGURATION.mk all LOGLEVEL=DEBUG

##### PAGES

To process only a subset of pages in all fileGrps, set `PAGES`. For example, to only consider pages `PHYS_0005` through `PHYS_0007`, do:

    ocrd-make -f CONFIGURATION.mk all PAGES=PHYS_0005..PHYS_0007

The variable gets interpreted as the usual [--page-id parameter](https://ocr-d.de/en/spec/cli#-g---page-id-id) by processors, so it supports
range expressions, comma-separated lists and regular expressions. 

If the METS provides physical page labels (`@ORDER` or `@ORDERLABEL`), then these work as well:

    ocrd-make -f CONFIGURATION.mk all PAGES=5..7

##### TIMEOUT

To set an upper limit on the time each processor may take to run, use `TIMEOUT`.
Set a numeric value in seconds, or post-fix with a temporal unit, as in `timeout(1)`.

Beware that useful values may vary widely, depending on the processor and parameters
(esp. whether GPUs are used), the input image size, and any `PAGES` setting.

In the case of `PAGEWISE=1`, this applies to single-page calls.

If `FAILRETRY>0`, then repeated attempts will each contribute to one overall timeout.

If `FAILDUMMY=1`, then timed out calls (as with any other cause of failure)
will be caught be `ocrd-dummy`, which may take up additional time.

##### FAILRETRY

To try recovering from transient errors (like OOM or network disruption), set `FAILRETRY`
to the number of attempts you want processors to make.

Without this, a failed step causes falling back to `ocrd-dummy` (if `FAILDUMMY=1`) or
the workflow to stop (otherwise) for that target workspace,
removing output pages already processed successfully (unless `PAGEWISE=1`).

##### FAILDUMMY

To handle errors gracefully, set `FAILDUMMY=1`. This will run a `ocrd-dummy` on the respective file groups and pages,
which effectively copies the input to the output annotation (so subsequent steps can continue on these pages).

Without this, a failed step causes the workflow to stop for that target workspace,
removing output pages already processed successfully (unless `PAGEWISE=1`).

##### METSSERV

To use METS Servers for each workspace, set `METSSERV=1`. On each workspace, this will
- start a METS Server in the background, using local Unix Domain Socket `mets.sock`, then
- run the workflow, having processors communicate via the socket, and finally
- stop the METS Server.

The METS Server avoids the cost of de/serialisation of the METS between processor calls,
and thus increases efficiency. It also allows calling processors for pages independently
(because the server synchronises METS updates, which the filesystem `mets.xml` cannot).

So a very useful combination is `METSSERV=1 PAGEWISE=1`. (In that combination, the top-level
number of jobs, `-j`, and load-level, `-l`, will be distributed to the page-wise calls;
see below).

##### PAGEWISE

To run processors on each page individually, set `PAGEWISE=1`. For each workflow step that needs an update,
this will call `make` recursively with `PAGES` set to each single page ID. (The top-level `PAGES`
setting is still respected, i.e. it only splits up the requested pages.)

This is most useful in combination with `FAILDUMMY=1` (for per-page error handling) and `METSSERV=1`
(for parallel distribution).

Note: the combination `PAGEWISE=1 METSSERV=1` will reserve all jobs (options `-j N` and `-l N`)
for the parallel pages instead of parallel documents.

##### JOBDB

To generate an SQL database and feed it with the jobs' status, set `JOBDB` to some non-empty
file path. As soon as ocrd-make starts, it will create a new `jobs` table with the following schema:

| *table header* | *description* |
| --- | --- |
| Seq | consecutive job number |
| Host | remote host (`-X` option), if any |
| Starttime | date started, if running |
| JobRuntime | duration so far, if running |
| Send | number of bytes sent, if any |
| Receive | number of bytes received, if any |
| Exitval | exit status (-1000 if not started) |
| _Signal | interrupt signal, if any |
| Command | (ocrd-)make command line |
| V1 | workspace path |
| Stdout | captured standard output |
| Stderr | captured standard error |

This will use `sqlite3`, which (requires `libdbd-sqlite3-perl` to be installed and) is incapable
of true concurrency, so you need to open the database in read-only mode, e.g.

    sqlite3 "file:$JOBDB?immutable=1&mode=ro" '.headers on' '.mode csv' 'SELECT * FROM jobs;'

Without this, only a CSV-formatted log file of finished jobs gets generated under `$CFGNAME.$$.log`
(i.e. using the name of the workflow and process ID).

##### Remote distribution

To run jobs on another machine (which has ocrd-make and the respecive OCR-D processors installed),
transferring the workflow configuration file and workspace directories prior to execution, and
the results afterwards, use `-X` or `--transfer`.

It takes as argument the remote host name and remote working directory, separated by a colon. In case
the installation on the remote side needs initialization after login, use `--remote-init` followed by
the respective command.

Example:

    ocrd-make -j 4 --remote-init ". ~/.bash_profile" -X user@host.domain:/local -f CONFIGURATION.mk all


### Customisation

To write new configurations, first choose a (sufficiently descriptive) makefile name, and spawn a new file for that: `make -C workflow-configuration NEW-CONFIGURATION.mk` (or copy from an existing configuration).

Next, edit the file to your needs: Write rules using file groups as prerequisites/targets in the normal GNU make syntax. The first target defined must be the default goal that builds the very last file group for that configuration, or else a variable `.DEFAULT_GOAL` pointing to that target must be set anywhere in the makefile.

#### Recommendations

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

```

### Testing

To run `ocrd-import` and `ocrd-make` (in various modes) on sample data, 
in the installation directory do:

    make test

This is also used by the CI.

### Results

#### OCR-D ground truth

:construction: these results are no longer meaningful and should be updated!

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

Rules that are not configuration-specific (like the static pattern rule) are all shared by including a common `Makefile` at the end of configuration makefiles (which gets copied from `workflow.mk` at install time).

`make` always operates on the level of the workspace directory (i.e. only one at a time), where targets are fileGrps and the default goal is the maximum fileGrp.

For running entire collections of workspaces (possibly in parallel), recursive `make` has been abandoned in favour of the `parallel`-based `bash` script `ocrd-make`. Its command-line interface _looks_ like `make`, but the targets are workspaces and the default goal is `all` (which recursively `find`s all workspaces).

:construction: we should explain the use of GNU `parallel` here.

#### GPU vs CPU parallelism

When executing workflows in parallel across workspaces (with `--jobs`) on multiple CPUs, it must be ensured that not too many OCR-D processors which use GPU resources are running concurrently (to prevent over-allocation of GPU memory). Thus, make needs to know:
1. which processors (have/want to) use GPU resources, and
2. how many such processors can run in parallel.

It can then synchronize these processors with a semaphore. This is achieved by expanding the static pattern rule with a synchronisation mechanism (based on GNU parallel). Workflow configurations can use that by setting the target-specific variable `GPU` to a non-empty value for the respective rules. (Custom recipes will have to use `sem --id OCR-D-GPUSEM`.)

That way, races are prevented, but also GPUs cannot become the bottleneck: When all GPUs are busy, processors will fall back to CPU.

#### workspace vs page parallelism

When executing workflows in parallel across workspaces (with `--jobs`) on multiple CPUs, it must be ensured that OCR-D processors do not use local multiprocessing facilities themselves (to prevent over-allocation of CPUs).

In the current state of affairs, OCR-D processors cannot be run in parallel across pages via multiprocessing. (At least, they are never implemented that way.) That may change in the future with a [new OCR-D API](https://github.com/OCR-D/core/issues/322). But still, many processors do already use libraries like OpenMP or OpenBLAS which use multiprocessing locally within pages. This can be controlled via _environment variables_ like `OMP_THREAD_LIMIT`.

This is achieved by exporting these variables to all recipes with a value of `1` when `-j` is used, or half the number of physical CPUs (unless `NTHREADS` is explicitly given) otherwise.
