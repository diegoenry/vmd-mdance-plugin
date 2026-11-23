# The VMDance quick-start guide, a PDF (for the JCIM article's Supporting
# Information). Kept apart from docs/, the online documentation: it reads
# that folder's figures, and writes nothing there.
#
#   make              vmdance-quickstart.pdf, from the numbers kept in numbers.tex
#   make numbers      run the guide's script (quickstart.tcl) in VMD, and
#                     write numbers.tex again from what it made
#   make check        run it, and compare with numbers.tex (the platform
#                     and the time apart)
#   make clean        the build folder; make distclean: the PDF too
#
# make numbers, make check and make figures need VMD, CPP-MDANCE and the
# example, the tau peptide of BitQT's examples folder:
#   make numbers VMD=/path/to/vmd TAU_DATA=/path/to/BitQT/examples \
#                MDANCE_CLI=/path/to/mdance-cli
# TAU_DATA: the folder of aligned_tau.pdb and aligned_original_tau_6K.dcd
# (git clone https://github.com/LQCT/BitQT.git: BitQT/examples).
# MDANCE_CLI: by default ../../CPP-MDANCE/build/cli/mdance-cli.
# VMD runs with an empty startup file: ~/.vmdrc is not read.

DOC      = vmdance-quickstart
VMD     ?= vmd
LATEXMK ?= latexmk
BUILD    = build

export TAU_DATA MDANCE_CLI MDANCE_LIB BENCH_REPS

.PHONY: all pdf run numbers figures bench check clean distclean

all: pdf

pdf: $(DOC).pdf

$(DOC).pdf: $(DOC).tex numbers.tex bench.tex quickstart.tcl $(wildcard figures/*)
	mkdir -p $(BUILD)
	$(LATEXMK) -pdf -interaction=nonstopmode -halt-on-error -outdir=$(BUILD) $(DOC).tex
	cp $(BUILD)/$(DOC).pdf $@

# The script's run (every time asked), its numbers in $(BUILD)/numbers.tex
run:
	mkdir -p $(BUILD)
	: > $(BUILD)/empty.vmdrc
	rm -f $(BUILD)/numbers.tex
	$(VMD) -dispdev text -startup $(BUILD)/empty.vmdrc -e numbers.tcl -args $(BUILD)/numbers.tex \
	    < /dev/null 2>&1 | tee $(BUILD)/numbers.log
	@test -s $(BUILD)/numbers.tex || { echo "numbers.tcl failed: see $(BUILD)/numbers.log"; exit 1; }

numbers: run
	cp $(BUILD)/numbers.tex numbers.tex

# The benchmark (bench.tex): the program against the library, every job
# timed whole, the median of BENCH_REPS runs (3). It needs the library too
# (MDANCE_LIB, or CPP-MDANCE built with -DBUILD_TCL=ON beside the
# repository). Run it on a machine otherwise idle: its times are the
# machine's, and are not compared by make check.
bench:
	mkdir -p $(BUILD)
	: > $(BUILD)/empty.vmdrc
	rm -f $(BUILD)/bench.tex
	$(VMD) -dispdev text -startup $(BUILD)/empty.vmdrc -e bench.tcl -args $(BUILD)/bench.tex \
	    < /dev/null 2>&1 | tee $(BUILD)/bench.log
	@test -s $(BUILD)/bench.tex || { echo "bench.tcl failed: see $(BUILD)/bench.log"; exit 1; }
	cp $(BUILD)/bench.tex bench.tex

# The figures (figures/): the script run in VMD with its window, which opens
# on the screen while they are drawn (a few minutes). VMD's standard input is
# kept open (a FIFO): VMD draws no new geometry once it has read its end.
# The window's picture is taken on macOS only (screencapture, and a lister
# of VMD's windows built with swiftc); elsewhere figures/window*.png are kept.
figures:
	mkdir -p $(BUILD) figures
	: > $(BUILD)/empty.vmdrc
	if [ "$$(uname)" = Darwin ]; then swiftc -O -o $(BUILD)/macos_windows macos_windows.swift; fi
	rm -f $(BUILD)/stdin; mkfifo $(BUILD)/stdin
	sleep 1800 > $(BUILD)/stdin & sp=$$!; \
	    $(VMD) -dispdev win -startup $(BUILD)/empty.vmdrc -e figures.tcl < $(BUILD)/stdin \
	        > $(BUILD)/figures.vmd.log 2>&1; \
	    kill $$sp 2>/dev/null; rm -f $(BUILD)/stdin
	@grep -q '^done' $(BUILD)/figures.log || { echo "figures.tcl failed: see $(BUILD)/figures.log"; exit 1; }
	python3 annotate.py figures

# The same run, compared with the numbers the guide quotes. Where it ran
# (VMD, the platform, the machine, the backend's commit), how long it took
# and the session's size may differ.
NOTCOMPARED = '^\\newcommand\{\\qs(VMD|Arch|Tcl|BackendCommit|Minutes|Machine|SessionKB)\}'
check: run
	@grep -vE $(NOTCOMPARED) numbers.tex > $(BUILD)/kept.tex
	@grep -vE $(NOTCOMPARED) $(BUILD)/numbers.tex > $(BUILD)/made.tex
	@if diff -u $(BUILD)/kept.tex $(BUILD)/made.tex; then \
	    echo "check: the guide's numbers made again, the same"; \
	else \
	    echo "check: the numbers differ from numbers.tex (above)"; exit 1; \
	fi

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -f $(DOC).pdf
