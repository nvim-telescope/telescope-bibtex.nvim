# telescope-bibtex

Search and paste entries from `*.bib` files with [telescope.nvim](https://github.com/nvim-telescope).

The `*.bib` files must be under the current working directory or you need to supply global files/directories (see [Configuration](#configuration)).

## Requirements

This is a plugin for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). Therefore, it needs to be installed as well.

## Installation

Plug

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-bibtex.nvim'
```

Packer

```lua
use { "nvim-telescope/telescope-bibtex.nvim",
  requires = {
    {'nvim-telescope/telescope.nvim'},
  },
  config = function ()
    require"telescope".load_extension("bibtex")
  end,
}
```

## Usage

Before using telescope-bibtex, you must load it (this is already taken care of
in the packer snippet above).

```vim
:lua require"telescope".load_extension("bibtex")
```

Then simply call the bibtex picker with:

```vim
:Telescope bibtex
```

### Keybindings (Actions)

The entry picker comes with three different actions.

| key     | Usage                        | Result |
|---------|------------------------------|--------|
| `<cr>`  | Insert the citation label    |@Newton1687|
| `<c-e>` | Insert the citation entry    |@book{newton1687philosophiae,<br />&nbsp;&nbsp; title={Philosophiae naturalis principia mathematica},<br />&nbsp;&nbsp;  author={Newton, I.},<br />&nbsp;&nbsp;  year={1687},<br />&nbsp;&nbsp;  publisher={J. Societatis Regiae ac Typis J. Streater}<br />  }|
| `<c-c>` | Insert a formatted citation  | Newton, I. (1687), _Philosophiae naturalis principa mathematica_.|

## Configuration

The default configuration for telescope-bibtex is:

```lua
require"telescope".setup {
  ...

  extensions = {
    bibtex = {
      -- Depth for the *.bib file
      depth = 1,
      -- Custom format for citation label
      custom_formats = {},
      -- Format to use for citation label.
      -- Try to match the filetype by default, or use 'plain'
      format = '',
      -- Path to global bibliographies (placed outside of the project)
      global_files = {},
      -- Define the search keys to use in the picker
      search_keys = { 'author', 'year', 'title' },
      -- Template for the formatted citation
      citation_format = '{{author}} ({{year}}), {{title}}.',
      -- Only use initials for the authors first name
      citation_trim_firstname = true,
      -- Max number of authors to write in the formatted citation
      -- following authors will be replaced by "et al."
      citation_max_auth = 2,
      -- Context awareness disabled by default
      context = false,
      -- Fallback to global/directory .bib files if context not found
      -- This setting has no effect if context = false
      context_fallback = true,
      -- Wrapping in the preview window is disabled by default
      wrap = false,
      -- user defined mappings
      mappings = {
          i = {
            ["<CR>"] = bibtex_actions.key_append('%s'), -- format is determined by filetype if the user has not set it explictly
            ["<C-e>"] = bibtex_actions.entry_append,
            ["<C-c>"] = bibtex_actions.citation_append('{{author}} ({{year}}), {{title}}.'),
          }
      },
    },
  }
}
```

### Context Aware Bibliography File

If enabled, the plugin will look for context lines in your currently opened file that imply which bibliography file you want to use. See below for common examples based on filetype:

| Filetype              | Context                                                                                      |
| --------------------- | -------------------------------------------------------------------------------------------- |
| `pandoc`, `md`, `rmd` | `bibliography: file_path_with_ext`                                                           |
| `tex`                 | `\bibliography{relative_file_path_no_ext}` or `\addbibresource{relative_file_path_with_ext}` |

_Note:_ Context awareness ignores the global bibliography files as well as the normal searching in the current directory.

Context awareness can be enabled in the setup with `context`.

If a context is not found in the current file, telescope-bibtex can fallback to the non-contextual behavior with `context_fallback`

```lua
require"telescope".setup {
  ...

  extensions = {
    bibtex = {
      -- Use context awareness
      context = true,
      -- Use non-contextual behavior if no context found
      -- This setting has no effect if context = false
      context_fallback = true,
    },
  }
}
```

To quickly change the context awareness, you can specify it via the options:

```
:Telescope bibtex context=false
```

### Label formats

Three common formats are pre-implemented:

| Identifier        | Result         |
| ----------        | -------------- |
| `tex`             | `\cite{label}` |
| `markdown`, `md`  | `@label`       |
| `plain`           | `label`        |

It is possible to implement custom formats as well. In that case, you must
declare the new format under `custom_formats` and enable it with `format`.

```lua
require"telescope".setup {
  ...

  extensions = {
    bibtex = {
      -- Custom format for citation label
      custom_formats = {
        {id = 'myCoolFormat', cite_marker = '#%s#'}
      },
      format = 'myCoolFormat',
    },
  }
}
```

The `id` field is the identifier for your custom format (the one to re-use in
the `format` option), while the `cite_marker` uses lua pattern matching to apply
the format.
In the example above, the citation label would then be `#label#`.

If `format` is not defined, the plugin will try to find the right format based
on the filetype. If there is no format for the filetype it will fall back to
`plain` format.

To quickly change the format, you can specify it via the options:

```
:Telescope bibtex format=markdown
```

### Search keys

You can configure telescope-bibtex to be able to search by other fields than
`author`, `year` and `title`. If you want to first search by `publisher`, then
`author` and finally `label`, just use

```lua
search_keys = { 'publisher','author', 'label' }
```

### Formatted citations

Telescope-bibtex allows you to paste a formatted citation in plain text.

Note that it is not currently possible to just ask for a usual style such as
`Chicago`, `APA`,...
Instead, you need to provide a template yourself if you want something specific.

The default format will produce a citation formatted like `Name, F. (YYYY),
Title`. You can use any field of the bibtex entry to customize the
`citation_format` parameter. If the fields are not present, they will be left
empty when pasting the formatted citation.
Besides the regular bibtex fields, you can also use `{{label}}` for the entry
label and `{{type}}` for the type of entry (`article`, `book`, `masterthesis`,
etc).

Example of `citation_format` for people using this feature for markdown
references:

```lua
citation_format = "[[^@{{label}}]]: {{author}} ({{year}}), {{title}}.",
```

It is also possible to trim the first (and middle) names of the authors in order
to keep only the initials (using `citation_trim_firstname`). The citation
formatter is also able to replace large numbers of authors by the common _et
al._ locution. Just specify the number of authors you want to keep in full with
`citation_max_auth`.

### Custom Mappings

To define a custom mapping you need to define one of the [actions](#keybindings-(actions)) provided by the plugin.
You can pass options to the action to further customize it.
One use-case for this could be to define different latex `\cite{}` mappings or other formats:

```lua
local bibtex_actions = require('telescope-bibtex.actions')

mappings = {
  i = {
    ["<C-a>"] = bibtex_actions.key_append([[\citep{%s}]]), -- a string with %s to be replaced by the citation key
    ["<C-b>"] = bibtex_actions.citation_append('[^@{{label}}]: {{author}}, {{title}}, {{journal}}, {{year}}, vol. {{volume}}, no. {{number}}, p. {{pages}}.'), -- a string with keys in {{}} to be replaced
    ["<C-c>"] = bibtex_actions.entry_append(), -- entry_append does not take any arguments
  }
}
```

## Troubleshooting

If the config does not seem to work/apply, check at which point you load the
extension. The extension will only be initialized with the right config if it is
loaded **after** calling the setup function.
