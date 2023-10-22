--[[ init.lua ]]

local g = vim.g
g.mapleader = ","
g.localleader = "\\"
g.t_co = 256

-- IMPORTS
require("keys")
require("opts")

require("plugins")
require("plugins.coverage")
require("plugins.telescope")
require("plugins.nvim-tree")
require("plugins.lsp")
require("plugins.treesitter")
require("plugins.vim-test")
require("plugins.statusline")
require("plugins.gitgutter")
require("plugins.null-ls")
require("plugins.legendary_menu")
require("autocmd")
