local M = {}

-- Split a string according to a delimiter
M.split_str = function(str, delim)
  local result = {}
  for match in (str .. delim):gmatch('(.-)' .. delim) do
    table.insert(result, match)
  end
  return result
end

-- Remove unwanted char from string
M.clean_str = function(str, exp)
  if str ~= nil then
    str = str:gsub(exp, '')
  end
  return str
end

-- Replace escaped accents by proper UTF-8 char
M.clean_accents = function(str)
  -- TODO

  return str
end

-- Parse bibtex entry into a table
M.parse_entry = function(entry)
  --TODO: add type of entry and citekey
  local parsed = {}
  for _, line in pairs(entry) do
    for field, val in string.gmatch(line, '(%w+)%s*=%s*["{]*(.-)["}],?$') do
      parsed[field] = val
    end
  end
  return parsed
end

-- Format parsed entry according to template
M.format_template = function(parsed, template)
  local citation = template
  for i = 1, #parsed do
    parsed[i] = M.clean_str(parsed[i], '[%{|%}]')
  end
  local substs = {
    a = parsed.author,
    t = parsed.title,
    bt = parsed.booktitle,
    y = parsed.year,
    m = parsed.month,
    d = parsed.date,
    e = parsed.editor,
    isbn = parsed.isbn,
    l = parsed.location,
    n = parsed.number,
    p = parsed.pages,
    P = parsed.pagetotal,
    pu = parsed.publisher,
    url = parsed.url,
    vol = parsed.volume,
  }

  for k, v in pairs(substs) do
    citation = citation:gsub('{{' .. k .. '}}', v)
  end

  return citation
end

-- Replace string by initials of each word
M.make_initials = function(str, delim)
  delim = delim or ''
  local initials = ''
  local words = M.split_str(str, ' ')

  for i = 1, #words, 1 do
    initials = initials .. words[i]:gsub('[%l|%.]', '') .. delim
    if i ~= #words then
      initials = initials .. ' '
    end
  end

  return initials
end

-- Abbreviate author firstnames
M.abbrev_authors = function(parsed, opts)
  opts = opts or {}
  opts.trim_firstname = opts.trim_firstname or true
  opts.max_auth = opts.max_auth or 2

  local shortened
  local authors = {}
  local sep = ' and ' -- Authors are separated by ' and ' in bibtex entries

  for auth in string.gmatch(parsed.author .. sep, '(.-)' .. sep) do
    local lastname, firstnames = auth:match('(.*)%, (.*)')
    if opts.trim_firstname == true then
      local initials = M.make_initials(firstnames, '.')
      auth = lastname .. ', ' .. initials
    end

    table.insert(authors, auth)
  end

  if #authors > opts.max_auth then
    shortened = table.concat(authors, ', ', 1, opts.max_auth) .. ', et al.'
  elseif #authors == 1 then
    shortened = authors[1]
  else
    shortened = table.concat(authors, ', ', 1, #authors - 1)
      .. ' and '
      .. authors[#authors]
  end

  return shortened
end

return M
