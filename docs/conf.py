import os
on_rtd = os.environ.get('READTHEDOCS') == 'True'
if on_rtd:
    html_theme = 'default'
else:
    html_theme = 'sphinx_rtd_theme'

# -- Project information -----------------------------------------------------

project = 'Bastille'
copyright = '2018-2023, Christer Edwards'
author = 'Christer Edwards'

# The short X.Y version
version = '0.10.20231125'
# The full version, including alpha/beta/rc tags
release = '0.10.20231125-beta'


# -- General configuration ---------------------------------------------------

extensions = [
]

templates_path = ['_templates']

source_suffix = ['.rst', '.md']

#from recommonmark.parser import CommonMarkParser
#source_parsers = {
#    '.md': CommonMarkParser,
#}

master_doc = 'index'
language = None
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']
pygments_style = None

# -- Options for HTML output -------------------------------------------------

html_static_path = ['_static']

# -- Options for HTMLHelp output ---------------------------------------------

htmlhelp_basename = 'Bastilledoc'


# -- Options for LaTeX output ------------------------------------------------

latex_elements = {
}

latex_documents = [
    (master_doc, 'Bastille.tex', 'Bastille Documentation',
     'Christer Edwards', 'manual'),
]

# -- Options for manual page output ------------------------------------------

man_pages = [
    (master_doc, 'bastille', 'Bastille Documentation',
     [author], 1)
]


# -- Options for Texinfo output ----------------------------------------------

texinfo_documents = [
    (master_doc, 'Bastille', 'Bastille Documentation',
     author, 'Bastille', 'Bastille is an open-source system for automating deployment and management of containerized applications on FreeBSD.',
     'Miscellaneous'),
]

# -- Options for Epub output -------------------------------------------------

epub_title = project

# A list of files that should not be packed into the epub file.
epub_exclude_files = ['search.html']
