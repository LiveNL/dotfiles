--[[ opts.lua ]]
local opt = vim.opt

-- [[ Context ]]
opt.colorcolumn = "80" -- str:  Show col for max line length
opt.number = true -- bool: Show line numbers
opt.relativenumber = false -- bool: Show relative line numbers
opt.scrolloff = 4 -- int:  Min num lines of context

-- [[ Filetypes ]]
opt.encoding = "utf8" -- str:  String encoding to use
opt.fileencoding = "utf8" -- str:  File encoding to use

-- [[ Theme ]]
opt.syntax = "ON" -- str:  Allow syntax highlighting
opt.termguicolors = true -- bool: If term supports ui color then enable

-- [[ Search ]]
opt.ignorecase = true -- bool: Ignore case in search patterns
opt.smartcase = true -- bool: Override ignorecase if search contains capitals
opt.incsearch = true -- bool: Use incremental search
opt.hlsearch = true -- bool: Highlight search matches

-- [[ Whitespace ]]
opt.expandtab = true -- bool: Use spaces instead of tabs
opt.shiftwidth = 2 -- num:  Size of an indent
opt.softtabstop = 4 -- num:  Number of spaces tabs count for in insert mode
opt.tabstop = 2 -- num:  Number of spaces tabs count for

-- [[ Splits ]]
opt.splitright = true -- bool: Place new window to right of current one
opt.splitbelow = true -- bool: Place new window below the current one

opt.clipboard = "unnamedplus" -- Use mac clipboard
opt.swapfile = false -- Do not save swapfiles

opt.hidden = true

-- Give more space for displaying messages.
opt.cmdheight = 1
opt.updatetime = 200

-- Show the sign column
opt.signcolumn = "yes:3" -- or auto:3-4

vim.cmd("set cursorline")
vim.cmd("set noshowcmd")
vim.cmd("set noshowmode")

-- FIXME: neovim 8.0.0 deprecated
-- vim.api.nvim_set_hl('MsgArea', {guifg='#587b7b'}, false)

vim.g.matchparen_timeout = 100
vim.g.matchparen_insert_timeout = 100

vim.g.coverage_loaded = 0

vim.filetype.add({
	extension = {
		applescript = "applescript",
	},
})
