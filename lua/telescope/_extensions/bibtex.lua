local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local scan = require('plenary.scandir')
local path = require('plenary.path')
local job = require('plenary.job')
local putils = require('telescope.previewers.utils')
local loop = vim.loop

local depth = 1
local formats = {}
formats['tex'] = "\\cite{%s}"
formats['md'] = "@%s"
formats['markdown'] = "@%s"
formats['plain'] = "%s"
local fallback_format = 'plain'
local use_auto_format = false
local user_format = ''
local user_files = {}
local files_initialized = false
local files = {}
local search_keys = { 'author', 'year', 'title' }
local reader = nil

local function table_contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

local function getBibFiles(dir)
  scan.scan_dir(dir, { depth = depth, search_pattern = '.*%.bib', on_insert = function(file)
    table.insert(files, {name = file, mtime = 0, entries = {}})
  end })
end

local function initFiles()
  for _,file in pairs(user_files) do
    local p = path:new(file)
    if p:is_dir() then
      getBibFiles(file)
    elseif p:is_file() then
      table.insert(files, {name = file, mtime = 0, entries = {} })
    end
  end
  getBibFiles('.')
end

local function read_file(file)
  local labels = {}
  local contents = {}
  local search_relevants = {}
  local p = path:new(file)
  if not p:exists() then return {} end
  local data = p:read()
  data = data:gsub("\r", "")
  local entries = {}
  local raw_entry = ''
  while true do
    raw_entry = data:match('@%w*%s*%b{}')
    if raw_entry == nil then
      break
    end
    table.insert(entries, raw_entry)
    data = data:sub(#raw_entry + 2)
  end
  for _,entry in pairs(entries) do
    local label = entry:match("{%s*[^{},~#%\\]+,\n")
    if (label) then
      label = vim.trim(label:gsub("\n",""):sub(2, -2))
      local content = vim.split(entry, "\n")
      table.insert(labels, label)
      contents[label] = content
      if table_contains(search_keys, [[label]]) then
        search_relevants[label]['label'] = label
      end
      search_relevants[label] = {}
      for _,key in pairs(search_keys) do
        local match_base = '%f[%w]' .. key
        local s = entry:match(match_base .. '%s*=%s*%b{}') or entry:match(match_base .. '%s*=%s*%b""') or entry:match(match_base .. '%s*=%s*%d+')
        if s ~= nil then
          s = s:match('%b{}') or s:match('%b""') or s:match('%d+')
          s = s:gsub('["{}\n]', ""):gsub('%s%s+', ' ')
          search_relevants[label][key] = vim.trim(s)
        end
      end
    end
  end
  return labels, contents, search_relevants
end

local function formatDisplay(entry)
  local display_string = ''
  local search_string = ''
  for _, val in pairs(search_keys) do
    if tonumber(entry[val]) ~= nil then
      display_string = display_string .. ' ' .. '(' .. entry[val] .. ')'
      search_string = search_string .. ' ' .. entry[val]
    elseif entry[val] ~= nil then
      display_string = display_string .. ', ' .. entry[val]
      search_string = search_string .. ' ' .. entry[val]
    end
  end
  return vim.trim(display_string:sub(2)), search_string:sub(2)
end

local function setup_picker()
  if not files_initialized then
    initFiles()
    files_initialized = true
  end
  local results = {}
  for _,file in pairs(files) do
    local mtime = loop.fs_stat(file.name).mtime.sec
    if mtime ~= file.mtime then
      file.entries = {}
      local result, content, search_relevants = read_file(file.name)
      for _,entry in pairs(result) do
	table.insert(results, { name = entry, content = content[entry], search_keys = search_relevants[entry] })
	table.insert(file.entries, { name = entry, content = content[entry], search_keys = search_relevants[entry] })
      end
      file.mtime = mtime
    else
      for _,entry in pairs(file.entries) do
        table.insert(results, entry)
      end
    end
  end
  return results
end

local function parse_format_string(opts)
  local format_string = nil
  if opts.format ~= nil then
    format_string = formats[opts.format]
  elseif use_auto_format then
    format_string = formats[vim.bo.filetype]
    if format_string == nil and vim.bo.filetype:match('markdown%.%a+') then
      format_string = formats['markdown']
    end
  end
  format_string = format_string or formats[user_format]
  return format_string
end

local function bibtex_picker(opts)
  opts = opts or {}
  local mode = vim.api.nvim_get_mode().mode
  local format_string = parse_format_string(opts)
  local results = setup_picker()
  pickers.new(opts, {
    prompt_title = 'Bibtex References',
    finder = finders.new_table {
      results = results,
      entry_maker = function(line)
        local display_string, search_string = formatDisplay(line.search_keys)
        if display_string == '' then
          display_string = line.name
        end
        if search_string == '' then
          search_string = line.name
        end
        return {
          value = search_string,
          ordinal = search_string,
          display = display_string,
          id = line,
          preview_command = function(entry, bufnr)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, results[entry.index].content)
            putils.highlighter(bufnr, 'bib')
          end,
        }
      end
    },
    previewer = previewers.display_content.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      actions.select_default:replace(key_append(format_string))
      map("i", "<c-e>", entry_append)
      map("i", "<c-o>", open_file)
      return true
    end,
  }):find()
end

key_append = function(format_string)
  return function(prompt_bufnr)
    local entry = string.format(format_string, action_state.get_selected_entry().id.name)
    actions.close(prompt_bufnr)
    if mode == "i" then
      vim.api.nvim_put({entry}, "", false, true)
      vim.api.nvim_feedkeys("a", "n", true)
    else
      vim.api.nvim_put({entry}, "", true, true)
    end
  end
end

entry_append = function(prompt_bufnr)
  local entry = action_state.get_selected_entry().id.content
  actions.close(prompt_bufnr)
  if mode == "i" then
    vim.api.nvim_put(entry, "", false, true)
    vim.api.nvim_feedkeys("a", "n", true)
  else
    vim.api.nvim_put(entry, "", true, true)
  end
end


-- Split a string using the seperator
local split = function(str, sep)
  local result={}
  for item in string.gmatch(str, "([^"..sep.."]+)") do
    table.insert(result, item)
  end
  return result
end

open_file = function(prompt_bufnr)
  local entry = action_state.get_selected_entry().id.content
  for _, line in pairs(entry) do
    local match_base = '%f[%w]file'
    local s = line:match(match_base .. '%s*=%s*%b{}') or line:match(match_base .. '%s*=%s*%b""') or line:match(match_base .. '%s*=%s*%d+')
    if s ~= nil then
      s = s:match('%b{}') or s:match('%b""') or s:match('%d+')
      s = s:gsub('["{}\n]', ""):gsub('%s%s+', ' ')
      file = split(s, ":")
      extension = string.gsub(file[3], '%s+', '')
      job:new({
        command = reader[extension],
        args = { file[2] },
        detached = true,
      }):start()
      break
    end
  end
  actions.close(prompt_bufnr)
end

return telescope.register_extension {
  setup = function(ext_config)
    reader = ext_config.reader or reader
    depth = ext_config.depth or depth
    local custom_formats = ext_config.custom_formats or {}
    for _, format in pairs(custom_formats) do
      formats[format.id] = format.cite_marker
    end
    if ext_config.format ~= nil and formats[ext_config.format] ~= nil then
      user_format = ext_config.format
    else
      user_format = fallback_format
      use_auto_format = true
    end
    user_files = ext_config.global_files or {}
    search_keys = ext_config.search_keys or search_keys
  end,
  exports = {
    bibtex = bibtex_picker,
  },
}
