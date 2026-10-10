# Sphinx configuration for the VMDance documentation.
import datetime
import importlib.util

project = "VMDance"
author = "Diego Gomes"
copyright = f"{datetime.date.today().year}, {author}"
version = "1.0a1"
release = "1.0 alpha 1"

extensions = ["sphinx.ext.mathjax"]
# copy buttons on the code blocks, when sphinx-copybutton is installed (the
# pages build the same without it)
if importlib.util.find_spec("sphinx_copybutton") is not None:
    extensions.insert(0, "sphinx_copybutton")
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "tools"]
highlight_language = "tcl"
pygments_style = "friendly"
pygments_dark_style = "monokai"
suppress_warnings = ["misc.highlighting_failure"]

html_theme = "furo" if importlib.util.find_spec("furo") is not None else "alabaster"
html_title = "VMDance"
html_static_path = ["_static"]
html_favicon = "_static/logo/vmdance_mark_64.png"
if html_theme == "furo":
    html_theme_options = {
        "light_logo": "logo/vmdance.svg",
        "dark_logo": "logo/vmdance_dark.svg",
        "sidebar_hide_name": True,
        "navigation_with_keys": True,
        "light_css_variables": {"color-brand-primary": "#1f5fae", "color-brand-content": "#1f5fae"},
        "dark_css_variables": {"color-brand-primary": "#8ab4f8", "color-brand-content": "#8ab4f8"},
    }
else:
    html_logo = "_static/logo/vmdance.svg"
copybutton_prompt_text = r"^\$ |^% |^vmd > "
copybutton_prompt_is_regexp = True
