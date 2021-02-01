# telescope-bibtex

Search and paste entries from `*.bib` files with [telescope.nvim](https://github.com/nvim-telescope).

The `*.bib` files must be under (see [Configuration](#configuration)) the current working directory.

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
To set it to another value, add this to your telescope setup:

```
require"telescope".setup {
  ...

  extensions = {
    bibtex = {
      depth = 3,
    },
  }
}
```
