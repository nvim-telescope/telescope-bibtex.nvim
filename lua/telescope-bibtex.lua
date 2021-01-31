local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local actions = require('telescope.actions')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local scan = require('plenary.scandir')
local path = require('plenary.path')

local function read_file(file)
  local entries = {}
  local contents = {}
  local p = path:new(file)
  if not p:exists() then return {} end
  local current_entry = "";
  for line in p:iter() do
    if line:match("@%w*{") then
      local entry = line:gsub("@%w*{", "")
      entry = entry:sub(1, -2)
      current_entry = entry
      table.insert(entries, entry)
      contents[current_entry] = { line }
    else
      table.insert(contents[current_entry], line)
    end
  end
  return entries, contents
end

local function bibtex_picker(opts)
  local results = {}
  scan.scan_dir('.', { depth = 1, search_pattern = '.*%.bib', on_insert = function(file)
    file = file:sub(3)
    local result, content = read_file(file)
    for _, entry in pairs(result) do
      table.insert(results, { name = entry, content = content[entry] })
    end
  end })
  pickers.new(opts, {
    prompt_title = 'Bibtex References',
    finder = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          value = line.name,
          ordinal = line.name,
          display = line.name,
          preview_command = function(entry, bufnr)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, results[entry.index].content)
          end,
        }
      end
    },
    previewer = previewers.display_content.new({}),
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
