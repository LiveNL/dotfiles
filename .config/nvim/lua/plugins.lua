local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

local lazy = require("lazy")

lazy.setup({
	checker = { enabled = true },

	-- "https://github.com/kyazdani43/nvim-web-devicons.git"
	"kyazdani43/nvim-web-devicons",

	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme terafox")
		end,
	},

	-- Git integration for buffers
	-- https://github.com/lewis6991/gitsigns.nvim
	{ "lewis6991/gitsigns.nvim", config = require("plugins.gitsigns") },

	-- In-buffer markdown rendering (headings, code blocks, tables, checkboxes, callouts…)
	-- https://github.com/MeanderingProgrammer/render-markdown.nvim
	{
		"MeanderingProgrammer/render-markdown.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		ft = { "markdown" },
		config = require("plugins.render-markdown"),
	},

	-- Center buffer content with side padding (used for markdown reading/writing)
	-- https://github.com/shortcuts/no-neck-pain.nvim
	{
		"shortcuts/no-neck-pain.nvim",
		version = "*",
		ft = { "markdown" },
		config = function()
			local nnp = require("no-neck-pain")

			local function enable()
				local width = math.max(100, math.floor(vim.o.columns * 0.8))
				nnp.setup({
					width = width,
					buffers = {
						scratchPad = { enabled = false },
						wo = { fillchars = "eob: " },
					},
				})
				nnp.enable()
			end

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = enable,
			})

			-- Plugin loaded lazily on ft=markdown, so the FileType event already
			-- fired — enable immediately for the current buffer.
			if vim.bo.filetype == "markdown" then
				enable()
			end

			vim.api.nvim_create_autocmd("VimResized", {
				callback = function()
					if vim.bo.filetype == "markdown" then
						enable()
					end
				end,
			})
		end,
	},

	-- Nvim Treesitter configurations and abstraction layer
	-- https://github.com/nvim-treesitter/nvim-treesitter
	{

		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = require("plugins.treesitter"),
	},

	"nvim-treesitter/nvim-treesitter-context",

	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "VeryLazy",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
				filetypes = {
					markdown = false,
					help = false,
					gitcommit = false,
					gitrebase = false,
					text = false,
					["*"] = true,
				},
				copilot_node_command = "node",
				server_opts_overrides = {
					settings = {
						advanced = {
							inlineSuggestCount = 3,
						},
					},
				},
			})
		end,
		dependencies = {
			{
				"zbirenbaum/copilot-cmp",
				config = function()
					require("copilot_cmp").setup()
				end,
			},
		},
	},

	-- This tiny plugin adds vscode-like pictograms to neovim built-in lsp:
	-- https://github.com/onsails/lspkind.nvim
	"onsails/lspkind.nvim",


	{
		"williamboman/mason.nvim",
		lazy = false,
		config = true,
	},

	-- Autocompletion
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			{ "L3MON4D3/LuaSnip", build = "make install_jsregexp" },
			{ "rafamadriz/friendly-snippets" }, -- Optional
			{ "hrsh7th/cmp-path" }, -- Optional
		},
		config = require("plugins.lsp-autocompletion"),
	},

	-- LSP
	"b0o/schemastore.nvim",

	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = true },
		},
		cmd = { "LspInfo", "LspInstall", "LspStart" },
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "williamboman/mason-lspconfig.nvim" },
		},
		config = require("plugins.lsp"),
	},


	-- show lsp status
	-- https://github.com/j-hui/fidget.nvim
	{ "j-hui/fidget.nvim", tag = "legacy", event = "LspAttach", opts = {} },

	-- show function signature
	-- https://github.com/ray-x/lsp_signature.nvim
	{
		"ray-x/lsp_signature.nvim",
		event = "VeryLazy",
		config = require("plugins.lsp-signature"),
	},

	-- Removed null-ls and related plugins

	-- autopairs for neovim written by lua
	-- https://github.com/windwp/nvim-autopairs
	{ "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

	-- Displays coverage information in the sign column.
	-- https://github.com/andythigpen/nvim-coverage
	{
		"andythigpen/nvim-coverage",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = require("plugins.coverage"),
	},

	-- A plugin to visualise and resolve merge conflicts in neovim
	-- https://github.com/akinsho/git-conflict.nvim
	{ "akinsho/git-conflict.nvim", version = "*", config = true },

  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    config = true,
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      { "<leader>gD", "<cmd>DiffviewFileHistory<cr>", desc = "File History" },
    },
  },

	-- Plugin for calling lazygit from within neovim.
	-- https://github.com/kdheepak/lazygit.nvim
	{
		{
			"kdheepak/lazygit.nvim",
			-- optional for floating window border decoration
			dependencies = {
				"nvim-telescope/telescope.nvim",
				"nvim-lua/plenary.nvim",
			},
			config = function()
				require("telescope").load_extension("lazygit")
			end,
		},
	},
	-- Nvim-Tree - File Explorer For Neovim Written In Lua
	-- https://github.com/nvim-tree/nvim-tree.lua
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons", -- optional, for file icons
		},
		config = require("plugins.nvim-tree"),
	},

	-- FZF sorter for telescope written in c
	-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

	-- It sets vim.ui.select to telescope.
	-- https://github.com/nvim-telescope/telescope-ui-select.nvim
	"nvim-telescope/telescope-ui-select.nvim",

	-- https://github.com/nvim-telescope/telescope-project.nvim
	{
		"nvim-telescope/telescope-project.nvim",
		lazy = true,
	},

	-- Find, Filter, Preview, Pick. All lua, all the time.
	-- https://github.com/nvim-telescope/telescope.nvim
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { { "nvim-lua/plenary.nvim" } },
		config = require("plugins.telescope"),
	},

	{
		"echasnovski/mini.nvim",
		version = "*",
		config = function()
			require("plugins.mini")
		end,
	},

	-- A minimal, stylish and customizable statusline for Neovim written in Lua
	-- https://github.com/freddiehaddad/feline.nvim
	-- { "freddiehaddad/feline.nvim", config = require("plugins.feline") },

	-- Custom keymaps + menu:
	{ "folke/which-key.nvim", config = require("plugins.which-key") },

  { "nvzone/menu", lazy = true, dependencies = { "nvzone/volt" } },

	-- Smart and Powerful commenting plugin for neovim
	{ "numToStr/Comment.nvim", opts = {}, lazy = false },

	-- A powerful Neovim plugin that lets users choose & modify RGB/HSL/HEX colors.
	-- https://github.com/ziontee113/color-picker.nvim
	{
		"ziontee113/color-picker.nvim",
		config = function()
			require("color-picker")
		end,
	},

	-- The fastest Neovim colorizer.
	-- https://github.com/NvChad/nvim-colorizer.lua
	{
		"NvChad/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup()
		end,
	},

	-- An extensible framework for interacting with tests within NeoVim.
	-- https://github.com/nvim-neotest/neotest
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-jest",
			"nvim-neotest/nvim-nio",
		},
		config = require("plugins.neotest"),
	},

	-- A pretty window for previewing, navigating and editing your LSP locations
	-- https://github.com/DNLHC/glance.nvim
	{ "dnlhc/glance.nvim" },

	{
		"jinh0/eyeliner.nvim",
		config = function()
			require("eyeliner").setup({
				highlight_on_key = true, -- show highlights only after keypress
				dim = false, -- dim all other characters if set to true (recommended!)
			})
		end,
	},

	{ "google/vim-searchindex", lazy = true },

	-- {
	-- 	"yetone/avante.nvim",
	-- 	event = "VeryLazy",
	-- 	lazy = false,
	-- 	version = false, -- set this if you want to always pull the latest change
	-- 	opts = {
	-- 		-- add any opts here
 --      provider = "copilot", -- Recommend using Claude
 --      auto_suggestions_provider = "copilot",
	-- 	},
	-- 	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- 	build = "make",
	-- 	-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
	-- 	dependencies = {
	-- 		"stevearc/dressing.nvim",
	-- 		"nvim-lua/plenary.nvim",
	-- 		"MunifTanjim/nui.nvim",
	-- 		--- The below dependencies are optional,
	-- 		"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
	-- 		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
	-- 		"zbirenbaum/copilot.lua", -- for providers='copilot'
	-- 		{
	-- 			-- support for image pasting
	-- 			"HakonHarnes/img-clip.nvim",
	-- 			event = "VeryLazy",
	-- 			opts = {
	-- 				-- recommended settings
	-- 				default = {
	-- 					embed_image_as_base64 = false,
	-- 					prompt_for_file_name = false,
	-- 					drag_and_drop = {
	-- 						insert_mode = true,
	-- 					},
	-- 					-- required for Windows users
	-- 					use_absolute_path = true,
	-- 				},
	-- 			},
	-- 		},
	-- 		{
	-- 			-- Make sure to set this up properly if you have lazy=true
	-- 			"MeanderingProgrammer/render-markdown.nvim",
	-- 			opts = {
	-- 				file_types = { "markdown", "Avante" },
	-- 			},
	-- 			ft = { "markdown", "Avante" },
	-- 		},
	-- 	},
	-- },
})
