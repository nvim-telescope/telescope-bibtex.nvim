local M = {}

M.file_present = function(table, filename)
  for _, file in pairs(table) do
    if file.name == filename then
      return true
    end
  end
  return false
end

M.construct_case_insensitive_pattern = function(key)
  local pattern = ''
  for char in key:gmatch('.') do
    if char:match('%a') then
      pattern = pattern
        .. '['
        .. string.lower(char)
        .. string.upper(char)
        .. ']'
    else
      pattern = pattern .. char
    end
  end
  return pattern
end

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
  str = M.clean_accents(str)
  if str ~= nil then
    str = str:gsub(exp, '')
  end

  return str
end

-- Parse bibtex entry into a table
M.parse_entry = function(entry)
  local parsed = {}
  for _, line in pairs(entry) do
    if line:sub(1, 1) == '@' then
      parsed.type = string.match(line, '^@(.-){')
      parsed.label = string.match(line, '^@.+{(.-),$')
    end
    for field, val in string.gmatch(line, '(%w+)%s*=%s*["{]*(.-)["}],?$') do
      parsed[field] = M.clean_str(val, '[%{|%}]')
    end
  end
  return parsed
end

-- Format parsed entry according to template
M.format_template = function(parsed, template)
  local citation = template

  for k, v in pairs(parsed) do
    citation = citation:gsub('{{' .. k .. '}}', v)
  end

  -- clean non-exsisting fields
  citation = M.clean_str(citation, '{{.-}}')

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

  for _, auth in pairs(M.split_str(parsed.author, sep)) do
    local lastname, firstnames = auth:match('(.*)%, (.*)')
    if firstnames == nil then
      firstnames, lastname = auth:match('(.*)% (.*)')
    end
    if opts.trim_firstname == true and firstnames ~= nil then
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

M.fileExists = function(file)
  return vim.fn.empty(vim.fn.glob(file)) == 0
end

M.bufferLines = function()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

M.extendRelativePath = function(rel_path)
  local base = vim.fn.expand('%:p:h')
  local path_sep = vim.loop.os_uname().sysname == 'Windows' and '\\' or '/'
  return base .. path_sep .. rel_path
end

M.trimWhitespace = function(str)
  return str:match('^%s*(.-)%s*$')
end

M.isLatexFile = function()
  return vim.o.filetype == 'tex'
end

M.parseLatex = function()
  local files = {}
  for _, line in ipairs(M.bufferLines()) do
    local bibs = line:match('^[^%%]*\\bibliography{(%g+)}')
    local bibresource = line:match('^[^%%]*\\addbibresource{(%g+)}')
    if bibs then
      for _, bib in ipairs(M.split_str(bibs, ',')) do
        bib = M.extendRelativePath(bib .. '.bib')
        if M.fileExists(bib) then
          table.insert(files, bib)
        end
      end
    elseif bibresource then
      bibresource = M.extendRelativePath(bibresource)
      if M.fileExists(bibresource) then
        table.insert(files, bibresource)
      end
    end
  end
  return files
end

M.isPandocFile = function()
  return vim.o.filetype == 'pandoc'
    or vim.o.filetype == 'markdown'
    or vim.o.filetype == 'md'
    or vim.o.filetype == 'rmd'
    or vim.o.filetype == 'quarto'
end

M.parsePandoc = function()
  local files = {}
  local bibStarted = false
  local bibYaml = 'bibliography:'
  for _, line in ipairs(M.bufferLines()) do
    local bibs = {}
    if bibStarted then
      local bib = line:match('- (.+)')
      if bib == nil then
        bibStarted = false
      else
        table.insert(bibs, bib)
      end
    elseif line:find(bibYaml) then
      local bib = line:match(bibYaml .. ' (.+)')
      if bib then
        for _, entry in
          ipairs(M.split_str(bib:gsub('%[', ''):gsub('%]', ''), ','))
        do
          table.insert(bibs, M.trimWhitespace(entry))
        end
      end
      bibStarted = true
    end
    for _, bib in ipairs(bibs) do
      local rel_bibs = M.extendRelativePath(bib)
      local found = nil
      if M.fileExists(bib) then
        found = bib
      elseif M.fileExists(rel_bibs) then
        found = rel_bibs
      end
      if found ~= nil then
        table.insert(files, bib)
      end
    end
  end
  return files
end

-- Replace escaped accents by proper UTF-8 char
M.clean_accents = function(str)
  -- Mapping table from Zotero translator
  -- https://github.com/zotero/translators/blob/6e82d036fd57b5e914a940d763a5f32133fa6995/BibTeX.js#L2554-L3078
  local mappingTable = {
    ['\\url'] = '', -- strip 'url'
    ['\\href'] = '', -- strip 'href'
    ['\textexclamdown'] = '¡', -- INVERTED EXCLAMATION MARK
    ['\\textcent'] = '¢', -- CENT SIGN
    ['\\textsterling'] = '£', -- POUND SIGN
    ['\\textyen'] = '¥', -- YEN SIGN
    ['\\textbrokenbar'] = 'ਆ', -- BROKEN BAR
    ['\\textsection'] = '§', -- SECTION SIGN
    ['\\textasciidieresis'] = '¨', -- DIAERESIS
    ['\\textcopyright'] = '©', -- COPYRIGHT SIGN
    ['\\textordfeminine'] = 'ª', -- FEMININE ORDINAL INDICATOR
    ['\\guillemotleft'] = '«', -- LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    ['\\textlnot'] = '¬', -- NOT SIGN
    ['\\textregistered'] = '®', -- REGISTERED SIGN
    ['\\textasciimacron'] = '¯', -- MACRON
    ['\\textdegree'] = '°', -- DEGREE SIGN
    ['\\textpm'] = '±', -- PLUS-MINUS SIGN
    ['\\texttwosuperior'] = '²', -- SUPERSCRIPT TWO
    ['\\textthreesuperior'] = '³', -- SUPERSCRIPT THREE
    ['\\textasciiacute'] = '´', -- ACUTE ACCENT
    ['\\textmu'] = 'µ', -- MICRO SIGN
    ['\\textparagraph'] = '¶', -- PILCROW SIGN
    ['\\textperiodcentered'] = '·', -- MIDDLE DOT
    ['\\c\\ '] = '¸', -- CEDILLA
    ['\\textonesuperior'] = '¹', -- SUPERSCRIPT ONE
    ['\\textordmasculine'] = 'º', -- MASCULINE ORDINAL INDICATOR
    ['\\guillemotright'] = '»', -- RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    ['\\textonequarter'] = '¼', -- VULGAR FRACTION ONE QUARTER
    ['\\textonehalf'] = '½', -- VULGAR FRACTION ONE HALF
    ['\\textthreequarters'] = '¾', -- VULGAR FRACTION THREE QUARTERS
    ['\\textquestiondown'] = '¿', -- INVERTED QUESTION MARK
    ['\\AE'] = 'Æ', -- LATIN CAPITAL LETTER AE
    ['\\DH'] = 'Ð', -- LATIN CAPITAL LETTER ETH
    ['\\texttimes'] = '×', -- MULTIPLICATION SIGN
    ['\\O'] = 'Ø', -- LATIN SMALL LETTER O WITH STROKE
    ['\\TH'] = 'Þ', -- LATIN CAPITAL LETTER THORN
    ['\\ss'] = 'ß', -- LATIN SMALL LETTER SHARP S
    ['\\ae'] = 'æ', -- LATIN SMALL LETTER AE
    ['\\dh'] = 'ð', -- LATIN SMALL LETTER ETH
    ['\\textdiv'] = '÷', -- DIVISION SIGN
    ['\\o'] = 'ø', -- LATIN SMALL LETTER O WITH STROKE
    ['\\th'] = 'þ', -- LATIN SMALL LETTER THORN
    ['\\i'] = 'ı', -- LATIN SMALL LETTER DOTLESS I
    ['\\NG'] = 'Ŋ', -- LATIN CAPITAL LETTER ENG
    ['\\ng'] = 'ŋ', -- LATIN SMALL LETTER ENG
    ['\\OE'] = 'Œ', -- LATIN CAPITAL LIGATURE OE
    ['\\oe'] = 'œ', -- LATIN SMALL LIGATURE OE
    ['\\textasciicircum'] = 'ˆ', -- MODIFIER LETTER CIRCUMFLEX ACCENT
    ['\\textacutedbl'] = '˝', -- DOUBLE ACUTE ACCENT
    ----Greek Letters Courtesy of Spartanroc
    ['%$\\Gamma%$'] = 'Γ', -- GREEK Gamma
    ['%$\\Delta%$'] = 'Δ', -- GREEK Delta
    ['%$\\Theta%$'] = 'Θ', -- GREEK Theta
    ['%$\\Lambda%$'] = 'Λ', -- GREEK Lambda
    ['%$\\Xi%$'] = 'Ξ', -- GREEK Xi
    ['%$\\Pi%$'] = 'Π', -- GREEK Pi
    ['%$\\Sigma%$'] = 'Σ', -- GREEK Sigma
    ['%$\\Phi%$'] = 'Φ', -- GREEK Phi
    ['%$\\Psi%$'] = 'Ψ', -- GREEK Psi
    ['%$\\Omega%$'] = 'Ω', -- GREEK Omega
    ['%$\\alpha%$'] = 'α', -- GREEK alpha
    ['%$\\beta%$'] = 'β', -- GREEK beta
    ['%$\\gamma%$'] = 'γ', -- GREEK gamma
    ['%$\\delta%$'] = 'δ', -- GREEK delta
    ['%$\\varepsilon%$'] = 'ε', -- GREEK var-epsilon
    ['%$\\zeta%$'] = 'ζ', -- GREEK zeta
    ['%$\\eta%$'] = 'η', -- GREEK eta
    ['%$\\theta%$'] = 'θ', -- GREEK theta
    ['%$\\iota%$'] = 'ι', -- GREEK iota
    ['%$\\kappa%$'] = 'κ', -- GREEK kappa
    ['%$\\lambda%$'] = 'λ', -- GREEK lambda
    ['%$\\mu%$'] = 'μ', -- GREEK mu
    ['%$\\nu%$'] = 'ν', -- GREEK nu
    ['%$\\xi%$'] = 'ξ', -- GREEK xi
    ['%$\\pi%$'] = 'π', -- GREEK pi
    ['%$\\rho%$'] = 'ρ', -- GREEK rho
    ['%$\\varsigma%$'] = 'ς', -- GREEK var-sigma
    ['%$\\sigma%$'] = 'σ', -- GREEK sigma
    ['%$\\tau%$'] = 'τ', -- GREEK tau
    ['%$\\upsilon%$'] = 'υ', -- GREEK upsilon
    ['%$\\varphi%$'] = 'φ', -- GREEK var-phi
    ['%$\\chi%$'] = 'χ', -- GREEK chi
    ['%$\\psi%$'] = 'ψ', -- GREEK psi
    ['%$\\omega%$'] = 'ω', -- GREEK omega
    ['%$\\vartheta%$'] = 'ϑ', -- GREEK var-theta
    ['%$\\Upsilon%$'] = 'ϒ', -- GREEK Upsilon
    ['%$\\phi%$'] = 'ϕ', -- GREEK phi
    ['%$\\varpi%$'] = 'ϖ', -- GREEK var-pi
    ['%$\\varrho%$'] = 'ϱ', -- GREEK var-rho
    ['%$\\epsilon%$'] = 'ϵ', -- GREEK epsilon
    --Greek letters end
    ['\\textendash'] = '–', -- EN DASH
    ['\\textemdash'] = '—', -- EM DASH
    ['%-%-%-'] = '—', -- EM DASH
    ['%-%-'] = '–', -- EN DASH
    ['\\textbardbl'] = '‖', -- DOUBLE VERTICAL LINE
    ['\\textunderscore'] = '‗', -- DOUBLE LOW LINE
    ['\\textquoteleft'] = '‘', -- LEFT SINGLE QUOTATION MARK
    ['\\textquoteright'] = '’', -- RIGHT SINGLE QUOTATION MARK
    ['\\textquotesingle'] = "'", -- APOSTROPHE / NEUTRAL SINGLE QUOTATION MARK
    ['\\quotesinglbase'] = '‚', -- SINGLE LOW-9 QUOTATION MARK
    ['\\textquotedblleft'] = '“', -- LEFT DOUBLE QUOTATION MARK
    ['\\textquotedblright'] = '”', -- RIGHT DOUBLE QUOTATION MARK
    ['\\quotedblbase'] = '„', -- DOUBLE LOW-9 QUOTATION MARK
    ['\\textdagger'] = '†', -- DAGGER
    ['\\textdaggerdbl'] = '‡', -- DOUBLE DAGGER
    ['\\textbullet'] = '•', -- BULLET
    ['\\textellipsis'] = '…', -- HORIZONTAL ELLIPSIS
    ['\\textperthousand'] = '‰', -- PER MILLE SIGN
    ["'''"] = '‴', -- TRIPLE PRIME
    ["''"] = '”', -- RIGHT DOUBLE QUOTATION MARK (could be a double prime)
    ['``'] = '“', -- LEFT DOUBLE QUOTATION MARK (could be a reversed double prime)
    ['```'] = '‷', -- REVERSED TRIPLE PRIME
    ['\\guilsinglleft'] = '‹', -- SINGLE LEFT-POINTING ANGLE QUOTATION MARK
    ['\\guilsinglright'] = '›', -- SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    ['!!'] = '‼', -- DOUBLE EXCLAMATION MARK
    ['\\textfractionsolidus'] = '⁄', -- FRACTION SLASH
    ['%?!'] = '⁈', -- QUESTION EXCLAMATION MARK
    ['!%?'] = '⁉', -- EXCLAMATION QUESTION MARK
    ['%$%^%{0%}%$'] = '⁰', -- SUPERSCRIPT ZERO
    ['%$%^%{4%}%$'] = '⁴', -- SUPERSCRIPT FOUR
    ['%$%^%{5%}%$'] = '⁵', -- SUPERSCRIPT FIVE
    ['%$%^%{6%}%$'] = '⁶', -- SUPERSCRIPT SIX
    ['%$%^%{7%}%$'] = '⁷', -- SUPERSCRIPT SEVEN
    ['%$%^%{8%}%$'] = '⁸', -- SUPERSCRIPT EIGHT
    ['%$%^%{9%}%$'] = '⁹', -- SUPERSCRIPT NINE
    ['%$%^%{%+%}%$'] = '⁺', -- SUPERSCRIPT PLUS SIGN
    ['%$%^%{%-%}%$'] = '⁻', -- SUPERSCRIPT MINUS
    ['%$%^%{=%}%$'] = '⁼', -- SUPERSCRIPT EQUALS SIGN
    ['%$%^%{%(%}%$'] = '⁽', -- SUPERSCRIPT LEFT PARENTHESIS
    ['%$%^%{%)%}%$'] = '⁾', -- SUPERSCRIPT RIGHT PARENTHESIS
    ['%$%^%{n%}%$'] = 'ⁿ', -- SUPERSCRIPT LATIN SMALL LETTER N
    ['%$_%{0%}%$'] = '₀', -- SUBSCRIPT ZERO
    ['%$_%{1%}%$'] = '₁', -- SUBSCRIPT ONE
    ['%$_%{2%}%$'] = '₂', -- SUBSCRIPT TWO
    ['%$_%{3%}%$'] = '₃', -- SUBSCRIPT THREE
    ['%$_%{4%}%$'] = '₄', -- SUBSCRIPT FOUR
    ['%$_%{5%}%$'] = '₅', -- SUBSCRIPT FIVE
    ['%$_%{6%}%$'] = '₆', -- SUBSCRIPT SIX
    ['%$_%{7%}%$'] = '₇', -- SUBSCRIPT SEVEN
    ['%$_%{8%}%$'] = '₈', -- SUBSCRIPT EIGHT
    ['%$_%{9%}%$'] = '₉', -- SUBSCRIPT NINE
    ['%$_%{%+%}%$'] = '₊', -- SUBSCRIPT PLUS SIGN
    ['%$_%{%-%}%$'] = '₋', -- SUBSCRIPT MINUS
    ['%$_%{=%}%$'] = '₌', -- SUBSCRIPT EQUALS SIGN
    ['%$_%{%(%}%$'] = '₍', -- SUBSCRIPT LEFT PARENTHESIS
    ['%$_%{%)%}%$'] = '₎', -- SUBSCRIPT RIGHT PARENTHESIS
    ['\\texteuro'] = '€', -- EURO SIGN
    ['\\textcelsius'] = '℃', -- DEGREE CELSIUS
    ['\\textnumero'] = '№', -- NUMERO SIGN
    ['\\textcircledP'] = '℗', -- SOUND RECORDING COPYRIGHT
    ['\\textservicemark'] = '℠', -- SERVICE MARK
    ['\\texttrademark'] = '™', -- TRADE MARK SIGN
    ['\\textohm'] = 'Ω', -- OHM SIGN
    ['\\textestimated'] = '℮', -- ESTIMATED SYMBOL
    ['\\textleftarrow'] = '←', -- LEFTWARDS ARROW
    ['\\textuparrow'] = '↑', -- UPWARDS ARROW
    ['\\textrightarrow'] = '→', -- RIGHTWARDS ARROW
    ['\\textdownarrow'] = '↓', -- DOWNWARDS ARROW
    ['%$\\infty%$'] = '∞', -- INFINITY
    ['%$\\%#%$'] = '⋕', -- EQUAL AND PARALLEL TO
    ['\\textlangle'] = '〈', -- LEFT-POINTING ANGLE BRACKET
    ['\\textrangle'] = '〉', -- RIGHT-POINTING ANGLE BRACKET
    ['\\textvisiblespace'] = '␣', -- OPEN BOX
    ['\\textopenbullet'] = '◦', -- WHITE BULLET
    ['%$\\%%%<%$'] = '✁', -- UPPER BLADE SCISSORS
    --Derived accented characters
    ['\\`A'] = 'À', -- LATIN CAPITAL LETTER A WITH GRAVE
    ["\\'A"] = 'Á', -- LATIN CAPITAL LETTER A WITH ACUTE
    ['\\%^A'] = 'Â', -- LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    ['\\~A'] = 'Ã', -- LATIN CAPITAL LETTER A WITH TILDE
    ['\\"A'] = 'Ä', -- LATIN CAPITAL LETTER A WITH DIAERESIS
    ['\\r A'] = 'Å', -- LATIN CAPITAL LETTER A WITH RING ABOVE
    ['\\AA'] = 'Æ', -- LATIN CAPITAL LETTER A WITH RING ABOVE
    ['\\c C'] = 'Ç', -- LATIN CAPITAL LETTER C WITH CEDILLA
    ['\\`E'] = 'È', -- LATIN CAPITAL LETTER E WITH GRAVE
    ["\\'E"] = 'É', -- LATIN CAPITAL LETTER E WITH ACUTE
    ['\\%^E'] = 'Ê', -- LATIN CAPITAL LETTER E WITH CIRCUMFLEX
    ['\\"E'] = 'Ë', -- LATIN CAPITAL LETTER E WITH DIAERESIS
    ['\\`I'] = 'Ì', -- LATIN CAPITAL LETTER I WITH GRAVE
    ["\\'I"] = 'Í', -- LATIN CAPITAL LETTER I WITH ACUTE
    ['\\%^I'] = 'Î', -- LATIN CAPITAL LETTER I WITH CIRCUMFLEX
    ['\\"I'] = 'Ï', -- LATIN CAPITAL LETTER I WITH DIAERESIS
    ['\\~N'] = 'Ñ', -- LATIN CAPITAL LETTER N WITH TILDE
    ['\\`O'] = 'Ò', -- LATIN CAPITAL LETTER O WITH GRAVE
    ["\\'O"] = 'Ó', -- LATIN CAPITAL LETTER O WITH ACUTE
    ['\\%^O'] = 'Ô', -- LATIN CAPITAL LETTER O WITH CIRCUMFLEX
    ['\\~O'] = 'Õ', -- LATIN CAPITAL LETTER O WITH TILDE
    ['\\"O'] = 'Ö', -- LATIN CAPITAL LETTER O WITH DIAERESIS
    ['\\`U'] = 'Ù', -- LATIN CAPITAL LETTER U WITH GRAVE
    ["\\'U"] = 'Ú', -- LATIN CAPITAL LETTER U WITH ACUTE
    ['\\%^U'] = 'Û', -- LATIN CAPITAL LETTER U WITH CIRCUMFLEX
    ['\\"U'] = 'Ü', -- LATIN CAPITAL LETTER U WITH DIAERESIS
    ["\\'Y"] = 'Ý', -- LATIN CAPITAL LETTER Y WITH ACUTE
    ['\\`a'] = 'à', -- LATIN SMALL LETTER A WITH GRAVE
    ["\\'a"] = 'á', -- LATIN SMALL LETTER A WITH ACUTE
    ['\\%^a'] = 'â', -- LATIN SMALL LETTER A WITH CIRCUMFLEX
    ['\\~a'] = 'ã', -- LATIN SMALL LETTER A WITH TILDE
    ['\\"a'] = 'ä', -- LATIN SMALL LETTER A WITH DIAERESIS
    ['\\r a'] = 'å', -- LATIN SMALL LETTER A WITH RING ABOVE
    ['\\aa'] = 'æ', -- LATIN SMALL LETTER A WITH RING ABOVE
    ['\\c c'] = 'ç', -- LATIN SMALL LETTER C WITH CEDILLA
    ['\\`e'] = 'è', -- LATIN SMALL LETTER E WITH GRAVE
    ["\\'e"] = 'é', -- LATIN SMALL LETTER E WITH ACUTE
    ['\\%^e'] = 'ê', -- LATIN SMALL LETTER E WITH CIRCUMFLEX
    ['\\"e'] = 'ë', -- LATIN SMALL LETTER E WITH DIAERESIS
    ['\\`i'] = 'ì', -- LATIN SMALL LETTER I WITH GRAVE
    ["\\'i"] = 'í', -- LATIN SMALL LETTER I WITH ACUTE
    ['\\%^i'] = 'î', -- LATIN SMALL LETTER I WITH CIRCUMFLEX
    ['\\"i'] = 'ï', -- LATIN SMALL LETTER I WITH DIAERESIS
    ['\\~n'] = 'ñ', -- LATIN SMALL LETTER N WITH TILDE
    ['\\`o'] = 'ò', -- LATIN SMALL LETTER O WITH GRAVE
    ["\\'o"] = 'ó', -- LATIN SMALL LETTER O WITH ACUTE
    ['\\%^o'] = 'ô', -- LATIN SMALL LETTER O WITH CIRCUMFLEX
    ['\\~o'] = 'õ', -- LATIN SMALL LETTER O WITH TILDE
    ['\\"o'] = 'ö', -- LATIN SMALL LETTER O WITH DIAERESIS
    ['\\`u'] = 'ù', -- LATIN SMALL LETTER U WITH GRAVE
    ["\\'u"] = 'ú', -- LATIN SMALL LETTER U WITH ACUTE
    ['\\%^u'] = 'û', -- LATIN SMALL LETTER U WITH CIRCUMFLEX
    ['\\"u'] = 'ü', -- LATIN SMALL LETTER U WITH DIAERESIS
    ["\\'y"] = 'ý', -- LATIN SMALL LETTER Y WITH ACUTE
    ['\\"y'] = 'ÿ', -- LATIN SMALL LETTER Y WITH DIAERESIS
    ['\\=A'] = 'Ā', -- LATIN CAPITAL LETTER A WITH MACRON
    ['\\=a'] = 'ā', -- LATIN SMALL LETTER A WITH MACRON
    ['\\u A'] = 'Ă', -- LATIN CAPITAL LETTER A WITH BREVE
    ['\\u a'] = 'ă', -- LATIN SMALL LETTER A WITH BREVE
    ['\\k A'] = 'Ą', -- LATIN CAPITAL LETTER A WITH OGONEK
    ['\\k a'] = 'ą', -- LATIN SMALL LETTER A WITH OGONEK
    ["\\'C"] = 'Ć', -- LATIN CAPITAL LETTER C WITH ACUTE
    ["\\'c"] = 'ć', -- LATIN SMALL LETTER C WITH ACUTE
    ['\\%^C'] = 'Ĉ', -- LATIN CAPITAL LETTER C WITH CIRCUMFLEX
    ['\\%^c'] = 'ĉ', -- LATIN SMALL LETTER C WITH CIRCUMFLEX
    ['\\%.C'] = 'Ċ', -- LATIN CAPITAL LETTER C WITH DOT ABOVE
    ['\\%.c'] = 'ċ', -- LATIN SMALL LETTER C WITH DOT ABOVE
    ['\\v C'] = 'Č', -- LATIN CAPITAL LETTER C WITH CARON
    ['\\v c'] = 'č', -- LATIN SMALL LETTER C WITH CARON
    ['\\v D'] = 'Ď', -- LATIN CAPITAL LETTER D WITH CARON
    ['\\v d'] = 'ď', -- LATIN SMALL LETTER D WITH CARON
    ['\\=E'] = 'Ē', -- LATIN CAPITAL LETTER E WITH MACRON
    ['\\=e'] = 'ē', -- LATIN SMALL LETTER E WITH MACRON
    ['\\u E'] = 'Ĕ', -- LATIN CAPITAL LETTER E WITH BREVE
    ['\\u e'] = 'ĕ', -- LATIN SMALL LETTER E WITH BREVE
    ['\\%.E'] = 'Ė', -- LATIN CAPITAL LETTER E WITH DOT ABOVE
    ['\\%.e'] = 'ė', -- LATIN SMALL LETTER E WITH DOT ABOVE
    ['\\k E'] = 'Ę', -- LATIN CAPITAL LETTER E WITH OGONEK
    ['\\k e'] = 'ę', -- LATIN SMALL LETTER E WITH OGONEK
    ['\\v E'] = 'Ě', -- LATIN CAPITAL LETTER E WITH CARON
    ['\\v e'] = 'ě', -- LATIN SMALL LETTER E WITH CARON
    ['\\%^G'] = 'Ĝ', -- LATIN CAPITAL LETTER G WITH CIRCUMFLEX
    ['\\%^g'] = 'ĝ', -- LATIN SMALL LETTER G WITH CIRCUMFLEX
    ['\\u G'] = 'Ğ', -- LATIN CAPITAL LETTER G WITH BREVE
    ['\\u g'] = 'ğ', -- LATIN SMALL LETTER G WITH BREVE
    ['\\%.G'] = 'Ġ', -- LATIN CAPITAL LETTER G WITH DOT ABOVE
    ['\\%.g'] = 'ġ', -- LATIN SMALL LETTER G WITH DOT ABOVE
    ['\\c G'] = 'Ģ', -- LATIN CAPITAL LETTER G WITH CEDILLA
    ['\\c g'] = 'ģ', -- LATIN SMALL LETTER G WITH CEDILLA
    ['\\%^H'] = 'Ĥ', -- LATIN CAPITAL LETTER H WITH CIRCUMFLEX
    ['\\%^h'] = 'ĥ', -- LATIN SMALL LETTER H WITH CIRCUMFLEX
    ['\\~I'] = 'Ĩ', -- LATIN CAPITAL LETTER I WITH TILDE
    ['\\~i'] = 'ĩ', -- LATIN SMALL LETTER I WITH TILDE
    ['\\=I'] = 'Ī', -- LATIN CAPITAL LETTER I WITH MACRON
    ['\\=i'] = 'ī', -- LATIN SMALL LETTER I WITH MACRON
    ['\\=\\i'] = 'ī', -- LATIN SMALL LETTER I WITH MACRON
    ['\\u I'] = 'Ĭ', -- LATIN CAPITAL LETTER I WITH BREVE
    ['\\u i'] = 'ĭ', -- LATIN SMALL LETTER I WITH BREVE
    ['\\k I'] = 'Į', -- LATIN CAPITAL LETTER I WITH OGONEK
    ['\\k i'] = 'į', -- LATIN SMALL LETTER I WITH OGONEK
    ['\\%.I'] = 'İ', -- LATIN CAPITAL LETTER I WITH DOT ABOVE
    ['\\%^J'] = 'Ĵ', -- LATIN CAPITAL LETTER J WITH CIRCUMFLEX
    ['\\%^j'] = 'ĵ', -- LATIN SMALL LETTER J WITH CIRCUMFLEX
    ['\\c K'] = 'Ķ', -- LATIN CAPITAL LETTER K WITH CEDILLA
    ['\\c k'] = 'ķ', -- LATIN SMALL LETTER K WITH CEDILLA
    ["\\'L"] = 'Ĺ', -- LATIN CAPITAL LETTER L WITH ACUTE
    ["\\'l"] = 'ĺ', -- LATIN SMALL LETTER L WITH ACUTE
    ['\\c L'] = 'Ļ', -- LATIN CAPITAL LETTER L WITH CEDILLA
    ['\\c l'] = 'ļ', -- LATIN SMALL LETTER L WITH CEDILLA
    ['\\v L'] = 'Ľ', -- LATIN CAPITAL LETTER L WITH CARON
    ['\\v l'] = 'ľ', -- LATIN SMALL LETTER L WITH CARON
    ['\\L '] = 'Ł', --LATIN CAPITAL LETTER L WITH STROKE
    ['\\l '] = 'ł', --LATIN SMALL LETTER L WITH STROKE
    ["\\'N"] = 'Ń', -- LATIN CAPITAL LETTER N WITH ACUTE
    ["\\'n"] = 'ń', -- LATIN SMALL LETTER N WITH ACUTE
    ['\\c N'] = 'Ņ', -- LATIN CAPITAL LETTER N WITH CEDILLA
    ['\\c n'] = 'ņ', -- LATIN SMALL LETTER N WITH CEDILLA
    ['\\v N'] = 'Ň', -- LATIN CAPITAL LETTER N WITH CARON
    ['\\v n'] = 'ň', -- LATIN SMALL LETTER N WITH CARON
    ['\\=O'] = 'Ō', -- LATIN CAPITAL LETTER O WITH MACRON
    ['\\=o'] = 'ō', -- LATIN SMALL LETTER O WITH MACRON
    ['\\u O'] = 'Ŏ', -- LATIN CAPITAL LETTER O WITH BREVE
    ['\\u o'] = 'ŏ', -- LATIN SMALL LETTER O WITH BREVE
    ['\\H O'] = 'Ő', -- LATIN CAPITAL LETTER O WITH DOUBLE ACUTE
    ['\\H o'] = 'ő', -- LATIN SMALL LETTER O WITH DOUBLE ACUTE
    ["\\'R"] = 'Ŕ', -- LATIN CAPITAL LETTER R WITH ACUTE
    ["\\'r"] = 'ŕ', -- LATIN SMALL LETTER R WITH ACUTE
    ['\\c R'] = 'Ŗ', -- LATIN CAPITAL LETTER R WITH CEDILLA
    ['\\c r'] = 'ŗ', -- LATIN SMALL LETTER R WITH CEDILLA
    ['\\v R'] = 'Ř', -- LATIN CAPITAL LETTER R WITH CARON
    ['\\v r'] = 'ř', -- LATIN SMALL LETTER R WITH CARON
    ["\\'S"] = 'Ś', -- LATIN CAPITAL LETTER S WITH ACUTE
    ["\\'s"] = 'ś', -- LATIN SMALL LETTER S WITH ACUTE
    ['\\%^S'] = 'Ŝ', -- LATIN CAPITAL LETTER S WITH CIRCUMFLEX
    ['\\%^s'] = 'ŝ', -- LATIN SMALL LETTER S WITH CIRCUMFLEX
    ['\\c S'] = 'Ş', -- LATIN CAPITAL LETTER S WITH CEDILLA
    ['\\c s'] = 'ş', -- LATIN SMALL LETTER S WITH CEDILLA
    ['\\v S'] = 'Š', -- LATIN CAPITAL LETTER S WITH CARON
    ['\\v s'] = 'š', -- LATIN SMALL LETTER S WITH CARON
    ['\\c T'] = 'Ţ', -- LATIN CAPITAL LETTER T WITH CEDILLA
    ['\\c t'] = 'ţ', -- LATIN SMALL LETTER T WITH CEDILLA
    ['\\v T'] = 'Ť', -- LATIN CAPITAL LETTER T WITH CARON
    ['\\v t'] = 'ť', -- LATIN SMALL LETTER T WITH CARON
    ['\\~U'] = 'Ũ', -- LATIN CAPITAL LETTER U WITH TILDE
    ['\\~u'] = 'ũ', -- LATIN SMALL LETTER U WITH TILDE
    ['\\=U'] = 'Ū', -- LATIN CAPITAL LETTER U WITH MACRON
    ['\\=u'] = 'ū', -- LATIN SMALL LETTER U WITH MACRON
    ['\\u U'] = 'Ŭ', -- LATIN CAPITAL LETTER U WITH BREVE
    ['\\u u'] = 'ŭ', -- LATIN SMALL LETTER U WITH BREVE
    ['\\r U'] = 'Ů', -- LATIN CAPITAL LETTER U WITH RING ABOVE
    ['\\r u'] = 'ů', -- LATIN SMALL LETTER U WITH RING ABOVE
    ['\\H U'] = 'Ű', -- LATIN CAPITAL LETTER U WITH DOUBLE ACUTE
    ['\\H u'] = 'ű', -- LATIN SMALL LETTER U WITH DOUBLE ACUTE
    ['\\k U'] = 'Ų', -- LATIN CAPITAL LETTER U WITH OGONEK
    ['\\k u'] = 'ų', -- LATIN SMALL LETTER U WITH OGONEK
    ['\\%^W'] = 'Ŵ', -- LATIN CAPITAL LETTER W WITH CIRCUMFLEX
    ['\\%^w'] = 'ŵ', -- LATIN SMALL LETTER W WITH CIRCUMFLEX
    ['\\%^Y'] = 'Ŷ', -- LATIN CAPITAL LETTER Y WITH CIRCUMFLEX
    ['\\%^y'] = 'ŷ', -- LATIN SMALL LETTER Y WITH CIRCUMFLEX
    ['\\"Y'] = 'Ÿ', -- LATIN CAPITAL LETTER Y WITH DIAERESIS
    ["\\'Z"] = 'Ź', -- LATIN CAPITAL LETTER Z WITH ACUTE
    ["\\'z"] = 'ź', -- LATIN SMALL LETTER Z WITH ACUTE
    ['\\%.Z'] = 'Ż', -- LATIN CAPITAL LETTER Z WITH DOT ABOVE
    ['\\%.z'] = 'ż', -- LATIN SMALL LETTER Z WITH DOT ABOVE
    ['\\v Z'] = 'Ž', -- LATIN CAPITAL LETTER Z WITH CARON
    ['\\v z'] = 'ž', -- LATIN SMALL LETTER Z WITH CARON
    ['\\v A'] = 'Ǎ', -- LATIN CAPITAL LETTER A WITH CARON
    ['\\v a'] = 'ǎ', -- LATIN SMALL LETTER A WITH CARON
    ['\\v I'] = 'Ǐ', -- LATIN CAPITAL LETTER I WITH CARON
    ['\\v i'] = 'ǐ', -- LATIN SMALL LETTER I WITH CARON
    ['\\v O'] = 'Ǒ', -- LATIN CAPITAL LETTER O WITH CARON
    ['\\v o'] = 'ǒ', -- LATIN SMALL LETTER O WITH CARON
    ['\\v U'] = 'Ǔ', -- LATIN CAPITAL LETTER U WITH CARON
    ['\\v u'] = 'ǔ', -- LATIN SMALL LETTER U WITH CARON
    ['\\v G'] = 'Ǧ', -- LATIN CAPITAL LETTER G WITH CARON
    ['\\v g'] = 'ǧ', -- LATIN SMALL LETTER G WITH CARON
    ['\\v K'] = 'Ǩ', -- LATIN CAPITAL LETTER K WITH CARON
    ['\\v k'] = 'ǩ', -- LATIN SMALL LETTER K WITH CARON
    ['\\k O'] = 'Ǫ', -- LATIN CAPITAL LETTER O WITH OGONEK
    ['\\k o'] = 'ǫ', -- LATIN SMALL LETTER O WITH OGONEK
    ['\\v j'] = 'ǰ', -- LATIN SMALL LETTER J WITH CARON
    ["\\'G"] = 'Ǵ', -- LATIN CAPITAL LETTER G WITH ACUTE
    ["\\'g"] = 'ǵ', -- LATIN SMALL LETTER G WITH ACUTE
    ['\\%.B'] = 'Ḃ', -- LATIN CAPITAL LETTER B WITH DOT ABOVE
    ['\\%.b'] = 'ḃ', -- LATIN SMALL LETTER B WITH DOT ABOVE
    ['\\d B'] = 'Ḅ', -- LATIN CAPITAL LETTER B WITH DOT BELOW
    ['\\d b'] = 'ḅ', -- LATIN SMALL LETTER B WITH DOT BELOW
    ['\\b B'] = 'Ḇ', -- LATIN CAPITAL LETTER B WITH LINE BELOW
    ['\\b b'] = 'ḇ', -- LATIN SMALL LETTER B WITH LINE BELOW
    ['\\%.D'] = 'Ḋ', -- LATIN CAPITAL LETTER D WITH DOT ABOVE
    ['\\%.d'] = 'ḋ', -- LATIN SMALL LETTER D WITH DOT ABOVE
    ['\\d D'] = 'Ḍ', -- LATIN CAPITAL LETTER D WITH DOT BELOW
    ['\\d d'] = 'ḍ', -- LATIN SMALL LETTER D WITH DOT BELOW
    ['\\b D'] = 'Ḏ', -- LATIN CAPITAL LETTER D WITH LINE BELOW
    ['\\b d'] = 'ḏ', -- LATIN SMALL LETTER D WITH LINE BELOW
    ['\\c D'] = 'Ḑ', -- LATIN CAPITAL LETTER D WITH CEDILLA
    ['\\c d'] = 'ḑ', -- LATIN SMALL LETTER D WITH CEDILLA
    ['\\%.F'] = 'Ḟ', -- LATIN CAPITAL LETTER F WITH DOT ABOVE
    ['\\%.f'] = 'ḟ', -- LATIN SMALL LETTER F WITH DOT ABOVE
    ['\\=G'] = 'Ḡ', -- LATIN CAPITAL LETTER G WITH MACRON
    ['\\=g'] = 'ḡ', -- LATIN SMALL LETTER G WITH MACRON
    ['\\%.H'] = 'Ḣ', -- LATIN CAPITAL LETTER H WITH DOT ABOVE
    ['\\%.h'] = 'ḣ', -- LATIN SMALL LETTER H WITH DOT ABOVE
    ['\\d H'] = 'Ḥ', -- LATIN CAPITAL LETTER H WITH DOT BELOW
    ['\\d h'] = 'ḥ', -- LATIN SMALL LETTER H WITH DOT BELOW
    ['\\"H'] = 'Ḧ', -- LATIN CAPITAL LETTER H WITH DIAERESIS
    ['\\"h'] = 'ḧ', -- LATIN SMALL LETTER H WITH DIAERESIS
    ['\\c H'] = 'Ḩ', -- LATIN CAPITAL LETTER H WITH CEDILLA
    ['\\c h'] = 'ḩ', -- LATIN SMALL LETTER H WITH CEDILLA
    ["\\'K"] = 'Ḱ', -- LATIN CAPITAL LETTER K WITH ACUTE
    ["\\'k"] = 'ḱ', -- LATIN SMALL LETTER K WITH ACUTE
    ['\\d K'] = 'Ḳ', -- LATIN CAPITAL LETTER K WITH DOT BELOW
    ['\\d k'] = 'ḳ', -- LATIN SMALL LETTER K WITH DOT BELOW
    ['\\b K'] = 'Ḵ', -- LATIN CAPITAL LETTER K WITH LINE BELOW
    ['\\b k'] = 'ḵ', -- LATIN SMALL LETTER K WITH LINE BELOW
    ['\\d L'] = 'Ḷ', -- LATIN CAPITAL LETTER L WITH DOT BELOW
    ['\\d l'] = 'ḷ', -- LATIN SMALL LETTER L WITH DOT BELOW
    ['\\b L'] = 'Ḻ', -- LATIN CAPITAL LETTER L WITH LINE BELOW
    ['\\b l'] = 'ḻ', -- LATIN SMALL LETTER L WITH LINE BELOW
    ["\\'M"] = 'Ḿ', -- LATIN CAPITAL LETTER M WITH ACUTE
    ["\\'m"] = 'ḿ', -- LATIN SMALL LETTER M WITH ACUTE
    ['\\%.M'] = 'Ṁ', -- LATIN CAPITAL LETTER M WITH DOT ABOVE
    ['\\%.m'] = 'ṁ', -- LATIN SMALL LETTER M WITH DOT ABOVE
    ['\\d M'] = 'Ṃ', -- LATIN CAPITAL LETTER M WITH DOT BELOW
    ['\\d m'] = 'ṃ', -- LATIN SMALL LETTER M WITH DOT BELOW
    ['\\%.N'] = 'Ṅ', -- LATIN CAPITAL LETTER N WITH DOT ABOVE
    ['\\%.n'] = 'ṅ', -- LATIN SMALL LETTER N WITH DOT ABOVE
    ['\\d N'] = 'Ṇ', -- LATIN CAPITAL LETTER N WITH DOT BELOW
    ['\\d n'] = 'ṇ', -- LATIN SMALL LETTER N WITH DOT BELOW
    ['\\b N'] = 'Ṉ', -- LATIN CAPITAL LETTER N WITH LINE BELOW
    ['\\b n'] = 'ṉ', -- LATIN SMALL LETTER N WITH LINE BELOW
    ["\\'P"] = 'Ṕ', -- LATIN CAPITAL LETTER P WITH ACUTE
    ["\\'p"] = 'ṕ', -- LATIN SMALL LETTER P WITH ACUTE
    ['\\%.P'] = 'Ṗ', -- LATIN CAPITAL LETTER P WITH DOT ABOVE
    ['\\%.p'] = 'ṗ', -- LATIN SMALL LETTER P WITH DOT ABOVE
    ['\\%.R'] = 'Ṙ', -- LATIN CAPITAL LETTER R WITH DOT ABOVE
    ['\\%.r'] = 'ṙ', -- LATIN SMALL LETTER R WITH DOT ABOVE
    ['\\d R'] = 'Ṛ', -- LATIN CAPITAL LETTER R WITH DOT BELOW
    ['\\d r'] = 'ṛ', -- LATIN SMALL LETTER R WITH DOT BELOW
    ['\\b R'] = 'Ṟ', -- LATIN CAPITAL LETTER R WITH LINE BELOW
    ['\\b r'] = 'ṟ', -- LATIN SMALL LETTER R WITH LINE BELOW
    ['\\%.S'] = 'Ṡ', -- LATIN CAPITAL LETTER S WITH DOT ABOVE
    ['\\%.s'] = 'ṡ', -- LATIN SMALL LETTER S WITH DOT ABOVE
    ['\\d S'] = 'Ṣ', -- LATIN CAPITAL LETTER S WITH DOT BELOW
    ['\\d s'] = 'ṣ', -- LATIN SMALL LETTER S WITH DOT BELOW
    ['\\%.T'] = 'Ṫ', -- LATIN CAPITAL LETTER T WITH DOT ABOVE
    ['\\%.t'] = 'ṫ', -- LATIN SMALL LETTER T WITH DOT ABOVE
    ['\\d T'] = 'Ṭ', -- LATIN CAPITAL LETTER T WITH DOT BELOW
    ['\\d t'] = 'ṭ', -- LATIN SMALL LETTER T WITH DOT BELOW
    ['\\b T'] = 'Ṯ', -- LATIN CAPITAL LETTER T WITH LINE BELOW
    ['\\b t'] = 'ṯ', -- LATIN SMALL LETTER T WITH LINE BELOW
    ['\\~V'] = 'Ṽ', -- LATIN CAPITAL LETTER V WITH TILDE
    ['\\~v'] = 'ṽ', -- LATIN SMALL LETTER V WITH TILDE
    ['\\d V'] = 'Ṿ', -- LATIN CAPITAL LETTER V WITH DOT BELOW
    ['\\d v'] = 'ṿ', -- LATIN SMALL LETTER V WITH DOT BELOW
    ['\\`W'] = 'Ẁ', -- LATIN CAPITAL LETTER W WITH GRAVE
    ['\\`w'] = 'ẁ', -- LATIN SMALL LETTER W WITH GRAVE
    ["\\'W"] = 'Ẃ', -- LATIN CAPITAL LETTER W WITH ACUTE
    ["\\'w"] = 'ẃ', -- LATIN SMALL LETTER W WITH ACUTE
    ['\\"W'] = 'Ẅ', -- LATIN CAPITAL LETTER W WITH DIAERESIS
    ['\\"w'] = 'ẅ', -- LATIN SMALL LETTER W WITH DIAERESIS
    ['\\%.W'] = 'Ẇ', -- LATIN CAPITAL LETTER W WITH DOT ABOVE
    ['\\%.w'] = 'ẇ', -- LATIN SMALL LETTER W WITH DOT ABOVE
    ['\\d W'] = 'Ẉ', -- LATIN CAPITAL LETTER W WITH DOT BELOW
    ['\\d w'] = 'ẉ', -- LATIN SMALL LETTER W WITH DOT BELOW
    ['\\%.X'] = 'Ẋ', -- LATIN CAPITAL LETTER X WITH DOT ABOVE
    ['\\%.x'] = 'ẋ', -- LATIN SMALL LETTER X WITH DOT ABOVE
    ['\\"X'] = 'Ẍ', -- LATIN CAPITAL LETTER X WITH DIAERESIS
    ['\\"x'] = 'ẍ', -- LATIN SMALL LETTER X WITH DIAERESIS
    ['\\%.Y'] = 'Ẏ', -- LATIN CAPITAL LETTER Y WITH DOT ABOVE
    ['\\%.y'] = 'ẏ', -- LATIN SMALL LETTER Y WITH DOT ABOVE
    ['\\%^Z'] = 'Ẑ', -- LATIN CAPITAL LETTER Z WITH CIRCUMFLEX
    ['\\%^z'] = 'ẑ', -- LATIN SMALL LETTER Z WITH CIRCUMFLEX
    ['\\d Z'] = 'Ẓ', -- LATIN CAPITAL LETTER Z WITH DOT BELOW
    ['\\d z'] = 'ẓ', -- LATIN SMALL LETTER Z WITH DOT BELOW
    ['\\b Z'] = 'Ẕ', -- LATIN CAPITAL LETTER Z WITH LINE BELOW
    ['\\b z'] = 'ẕ', -- LATIN SMALL LETTER Z WITH LINE BELOW
    ['\\b h'] = 'ẖ', -- LATIN SMALL LETTER H WITH LINE BELOW
    ['\\"t'] = 'ẗ', -- LATIN SMALL LETTER T WITH DIAERESIS
    ['\\r w'] = 'ẘ', -- LATIN SMALL LETTER W WITH RING ABOVE
    ['\\r y'] = 'ẙ', -- LATIN SMALL LETTER Y WITH RING ABOVE
    ['\\d A'] = 'Ạ', -- LATIN CAPITAL LETTER A WITH DOT BELOW
    ['\\d a'] = 'ạ', -- LATIN SMALL LETTER A WITH DOT BELOW
    ['\\d E'] = 'Ẹ', -- LATIN CAPITAL LETTER E WITH DOT BELOW
    ['\\d e'] = 'ẹ', -- LATIN SMALL LETTER E WITH DOT BELOW
    ['\\~E'] = 'Ẽ', -- LATIN CAPITAL LETTER E WITH TILDE
    ['\\~e'] = 'ẽ', -- LATIN SMALL LETTER E WITH TILDE
    ['\\d I'] = 'Ị', -- LATIN CAPITAL LETTER I WITH DOT BELOW
    ['\\d i'] = 'ị', -- LATIN SMALL LETTER I WITH DOT BELOW
    ['\\d O'] = 'Ọ', -- LATIN CAPITAL LETTER O WITH DOT BELOW
    ['\\d o'] = 'ọ', -- LATIN SMALL LETTER O WITH DOT BELOW
    ['\\d U'] = 'Ụ', -- LATIN CAPITAL LETTER U WITH DOT BELOW
    ['\\d u'] = 'ụ', -- LATIN SMALL LETTER U WITH DOT BELOW
    ['\\`Y'] = 'Ỳ', -- LATIN CAPITAL LETTER Y WITH GRAVE
    ['\\`y'] = 'ỳ', -- LATIN SMALL LETTER Y WITH GRAVE
    ['\\d Y'] = 'Ỵ', -- LATIN CAPITAL LETTER Y WITH DOT BELOW
    ['\\d y'] = 'ỵ', -- LATIN SMALL LETTER Y WITH DOT BELOW
    ['\\~Y'] = 'Ỹ', -- LATIN CAPITAL LETTER Y WITH TILDE
    ['\\~y'] = 'ỹ', -- LATIN SMALL LETTER Y WITH TILDE
    ['\\~'] = '~', -- TILDE OPERATOR
    ['~'] = ' ', -- NO-BREAK SPACE
  }
  for k, v in pairs(mappingTable) do
    str = str:gsub(k, v)
  end
  return str
end

M.parse_wrap = function(opts, user_wrap)
  local wrap = user_wrap
  if opts.wrap ~= nil then
    wrap = opts.wrap
  end
  return wrap
end

return M
