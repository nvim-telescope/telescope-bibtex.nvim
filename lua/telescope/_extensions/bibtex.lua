local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local actions = require('telescope.actions')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local scan = require('plenary.scandir')
local path = require('plenary.path')
local putils = require('telescope.previewers.utils')

local depth = 1
local formats = {}
formats['tex'] = "\\cite{%s}"
formats['md'] = "@%s"
local fallback_format = 'tex'
local user_format = fallback_format

local function end_of_entry(line, par_mismatch)
  local line_blank = line:gsub("%s", "")
  for _ in (line_blank):gmatch("{") do
    par_mismatch = par_mismatch + 1
  end
  for _ in (line_blank):gmatch("}") do
    par_mismatch = par_mismatch - 1
  end
  return par_mismatch == 0
end

local function read_file(file)
  local entries = {}
  local contents = {}
  local p = path:new(file)
  if not p:exists() then return {} end
  local current_entry = ""
  local in_entry = false
  local par_mismatch = 0
  for line in p:iter() do
    if line:match("@%w*{") then
      in_entry = true
      par_mismatch = 1
      local entry = line:gsub("@%w*{", "")
      entry = entry:sub(1, -2)
      current_entry = entry
      table.insert(entries, entry)
      contents[current_entry] = { line }
    elseif in_entry and line ~= "" then
      table.insert(contents[current_entry], line)
      if end_of_entry(line, par_mismatch) then
        in_entry = false
      end
    end
  end
  return entries, contents
end

local function bibtex_picker(opts)
  opts = opts or {}
  local results = {}
  scan.scan_dir('.', { depth = depth, search_pattern = '.*%.bib', on_insert = function(file)
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
            putils.highlighter(bufnr, 'bib')
          end,
        }
      end
    },
    previewer = previewers.display_content.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, _)
        local entry = string.format(formats[user_format], actions.get_selected_entry().value)
        actions.close(prompt_bufnr)
        vim.api.nvim_put({entry}, "", true, true)
        -- TODO: prettier insert mode? <16-01-21, @noahares> --
        vim.api.nvim_feedkeys("ea", "n", true)
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension {
  setup = function(ext_config)
    depth = ext_config.depth or depth
    local custom_formats = ext_config.custom_formats or {}
    for _, format in pairs(custom_formats) do
      formats[format.id] = format.cite_marker
    end
    user_format = ext_config.format or fallback_format
    if formats[user_format] == nil then
      user_format = fallback_format
    end
  end,
  exports = {
    bibtex = bibtex_picker
  },
}
