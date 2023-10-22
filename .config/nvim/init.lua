--[[ init.lua ]]

local g = vim.g
g.mapleader = ","
g.localleader = "\\"
g.t_co = 256

require("opts")
require("plugins")
require("autocmd")
