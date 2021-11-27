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

:Telescope bibtex cite

:Telescope bibtex entry
```

**`Telescope bibtex` will still work for now, but becomes deprecated in favor of `Telescope bibtex cite` and will eventually be removed!**

# Configuration

The default search depth for `*.bib` files is 1.

The currently supported formats are:

| Identifier | Result         |
| ---------- | -------------- |
| `tex`      | `\cite{label}` |
| `md`       | `@label`       |
| `plain`    | `label`        |

You may add custom formats: `id` is the format identifier, `cite_marker` the format to apply.

Some people have master `*.bib` files that do not lie within the project tree. Directories and files to retrieve entries from can be set.

The default search matches `author, year, title` in this order.

To search for the citation label, add `label` to the `search_keys`. Other keys to match are named by their tag in the bibtex file.

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
      search_keys = { 'label', 'author', 'publisher' },
    },
  }
}
```

This produces output like `#label#`.

The `entry` picker will always paste the whole entry.

Think of this as defining text before and after the entry and putting a `%s` where the entry should be put.

If `format` is not defined, the plugin will fall back to `tex` format.

If the config does not seem to work/apply, check at which point you load the extension. The extension will only be initialized with the right config if it is loaded **after** calling the setup function.
