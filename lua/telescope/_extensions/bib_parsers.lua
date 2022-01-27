local State = {
  name = 1,
  path = 2,
  ext  = 3,
  done = 4
}

local Commit = {
  name = 1,
  path = 2,
  ext  = 3,
}

-- P for parser

P = {}

P.file_list = function(str)
  local result = {}
  table.insert(result, {})
  local start = 1
  local index = 1
  local state = nil
  for c in str:gmatch"." do

    if state == nil then
      if c == "{" then
        state = State.name
        goto continue
      end
      return nil
    end

    skip = false
    commit = nil

    if state == State.name then
      if c == "}" then
        state = State.done
        commit = Commit.path
      elseif c == ";" then
        commit = Commit.path
      elseif c == ":" then
        state = State.path
        commit = Commit.name
      else
        skip = (c == "\\")
      end

    elseif state == State.path then
      if c == ":" then
        state = State.ext
        commit = Commit.path
      elseif c == "}" or c == ";" then
        state = State.err
      else
        skip = ( c == "\\" )
      end

    elseif state == State.ext then
      if c == ";" then
        state = State.name
        commit = Commit.ext
      elseif c == "}" then
        state = State.done
        commit = Commit.ext
      end

    end

    if commit == nil then
      goto continue
    end

    term = result[#result]
    word = str:sub(start+1, index-1)
    start = index

    if commit == Commit.name then
      term.name = word

    elseif commit == Commit.path then
      term.path = word
      if term.name == nil then
        table.insert(result, {})
      end

    elseif commit == Commit.ext then
      term.ext = word
      table.insert(result, {})
    end

    if state == State.done then
      return result
    end

    ::continue::

    index = index + 1
  end
end

return P
