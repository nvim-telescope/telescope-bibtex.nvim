local actions = require('telescope.actions')
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

  citation_append = function(citation_format)
    return function(prompt_bufnr)
      local entry = action_state.get_selected_entry().id.content
      actions.close(prompt_bufnr)
      local citation = format_citation(entry, citation_format)
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
