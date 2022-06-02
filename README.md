# nvim-pasta

The yank/paste enhancement plugin for neovim.

This plugin provides the following functionality.

1. Save your all yank history automatically.
2. Cycle yank history after paste via `<C-n>` or `<C-p>` 
3. Adjust block-wise register content's indentation

## Usage

### Setup

```lua
vim.keymap.set('n', 'p', require('pasta.mappings').p)
vim.keymap.set('n', 'P', require('pasta.mappings').P)

-- This is the default. You can omit `setup` call if you don't want to change this. 
require('pasta').setup {
  converters = {
    require('pasta.converters').indentation,
  },
  paste_mode = true,
  next_key = vim.api.nvim_replace_termcodes('<C-p>', true, true, true),
  prev_key = vim.api.nvim_replace_termcodes('<C-n>', true, true, true),
}
```

### Plan

- [x] Adjust indentation for block-wise paste
- [ ] Preview next/prev candidates
