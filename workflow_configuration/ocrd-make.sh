#!/usr/bin/env bash

# This script encapsulates (parallel) calls to `make` in the
# workspace directories with workflow-configuration makefiles.
#
# It is meant to be used either:
# - by calling the script via its full path in the
#   workflow-configuration installation directory, or
# - by using PATH after running `make install` in the
#   workflow-configuration installation directory
#   (with a suitable choice of VIRTUAL_ENV as prefix).
#
# The CLI in parts mimics that of `make` itself, esp.
# the -j and -f options.
# Concrete workflow files must be passed by file name
# via the -f option. Relative paths are resolved by
# either the CWD, or the script's location (`dirname $0`),
# or the fixed $SHAREDIR substituted during `make install`.

SCRIPTDIR="$(dirname "$0")"
SHAREDIR="$(cd $(dirname "$0") && pwd)"
WORKFLOW=
JOBDB=
PARALLEL=0
PAGEWISE=0
METSSERV=0
JOBS=0
LOAD=0
ALL=0
XFERHOST=
XFERWORKDIR=
XFERINIT=

set -e -o pipefail

makeopts=()
targets=()
# consume all arguments, sift our own vs. make's
while (($#)); do
    case "$1" in
        -X|--transfer)
            shift
            XFERHOST=${1%:*}
            XFERWORKDIR=${1#*:}
            ;;
        --remote-init)
            shift
            XFERINIT="$1"
            ;;
        -f)
            shift
            WORKFLOW="$1"
            ;;
        --file=*|--makefile=*)
            WORKFLOW="$1"
            WORKFLOW="${WORKFLOW#*=}"
            ;;
        -j|--jobs)
            PARALLEL=1
            case "$2" in
                -*)
                    :
                    ;;
                [0-9]*)
                    JOBS=$2
                    shift
                    ;;
            esac
            ;;
        -j*|--jobs*)
            PARALLEL=1
            JOBS=$1
            JOBS=${JOBS#-j}
            JOBS=${JOBS#--jobs=}
            JOBS=${JOBS#--jobs}
            ;;
        -l)
            LOAD=0
            case "$2" in
                -*)
                    :
                    ;;
                [0-9]*)
                    LOAD=$2
                    shift
                    ;;
            esac
            ;;
        --load-average=*|--max-load=*)
            LOAD=${1#*=}
            ;;
        --load-average*|--max-load*)
            LOAD=0
            ;;
        -C)
            cd "$2"
            shift
            ;;
        --directory=*)
            cd "${2#*=}"
            ;;
        -I|--include-dir=*)
            echo >&2 "ERROR: explicit include-dir not allowed here"
            exit 1
            ;;
        -o|-W)
            makeopts+=( $1 "$2" )
            shift
            ;;
        -h|-[-]help|help)
            cat <<EOF
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
  * JOBDB: path of an sqlite3 database file to feed with jobs status
    (if unset, no SQL database will be generated, only a CSV-formatted log file)
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

(This will merely delegate to \`make\` on the given working directories
from the installation directory "$SHAREDIR".
All options except -C and -I are allowed and passed through.
Options -j and -l are intercepted.)

EOF
            exit
            ;;
        -*|--*)
            makeopts+=( "$1" )
            ;;
        *=*)
            makeopts+=( "$1" )
            eval ${1%=*}=${1#*=}
            ;;
        all)
            ALL=1
            ;;
        info|show|server)
            make "${makeopts[@]}" -I $SHAREDIR -f $WORKFLOW $1
            exit
            ;;
        *)
            if ! [[ -d "$1" ]]; then
                echo >&2 "ERROR: target '$1' is not a directory"
                exit 1
            fi
            targets+=( "$1" )
            ;;
    esac
    shift
done

if [[ -z "$WORKFLOW" ]]; then
    echo >&2 "ERROR: must set concrete workflow file (-f option)"
    exit 1
fi

if [[ "$WORKFLOW" = "${WORKFLOW#/}" ]]; then
    # relative path
    if [[ -e "$WORKFLOW" ]]; then
        WORKFLOW="$PWD/$WORKFLOW"
    elif [[ -e "$SCRIPTDIR/$WORKFLOW" ]]; then
        WORKFLOW="$SCRIPTDIR/$WORKFLOW"
    elif [[ -e "$SHAREDIR/$WORKFLOW" ]]; then
        WORKFLOW="$SHAREDIR/$WORKFLOW"
    fi
fi
if ! [[ -e "$WORKFLOW" ]]; then
    echo >&2 "ERROR: cannot resolve path name '$WORKFLOW'"
    exit 1
fi

CFGDIR="$(realpath $(dirname "$WORKFLOW"))"
CFGNAME="$(basename "${WORKFLOW%.mk}")"
if  [[ -n "$XFERHOST" ]]; then
    # will be copied via to host via --bf relative to --wd
    WORKFLOW="$CFGDIR/./${CFGNAME}.mk"
    # sharedir will be added on host
    makeopts+=( -f "$CFGNAME.mk" )
else
    # include directory of workflow config itself,
    # in case it includes a local.mk or Makefile
    # and is not here:  -I "$CFGDIR"
    makeopts+=( -R -I "$SHAREDIR" -f "$WORKFLOW" )
fi

((${#targets[*]})) || ALL=1
if ((ALL)); then
    # find all */mets.xml
    # FIXME: find a way to shortcut directories we already found
    targets=( $(find -L . -mindepth 2 -path "./*.backup" -prune -o -name mets.xml -printf "%h\n") )
fi

###
# suppress other multiscalar mechanisms
# (mostly related to Python numpy and Tesseract OpenMP:)
NPROCS=$(nproc)
NPROCS2=$(( $NPROCS/2 ))
if ((NPROCS2==0)); then
    NTHREADS=1
else
    NTHREADS=$NPROCS2
fi
if ((PARALLEL)); then
    export OMP_THREAD_LIMIT=$NTHREADS
    export OMP_NUM_THREADS=$NTHREADS
    export OPENBLAS_NUM_THREADS=$NTHREADS
    export VECLIB_MAXIMUM_THREADS=$NTHREADS
    export NUMEXPR_NUM_THREADS=$NTHREADS
    export MKL_NUM_THREADS=$NTHREADS
else
    export OMP_THREAD_LIMIT=1
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1
    export VECLIB_MAXIMUM_THREADS=1
    export NUMEXPR_NUM_THREADS=1
    export MKL_NUM_THREADS=1
fi
# FIXME: how about multiprocessing/threading in Tensorflow?

set +e

if ((PARALLEL)); then
    parallelopts=(--progress --joblog $CFGNAME.$$.log --files --tag)

    if [[ -n "$XFERHOST" ]]; then
        parallelopts+=(--jobs 1) # default is 100% i.e. num cores
        # disambiguate document-parallel / page-parallel on remote host
        ((LOAD)) && makeopts+=(--load $LOAD)
        ((JOBS)) && makeopts+=(--jobs $JOBS)
    elif ((METSSERV && PAGEWISE)); then
        parallelopts+=(--jobs 1) # default is 100% i.e. num cores
        # enable page-parallel rules in recursive make (workflow.mk)
        ((LOAD)) && makeopts+=(LOAD=$LOAD)
        ((JOBS)) && makeopts+=(JOBS=$JOBS)
        # disable document-parallel behaviour to avoid oversubscription
        LOAD=0
        JOBS=0
    else
        # enable document-parallel options here
        ((LOAD)) && parallelopts+=(--load $LOAD)
        ((JOBS)) && parallelopts+=(--jobs $JOBS)
    fi

    echo >&2 "INFO: processing ${#targets[*]} workspaces with ${makeopts[*]} in parallel"
    # keep time stamps, so unchanged data will not be copied back at return
    export PARALLEL_RSYNC_OPTS="-rlDzRt"
    if [[ -n "$JOBDB" ]]; then
        # can be read synchronously (despite locking) via URL notation:
        # sqlite3 "file:$CFGNAME.sqlite?immutable=1&mode=ro" '.headers on' '.mode csv' 'SELECT * FROM jobs;'
        # schema: Seq,Host,Starttime,JobRuntime,Send,Receive,Exitval,_Signal,Command,V1,Stdout,Stderr
        parallelopts+=(--sqlandworker sqlite3:///$JOBDB/jobs)
    fi
    # 
    # --halt soon,fail=3    exit when 3 jobs fail, but wait for running jobs to complete.
    # --halt soon,fail=3%   exit when 3% of the jobs have failed, but wait for running jobs to complete.
    #  defaults to never, which runs all jobs no matter what.
    if [[ -n "$XFERHOST" ]]; then
        parallelopts+=(-S "$XFERHOST" --transfer --return {} --bf "$WORKFLOW")
        [[ -n "$XFERWORKDIR" ]] && parallelopts+=(--wd "$XFERWORKDIR")
        # we cannot just use `make` directly, since the installation on the remote host
        # will most likely use a different SHAREDIR, so wrap via ocrd-make there;
        # also, we usually need to activate our venv for OCR-D on the remote,
        # hence optional extra commands XFERINIT:
        parallel "${parallelopts[@]}" "$XFERINIT" "${XFERINIT:+;}" ocrd-make "${makeopts[@]}" {} "2>&1" ::: "${targets[@]}"
    elif ((METSSERV)); then
        parallel "${parallelopts[@]}" \
                 ocrd workspace -d {} -U {}/mets.sock server start "2>&1" "&" \
                 'sleep 2;' \
                 make "${makeopts[@]}" METS_SOCKET=mets.sock -C {} "2>&1" \
                 ';result=$?;' \
                 ocrd workspace -d {} -U {}/mets.sock server stop "2>&1" \
                 ';exit $result' \
                 ::: "${targets[@]}"
    else
        parallel "${parallelopts[@]}" make "${makeopts[@]}" -C {} "2>&1" ::: "${targets[@]}"
    fi | while read dir log; do
        echo $dir
        cat $log >> ${dir%%/}.$CFGNAME.log
        rm $log
    done
    echo $CFGNAME.$$.log
    exitcodes=( $(cat $_ | cut -d"	" -f7 | sed 1d) )
    for ((i=0; i<${#targets[*]}; i++)); do
        ((${exitcodes[$i]:-(-1)}==0)) && echo -n "success:" || echo -n "failure:"
        echo " ${targets[$i]}"
    done
else
    echo >&2 "INFO: processing ${#targets[*]} workspaces with ${makeopts[*]} serially"
    exitcodes=()
    for target in "${targets[@]}"; do
        if ((METSSERV)); then
            ocrd workspace -d "$target" -U "$target"/mets.sock server start 2>&1 | tee -a "$target.$CFGNAME.log" &
            sleep 2
            make "${makeopts[@]}" METS_SOCKET=mets.sock -C "$target" 2>&1 | tee -a "$target.$CFGNAME.log"
            exitcodes+=( $? )
            ocrd workspace -d "$target" -U "$target"/mets.sock server stop | tee -a "$target.$CFGNAME.log" 2>&1
        else
            make "${makeopts[@]}" -C "$target" 2>&1 | tee -a "$target.$CFGNAME.log"
            exitcodes+=( $? )
        fi
        ((${exitcodes[-1]}==0)) && echo -n "success:" || echo -n "failure:"
        echo " $target"
    done
fi
if ((ALL)); then
    > _all.$CFGNAME.log
    for target in "${targets[@]}"; do
        cat "$target.$CFGNAME.log" >> _all.$CFGNAME.log
    done
    echo _all.$CFGNAME.log
fi
IFS=+
exit $(("${exitcodes[*]}"))
