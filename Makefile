.SILENT:

# The plugin as VMD's plugin build installs it: the package folder only
# (tests/ and docs/ belong with the source).
VMVERSION = 1.0
DIR = $(PLUGINDIR)/noarch/tcl/vmdance$(VMVERSION)

bins:
win32bins:
dynlibs:
staticlibs:
win32staticlibs:

distrib:
	@echo "Copying vmdance $(VMVERSION) files to $(DIR)"
	mkdir -p $(DIR)
	cp -r vmdance/pkgIndex.tcl vmdance/vmdance.tcl vmdance/lib $(DIR)
	mkdir -p $(DIR)/icons
	cp vmdance/icons/*.png $(DIR)/icons
