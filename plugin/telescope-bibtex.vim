if exists('g:loaded_telescope_bibtex')
  finish
endif

command! BibtexPicker lua require'telescope-bibtex'.bibtex_picker()

let g:loaded_telescope_bibtex = 1
