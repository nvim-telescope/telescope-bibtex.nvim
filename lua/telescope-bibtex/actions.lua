local actions = require('telescope.actions')
local utils = require('telescope-bibtex.utils')
local action_state = require('telescope.actions.state')

return {
  key_append = function(format_string)
    return function(prompt_bufnr)
      local mode = vim.api.nvim_get_mode().mode
      local entry =
          string.format(format_string, action_state.get_selected_entry().id.name)
      actions.close(prompt_bufnr)
      if mode == 'i' then
        vim.api.nvim_put({ entry }, '', false, true)
        vim.api.nvim_feedkeys('a', 'n', true)
      else
        vim.api.nvim_put({ entry }, '', true, true)
      end
    end
  end,

  entry_append = function(prompt_bufnr)
    local entry = action_state.get_selected_entry().id.content
    actions.close(prompt_bufnr)
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'i' then
      vim.api.nvim_put(entry, '', false, true)
      vim.api.nvim_feedkeys('a', 'n', true)
    else
      vim.api.nvim_put(entry, '', true, true)
    end
  end,

  citation_append = function(citation_format, opts)
    return function(prompt_bufnr)
      local entry = action_state.get_selected_entry().id.content
      actions.close(prompt_bufnr)
      local citation = utils.format_citation(entry, citation_format, opts)
      local mode = vim.api.nvim_get_mode().mode
      if mode == 'i' then
        vim.api.nvim_put({citation}, '', false, true)
        vim.api.nvim_feedkeys('a', 'n', true)
      else
        vim.api.nvim_paste(citation, true, -1)
      end
    end
  end
}
