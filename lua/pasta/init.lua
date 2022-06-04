local converters = require('pasta.converters')
local highlight  = require('pasta.highlight')

---@class pasta.Entry
---@field public regtype string
---@field public regcontents string[]

---@class pasta.Config
---@field public converters? (fun(entry: pasta.Entry): pasta.Entry)[]
---@field public paste_mode? boolean
---@field public next_key? string
---@field public prev_key? string

local config = {
  converters = {
    converters.indentation,
  },
  paste_mode = true,
  next_key = vim.api.nvim_replace_termcodes('<C-p>', true, true, true),
  prev_key = vim.api.nvim_replace_termcodes('<C-n>', true, true, true),
}

local pasta = {}

---@type pasta.Entry[]
pasta.history = {}

---@type boolean
pasta.running = false

---Setup pasta.
---@param config_ pasta.Config
function pasta.setup(config_)
  for k, v in pairs(config_) do
    config[k] = v
  end
end

---Save yank history.
---@param regtype string
---@param regcontents string[]
function pasta.save(regtype, regcontents)
  if pasta.running then
    return
  end

  pasta.history = vim.tbl_filter(function(entry)
    return entry.regtype ~= regtype or table.concat(entry.regcontents, '\n') ~= table.concat(regcontents, '\n')
  end, pasta.history)
  table.insert(pasta.history, 1, {
    regtype = regtype,
    regcontents = regcontents
  })
end

---Start paste mode.
---@param after boolean
function pasta.start(after)
  pasta.ensure()

  if #pasta.history == 0 then
    return
  end

  pasta.running = true
  pcall(function()
    vim.diagnostic.disable()
    local savepoint = pasta.savepoint()
    local index = 1
    local entry = pasta.history[index]
    pasta.paste(entry, after)
    while true do
      local char = vim.fn.nr2char(vim.fn.getchar())
      if char == config.prev_key and index > 1 then
        index = index - 1
        entry = pasta.history[index]
        savepoint()
        pasta.paste(pasta.history[index], after)
      elseif char == config.next_key and index < #pasta.history then
        index = index + 1
        entry = pasta.history[index]
        savepoint()
        pasta.paste(pasta.history[index], after)
      elseif char ~= config.next_key and char ~= config.prev_key then
        vim.api.nvim_feedkeys(char, 'i', true)
        break
      end
    end
    pasta.save(entry.regtype, entry.regcontents)
    vim.fn.setreg(vim.v.register, entry)
  end)
  pasta.running = false
  highlight.clear()
  vim.diagnostic.enable()
end

---Paste the text and redraw.
---@param entry pasta.Entry
---@param after boolean
function pasta.paste(entry, after)
  entry = {
    regtype = entry.regtype,
    regcontents = { unpack(entry.regcontents) },
  }
  for _, converter in ipairs(config.converters or {}) do
    entry = converter(entry)
  end

  if entry.regtype ~= 'v' and #entry.regcontents > 1 and entry.regcontents[#entry.regcontents] == '' then
    table.remove(entry.regcontents, #entry.regcontents)
  end

  local paste = vim.o.paste
  local register = vim.fn.getreginfo(vim.v.register)
  vim.o.paste = config.paste_mode
  vim.fn.setreg(vim.v.register, entry)
  if after then
    vim.cmd('normal! p')
  else
    vim.cmd('normal! P')
  end
  vim.o.paste = paste
  vim.fn.setreg(vim.v.register, register)

  if vim.fn.reg_executing() == '' then
    highlight.cursor(vim.api.nvim_win_get_cursor(0))
    vim.cmd([[redraw!]])
  end
end

---Create savepoint.
---@return function
function pasta.savepoint()
  vim.o.undolevels = vim.o.undolevels
  local cursor = vim.fn.getcurpos()
  local changenr = vim.fn.changenr()
  local is_visual = pasta.is_visual()
  return function()
    if vim.fn.changenr() ~= changenr then
      vim.cmd(([[undo %s]]):format(changenr))
    end
    if is_visual then
      vim.cmd([[normal! gv]])
    end
    vim.fn.setpos('.', cursor)
  end
end

---Ensure recent register.
function pasta.ensure()
  for _, register in ipairs({ vim.v.register }) do
    local reginfo = vim.fn.getreginfo(register)
    if not vim.tbl_isempty(reginfo) then
      pasta.save(reginfo.regtype, reginfo.regcontents)
    end
  end
end

---Return the mode is visual or not.
---@return boolean
function pasta.is_visual()
  return vim.tbl_contains({ 'v', 'V', vim.api.nvim_replace_termcodes('<C-v>', true, true, true) }, vim.api.nvim_get_mode().mode)
end

return pasta

