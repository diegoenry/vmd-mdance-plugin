# Minimal makefile for Sphinx documentation (warnings are errors).
SPHINXOPTS    ?= -W --keep-going
SPHINXBUILD   ?= python3 -m sphinx
SOURCEDIR     = .
BUILDDIR      = _build

help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)

.PHONY: help Makefile

# the parameters page is written from the plugin's table first
%: Makefile
	@cd .. && tclsh docs/tools/gen_parameters.tcl
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)
