--[[ keys.lua ]]
local map = vim.api.nvim_set_keymap
local vmap = vim.keymap.set

-- map(mode, sequence, command, options)
-- mode: the mode you want the key-bind to apply to (insert, normal, command, visual).
-- sequence: the sequence of keys to press.
-- command: the command you want the keypresses to execute.
-- options: an optional Lua table of options to configure (e.g., silent or noremap).

-- remap the key used to leave insert mode
map("i", "jk", "<ESC>", {})

-- Toggle nvim-tree
-- ctrl + n
map("n", "<C-n>", [[:NvimTreeToggle<CR>]], {})

-- Telescope, file search
map("n", "ff", [[:Telescope find_files<CR>]], {})

-- Stop search / disable result highlight
map("n", "=", ":nohlsearch<CR>", { silent = true })

-- Create new buffers
map("n", "<leader>s<left>", ":topleft  vnew <CR>:Alpha<CR>", {})
map("n", "<leader>s<right>", ":botright vnew <CR>:Alpha<CR>", {})
map("n", "<leader>s<up>", ":above sp <CR>:Alpha<CR>", {})
map("n", "<leader>s<down>", ":below sp <CR>:Alpha<CR>", {})

-- Create new tabs, + switch
map("n", "<leader>t<left>", ":tabprevious<CR>", {})
map("n", "<leader>t<right>", ":tabnext<CR>", {})
map("n", "<leader>t<up>", ":tabnew<CR>", {})
map("n", "<leader>t<down>", ":tabclose<CR>", {})

-- debuggers
map("n", "<Leader>bp", 'irequire"pry";binding.pry; <esc>:w<cr>', {})
map("n", "<Leader>bo", "iimport pdb; pdb.set_trace(); <cr>", {})
map("n", "<Leader>bi", "idebugger; <cr>", {})

-- resize windows
map("n", "+", "<C-w>+", {})
map("n", "-", "<C-w>-", {})

map("n", "<leader>d", ':echom (strftime("%H:%M:%S"))<CR>', {})
map("v", "<leader>k", ":!black -q -<CR>", {})
