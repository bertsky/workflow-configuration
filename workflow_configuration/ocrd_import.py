from __future__ import absolute_import

import click
import re
import os
import sys
import subprocess
import  multiprocessing as mp
from time import sleep
from tempfile import TemporaryDirectory
from shutil import move
from logging import getLogger, ERROR

from ocrd.decorators import ocrd_loglevel
from ocrd import (
    Resolver,
    Workspace,
    OcrdMetsServer,
)
from ocrd.mets_server import ClientSideOcrdMets
from ocrd_models import OcrdMets
from ocrd_utils import (
    pushd_popd,
    initLogging,
    setOverrideLogLevel,
    make_xml_id,
    guess_media_type,
    EXT_TO_MIME,
    MIMETYPE_PAGE,
)

def _start_mets_server(directory, url, log_level):
    initLogging()
    setOverrideLogLevel(log_level)
    # silentium!
    getLogger('ocrd.models.ocrd_mets.server').setLevel(log_level or ERROR)
    getLogger('uvicorn.error').setLevel(log_level or ERROR)
    workspace = Workspace(Resolver(), directory, OcrdMets.empty_mets())
    server = OcrdMetsServer(workspace, url)
    server.startup()

@click.command(context_settings={'help_option_names': ['-h', '--help']})
@ocrd_loglevel
@click.option('-i', '--ignore', is_flag=True, help='keep going after unknown file types')
@click.option('-s', '--skip',  metavar='SUFFIX', multiple=True, help='ignore file names ending in given SUFFIX (repeatable)')
@click.option('-R', '--regex', metavar='EXPR', multiple=True, help='only include paths matching given EXPR (repeatable)')
@click.option('-C', '--no-convert', is_flag=True, help='do not attempt to convert image file types')
@click.option('-r', '--render', metavar='DPI', default=300, show_default=True, type=float, help='when converting PDFs, render at DPI pixel density')
@click.option('-P', '--nonnum-ids', is_flag=True, help='do not use numeric pageIds but basename patterns')
@click.option('-B', '--basename', is_flag=True, help='only use basename for IDs')
@click.option('-n', '--dry-run', is_flag=True, help='only show resulting METS to stdout via pager')
@click.option('-I', '--image-group', default='OCR-D-IMG', show_default=True, help='fileGrp to place detected or converted images into')
@click.option('-X', '--pagexml-group', default='OCR-D-PAGE', show_default=True, help='fileGrp to place detected PAGE-XML into')
@click.option('-A', '--altoxml-group', default='OCR-D-ALTO', show_default=True, help='fileGrp to place detected ALTO-XML into')
@click.option('-G', '--directory-groups', is_flag=True, help='instead of assigning files to `image_group` or `pagexml_group`, and trying to convert everything else to images, create a group for every subdirectory and auto-detect its MIME types')
@click.argument('workspace_dir', type=click.Path(file_okay=False))
def cli(workspace_dir, dry_run, log_level, **kwargs):
    """
    \b
    Create OCR-D workspace meta-data (mets.xml) in WORKSPACE_DIR (or $PWD), importing...
    * all image files (with known file extension or convertible via ImageMagick) under fileGrp `image_group`
    * all .xml files (if they validate as PAGE-XML) under fileGrp `pagexml_group`
    * all .xml files (if they validate as ALTO-XML) under fileGrp `altoxml_group`
    ...but failing otherwise (unless `ignore` is set)
    """
    initLogging()
    ctxt = mp.get_context('spawn') # avoid forking, because the child then kills the tmpdir
    with TemporaryDirectory() as tmpdir:
        mets_server_url = os.path.join(tmpdir, 'mets.sock')
        mets_server = ctxt.Process(target=_start_mets_server,
                                   args=(workspace_dir if not dry_run else tmpdir,
                                         mets_server_url,
                                         log_level),
                                   # auto-kill in case of failure
                                   daemon=True)
        mets_server.start()
        sleep(2)
        assert mets_server.is_alive() # not much worth (also true when not running *yet*)
        sys.exit(0 if ocrd_import(tmpdir, workspace_dir, mets_server_url,
                                  log_level=log_level, dry_run=dry_run,
                                  **kwargs)
                 else 1)

def ocrd_import(tmpdir, workspace_dir, mets_server_url,
                log_level=None,
                ignore=False,
                skip=None,
                regex=None,
                no_convert=False,
                render=300,
                nonnum_ids=False,
                basename=False,
                dry_run=False,
                image_group='OCR-D-IMG',
                pagexml_group='OCR-D-SEG-PAGE',
                altoxml_group='OCR-D-SEG-ALTO',
                directory_groups=False,
):
    if os.path.exists(os.path.join(workspace_dir, 'mets.xml')) or \
       os.path.exists(os.path.join(workspace_dir, 'data', 'mets.xml')):
        raise ValueError("Directory '%s' already is a workspace" % workspace_dir)
    LOG = getLogger("ocrd.import")
    assert os.path.exists(mets_server_url)
    mets = ClientSideOcrdMets(mets_server_url)
    LOG.info("analysing '%s'", workspace_dir)
    if ignore is None:
        ignore = []
    if skip is None:
        skip = []
    if regex is None:
        regex = []
    else:
        regex = [re.compile(expr) for expr in regex]
    pages = dict()
    with pushd_popd(workspace_dir):
        for dirname, dirs, files in os.walk(".", followlinks=True):
            dirname = dirname[2:] # remove ./ prefix
            for fname in files:
                fpath = os.path.join(dirname, fname)
                LOG.debug("inspecting file '%s'", fpath)
                if os.path.getsize(fpath) == 0:
                    LOG.warning("ignoring empty file '%s'", fpath)
                    continue
                if fname.endswith(".log") or \
                   any(fname.endswith(suffix) for suffix in skip):
                    LOG.info("skipping file '%s'", fpath)
                    continue
                if regex:
                   if any(expr.fullmatch(fname) for expr in regex):
                       LOG.info("matching file '%s'", fpath)
                   else:
                       continue
                base, suffix = os.path.splitext(fname)
                # create ID from path
                if not basename:
                    base = dirname.replace('/', '_') + '_' + base
                # XML ID must start with letter and not contain colons or spaces
                # also, avoid . in IDs, because downstream it will confuse filename suffix detection
                if not base[0].isalpha():
                    base = "f" + base # to avoid "id_" prefix for backwards compatibility
                base = make_xml_id(base)
                # guess MIME type
                #mime = EXT_TO_MIME.get(suffix.lower(), "")
                mime = guess_media_type(fpath, application_xml=MIMETYPE_PAGE)
                if mime == MIMETYPE_PAGE:
                    with open(fpath, 'r') as fd:
                        content = fd.read()
                    if "http://schema.primaresearch.org/PAGE/gts/pagecontent/" in content and \
                       (":PcGts " in content or "<PcGts " in content):
                        group = pagexml_group
                    elif "http://www.loc.gov/standards/alto/" in content and \
                         (":alto " in content or "<alto " in content):
                        group = altoxml_group
                    elif directory_groups:
                        mime = 'application/xml'
                    elif ignore:
                        LOG.warning("unknown type of file '%s'", fpath)
                        continue
                    else:
                        LOG.critical("unknown type of file '%s'", fpath)
                        return False
                elif mime in ["image/tiff", "image/jpeg", "image/png"]:
                    group = image_group # directly supported
                elif directory_groups:
                    pass
                elif no_convert:
                    if ignore:
                        LOG.warning("unknown type of file '%s'", fpath)
                        continue
                    LOG.critical("unknown type of file '%s'", fpath)
                    return False
                else:
                    # try convert to image
                    if mime in ["application/pdf", "application/postscript"]:
                        inopts = ["-units", "PixelsPerInch", "-density", str(2*render)]
                        outopts = ["-background", "white", "-alpha", "remove", "-alpha", "off",
                                   "-colorspace", "Gray", "-units", "PixelsPerInch", "-resample", str(render),
                                   "-density", str(render)]
                    else:
                        inopts = []
                        outopts = []
                    group = image_group
                    LOG.warning("converting '%s' to '%s/%s_*.tif' prior to import", fpath, group, base)
                    resdir = os.path.join(tmpdir, group)
                    os.makedirs(resdir, exist_ok=True)
                    result = subprocess.run(["convert"] +
                                            #["-debug", "All"] +
                                            inopts + [fpath] + \
                                            outopts + [os.path.join(resdir, base + "_%04d.tif")],
                                            # ensure temporary files get deleted afterwards
                                            env=dict(MAGICK_TMPDIR=tmpdir, **os.environ),
                                            shell=False, text=True, capture_output=True, encoding="utf-8")
                    #LOG.debug(result.args)
                    if result.stdout:
                        LOG.debug("convert for '%s': %s", fpath, result.stdout)
                    if result.stderr:
                        LOG.warning("convert for '%s': %s", fpath, result.stderr)
                    if result.returncode != 0:
                        LOG.error("convert for '%s' failed", fpath)
                        if ignore:
                            continue
                        return False
                    resfiles = list(resfname for resfname in os.listdir(resdir)
                                    if resfname.startswith(base))
                    LOG.info("converted '%s' to '%s/%s_*.tif' (%d files)", fpath, group, base, len(resfiles))
                    mime = "image/tiff"
                    for resfname in resfiles:
                        resfpath = os.path.join(group, resfname)
                        resbase = os.path.splitext(resfname)[0]
                        resattr = (resfpath, resfname, resbase, mime, tmpdir)
                        respage = pages.setdefault(resbase, dict())
                        if group in respage:
                            LOG.critical("would result in duplicate file IDs: %s vs %s",
                                         str(respage[group]), str(resattr))
                            return False
                        respage[group] = resattr
                    continue
                attr = (fpath, fname, base, mime, "")
                page = pages.setdefault(base, dict())
                if directory_groups:
                    group = dirname
                if group in page:
                    LOG.critical("would result in duplicate file IDs: %s vs %s",
                                 str(page[group]), str(attr))
                    return False
                page[group] = attr
        groups = list(group for page in pages for group in pages[page])
        LOG.info("found %d files for %d groups across %d pages",
                 len(groups), len(set(groups)), len(pages))
        sched_mkdir = list(set(groups)) # mkdir groups (even if empty)
        sched_move = [] # get converted files from tmpdir
        for page_num, page in enumerate(sorted(pages), start=1):
            for group in pages[page]:
                path, fname, base, mime, location = pages[page][group]
                if location:
                    # copy from tmpdir to target
                    sched_move.append((location, path))
                    # file IDs must contain fileGrp, otherwise processors will have to prevent
                if nonnum_ids:
                    subdir = os.path.dirname(path).replace('/', '_')
                    # try to be smart
                    if base.startswith(group):
                        page = base[len(group):]
                    elif base.endswith(group):
                        page = base[:-len(group)]
                    # even smarter: mismatch between original and target group
                    elif base.startswith(subdir):
                        page = base[len(subdir):]
                    elif base.endswith(subdir):
                        page = base[:-len(subdir)]
                    else:
                        page = base
                    page = page.strip('_-.')
                    # XML ID must start with letter and not contain colons or spaces
                    if not page[0].isalpha():
                        page = "p" + page # to avoid "id_" prefix for backwards compatibility
                    page = make_xml_id(page)
                else:
                    page = "p%04d" % page_num
                # file IDs must contain fileGrp, otherwise processors will have to prevent
                # ID clashes by using numeric IDs
                if not group in base:
                    base = group + "_" + base
                LOG.info(f"adding -g {page} -G {group} -m {mime} -i {base} '{path}'")
                mets.add_file(group, ID=base, local_filename=path, mimetype=mime, pageId=page)
        mets.stop() # includes save
        LOG.info("creating directories for output fileGrps: %s", str(sched_mkdir))
        for group in sched_mkdir:
            LOG.info("mkdir '%s'", group)
            if not dry_run:
                os.makedirs(group, exist_ok=True)
        LOG.info("moving %d converted files from tmpdir to output directory", len(sched_move))
        for location, path in sched_move:
            LOG.info("mv '%s' '%s'", os.path.join(location, path), path)
            if not dry_run:
                move(os.path.join(location, path), path)
        if dry_run:
            with open(os.path.join(tmpdir, "mets.xml")) as file:
                content = file.read()
            click.echo_via_pager(content)
    LOG.info("Success on '%s'", workspace_dir)
    return True

if __name__ == '__main__':
    cli()
