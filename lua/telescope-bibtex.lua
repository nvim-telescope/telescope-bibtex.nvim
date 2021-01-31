local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local actions = require('telescope.actions')
local conf = require('telescope.config').values
local scan = require('plenary.scandir')
local path = require('plenary.path')

local function read_file(file)
  local entries = {}
  local p = path:new(file)
  if not p:exists() then return {} end
  for line in p:iter() do
    if line:match("@%w*{") then
      local entry = line:gsub("@%w*{", "")
      entry = entry:sub(1, -2)
      table.insert(entries, entry)
    end
  end
  return entries
end

local function bibtex_picker(opts)
  local results = {}
  scan.scan_dir('.', { depth = 1, search_pattern = '.*%.bib', on_insert = function(file)
    file = file:sub(3)
    local result = read_file(file)
    for _, entry in pairs(result) do
      table.insert(results, entry)
    end
  end })
  pickers.new(opts, {
    prompt_title = 'Bibtex References',
    finder = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          value = line,
          ordinal = line,
          display = line
        }
      end
    },
    previewer = nil,
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, _)
        local entry = "\\cite{"..actions.get_selected_entry().value.."}"
        actions.close(prompt_bufnr)
        vim.api.nvim_put({entry}, "", true, true)
        -- TODO: prettier insert mode? <16-01-21, @noahares> --
        vim.api.nvim_feedkeys("A", "n", true)
      end)
      return true
    end,
  }):find()
end

return {
  bibtex_picker = bibtex_picker
}
