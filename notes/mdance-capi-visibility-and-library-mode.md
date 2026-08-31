---
name: mdance-capi-visibility-and-library-mode
description: "CPP-MDANCE C-API symbol visibility / why the VMD plugin's \"library mode\" runs vs CLI mode"
metadata: 
  node_type: memory
  type: project
  originSessionId: 42b79370-5dc3-4d30-97e2-6f8ad5cafee7
---

`capi/CMakeLists.txt` builds `libmdance.dylib` with `CXX_VISIBILITY_PRESET hidden` + `C_VISIBILITY_PRESET hidden`. Originally the `extern "C"` declarations in `capi/mdance_capi.h` had no export attribute, so `nm -gU libmdance.dylib | grep mdance_` returned **0** — every C-API symbol was hidden. Consequence: the Tcl extension (`tcl/mdance_tcl.cpp`, links `mdance_shared`) could not link `mdance_kmeans` et al., so the plugin's "native library mode" never actually worked and it always fell back to CLI mode (spawning `mdance-cli`).

**Why:** hidden default visibility hides every symbol not explicitly marked default.

**How to apply:** the header now defines `MDANCE_API` (`__attribute__((visibility("default")))`, `__declspec(dllexport)` on Windows) on every public function. Any new C-API function MUST carry `MDANCE_API` or it won't be linkable. After building, verify with `nm -gU build/capi/libmdance.dylib | grep mdance_`. Building the Tcl extension (`cmake -S . -B build -DBUILD_TCL=ON`) is the real link test. Note: that build links against whatever Tcl `find_package(TCL)` finds (homebrew Tcl 9 here) — fine for compile/link checking, but for deployment the extension must be built against VMD's embedded Tcl ABI (via `install.sh --with-library`).

See [[vmd-headless-verification]].
