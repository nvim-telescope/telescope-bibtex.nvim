# telescope-bibtex

Search and paste entries from `*.bib` files with [telescope.nvim](https://github.com/nvim-telescope).

The `*.bib` files must be under the current working directory or you need to supply global files/directories (see [Configuration](#configuration)).

# Requirements

[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

# Installation

## Plug

```
Plug 'nvim-telescope/telescope-bibtex.nvim'
```

# Usage

```
lua require"telescope".load_extension("bibtex")

:Telescope bibtex
```

# Configuration

The default search depth for `*.bib` files is 1.

The currently supported formats are `tex` and `md` for `\cite{entry}` and `@entry` respectively.

You may add custom formats: `id` is the format identifier, `cite_marker` the format to apply.

Some people have master `*.bib` files that do not lie within the project tree. Directories and files to retrieve entries from can be set.

See the example below for the config in action:

```
require"telescope".setup {
  ...

  extensions = {
    bibtex = {
      depth = 1,
      custom_formats = {
        {id = 'myCoolFormat', cite_marker = '#%s#'}
      },
      format = 'myCoolFormat',
      global_files = { 'path/to/my/bib/file.bib', 'path/to/my/bib/directory' },
      search_keys = { 'author', 'publisher' },
    },
  }
}
```

This produces output like `#entry#`.

Think of this as defining text before and after the entry and putting a `%s` where the entry should be put.

If `format` is not defined, the plugin will fall back to `tex` format.
