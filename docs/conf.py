# -- Project information -----------------------------------------------------

project = 'Bastille'
copyright = '2018-2025, Christer Edwards'
author = 'Christer Edwards'

# The short X.Y version
version = '0.14.20250420'
# The full version, including alpha/beta/rc tags
release = '0.14.20250420-beta'

# -- General configuration ---------------------------------------------------

extensions = ['sphinx_rtd_theme']

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
html_logo = 'images/bastille.jpeg'
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

html_theme_options = {
    'logo_only': False,
    'prev_next_buttons_location': 'bottom',
    'style_external_links': False,
    'vcs_pageview_mode': '',
    'style_nav_header_background': 'white',
    'flyout_display': 'hidden',
    'version_selector': True,
    'language_selector': True,
    # Toc options
    'collapse_navigation': True,
    'sticky_navigation': True,
    'navigation_depth': 4,
    'includehidden': True,
    'titles_only': False
}

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
