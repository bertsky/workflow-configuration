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

### Installation

Simply copy or symlink all makefiles (i.e. both the specific workflow configurations `*.mk` and the general `Makefile`) to the target directory. (The target directory is the one where the OCR workspace directories can be found. It is searched for `mets.xml` files recursively.)

Of course, [OCR-D core](https://github.com/OCR-D/core) itself must be installed along with its dependencies in the current environment. Moreover, depending on the actual configuration (the processors it contains), additional modules must be installed. Ideally, the configuration itself offers a target `install` which would cover all that.

### Usage

To run:
1. Activate working environment and change to the target directory.
2. Choose (or create) a workflow configuration makefile. (Yes, you may have to look inside and browse its rules!)
3. Execute: 
```bash
make -f CONFIGURATION.mk
```

You can also run on a subset of workspaces by giving these as command line targets:
3. Execute:
```bash
make -f CONFIGURATION.mk PATH/TO/WORKSPACE1 PATH/TO/WORKSPACE2
```

To get help: `make help`

To spawn a new configuration file: `make NEW-CONFIGURATION.mk`

To clone and bag/zip each workspace including only the results of the current configuration, and optimise it for JPageViewer: `make view`

### Results

#### OCR-D ground truth

For the `bagit_data_text_structur` repository, which includes both layout and text annotation down to the textline level, but very coarse segmentation, the following _character error rate_ (CER) was measured:

| *pipeline* | *CER* |
| ---------- | ----- |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .263 |
| OCR-D-OCR-OCRO-fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .267 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .314 |
| OCR-D-OCR-OCRO-frakturjze-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .317 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .122 |
| OCR-D-OCR-TESS-Fraktur-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .124 |
| OCR-D-OCR-TESS-frk-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .117 |
| OCR-D-OCR-TESS-frk-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .120 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .113 |
| OCR-D-OCR-TESS-frk+deu-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .116 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-RESEG-DEWARP | .094 |
| OCR-D-OCR-TESS-gt4histocr-BINPAGE-wolf-DENOISE-ocropy-DESKEW-ocropy-CLIP-DESKEW-tesseract-RESEG-DEWARP | .100 |

### Implementation

...

