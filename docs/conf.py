# -- Project information -----------------------------------------------------

project = 'Bastille'
copyright = '2018-2025, Christer Edwards'
author = 'Christer Edwards'

# The short X.Y version
version = '1.2.0'
# The full version, including alpha/beta/rc tags
release = '1.2.0.251201'

# -- General configuration ---------------------------------------------------

extensions = ['sphinx_rtd_theme','sphinx_rtd_dark_mode']

templates_path = ['_templates']

source_suffix = ['.rst', '.md']

#from recommonmark.parser import CommonMarkParser
#source_parsers = {
#    '.md': CommonMarkParser,
#}

master_doc = 'index'
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']
pygments_style = None

# -- Options for HTML output -------------------------------------------------
html_logo = 'images/bastille.jpeg'
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

html_theme_options = {
    'collapse_navigation': True,
    'flyout_display': 'hidden',
    'includehidden': True,
    'language_selector': True,
    'logo_only': False,
    'navigation_depth': 4,
    'prev_next_buttons_location': 'bottom',
    'sticky_navigation': True,
    'style_external_links': False,
    'style_nav_header_background': 'white',
    'theme_switcher': True,
    'default_mode': 'auto',
    'titles_only': False,
    'vcs_pageview_mode': '',
    'version_selector': True,
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
