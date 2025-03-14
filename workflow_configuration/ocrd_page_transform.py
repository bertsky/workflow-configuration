from __future__ import absolute_import

from typing import Optional, get_args
import os

from lxml import etree as ET
import click

from ocrd import Processor, OcrdPageResult
from ocrd_models.ocrd_page import (
    PcGtsType,
    PageType,
    OcrdPage,
)
from ocrd_models.ocrd_file import OcrdFileType
from ocrd_models.constants import NAMESPACES
from ocrd_utils import MIMETYPE_PAGE, MIME_TO_EXT, config, make_file_id
from ocrd_modelfactory import page_from_file
from ocrd.decorators import ocrd_cli_options, ocrd_cli_wrap_processor

def pairwise(iterable):
    iterator = iter(iterable)
    a = next(iterator, None)
    for b in iterator:
        yield a, b
        a = b

class PageTransform(Processor):
    """
    Transform pages with the given XSLT.

    Open the input PAGE element hierarchy and process it with the
    XSLT processor parsed from the `xsl` resource file, passing
    `xslt-params` as XSLT parameters (if any).

    Generate a new PAGE object from the resulting hierarchy,
    finally serialise and add it as new output file.
    """

    @property
    def executable(self):
        return 'ocrd-page-transform'

    def setup(self):
        xsl = self.resolve_resource(self.parameter['xsl'])
        self.logger.info("parsing xsl='%s'", xsl)
        xsl = ET.parse(xsl)
        self.xslt = ET.XSLT(xsl)
        xsltparam = self.parameter['xslt-params']
        self.logger.info("parsing xslt-params='%s'", xsltparam)
        # support xmlstarlet CLI options for backwards compatibility
        self.xsltparams = dict()
        for kind, setting in pairwise(xsltparam.split()):
            key, val = setting.split('=')
            if kind == '-s':
                self.xsltparams[key] = "'%s'" % val
            elif kind == '-p':
                self.xsltparams[key] = ET.XPath("'%s'" % val, namespaces={
                    'page': NAMESPACES['page'],
                    'pc': NAMESPACES['page']})
            else:
                raise ValueError("xslt-params must be '-s' (string literal) or '-p' (XPath expression), but not '%s'" % kind)
        self.parameter['pretty-print'] # ignore

    def process_page_file(self, *input_files : Optional[OcrdFileType]) -> None:
        if self.parameter['mimetype'] == MIMETYPE_PAGE:
            return super().process_page_file(*input_files)
        # from core's ocrd.processor.base
        input_pcgts : List[Optional[OcrdPage]] = [None] * len(input_files)
        assert isinstance(input_files[0], get_args(OcrdFileType))
        page_id = input_files[0].pageId
        self._base_logger.info("processing page %s", page_id)
        for i, input_file in enumerate(input_files):
            assert isinstance(input_file, get_args(OcrdFileType))
            self._base_logger.debug(f"parsing file {input_file.ID} for page {page_id}")
            try:
                page_ = page_from_file(input_file)
                assert isinstance(page_, OcrdPage)
                input_pcgts[i] = page_
            except ValueError as err:
                # not PAGE and not an image to generate PAGE for
                self._base_logger.error(f"non-PAGE input for page {page_id}: {err}")
        output_file_id = make_file_id(input_files[0], self.output_file_grp)
        output_file = next(self.workspace.mets.find_files(ID=output_file_id), None)
        if output_file and config.OCRD_EXISTING_OUTPUT != 'OVERWRITE':
            # short-cut avoiding useless computation:
            raise FileExistsError(
                f"A file with ID=={output_file_id} already exists {output_file} and neither force nor ignore are set"
            )
        result = self.xslt(input_pcgts[0].etree, **self.xsltparams)
        output_file_ext = MIME_TO_EXT.get(self.parameter['mimetype'], '')
        self.workspace.add_file(
            file_id=output_file_id,
            file_grp=self.output_file_grp,
            page_id=page_id,
            local_filename=os.path.join(self.output_file_grp, output_file_id + output_file_ext),
            mimetype=self.parameter['mimetype'],
            content=str(result),
        )

    def process_page_pcgts(self, *input_pcgts: Optional[OcrdPage], page_id: Optional[str] = None) -> OcrdPageResult:
        pcgts = input_pcgts[0]
        result = self.xslt(pcgts.etree, **self.xsltparams)
        for error in self.xslt.error_log:
            self.logger.error(error)
        root = result.getroot()
        assert root is not None, "transform yields non-XML result; try setting `mimetype` parameter correctly"
        root = PcGtsType.factory()
        root.build(result.getroot())
        return OcrdPageResult(OcrdPage(root, result, {}, {}))

@click.command()
@ocrd_cli_options
def cli(*args, **kwargs):
    return ocrd_cli_wrap_processor(PageTransform, *args, **kwargs)
