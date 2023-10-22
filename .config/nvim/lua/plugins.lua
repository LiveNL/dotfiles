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
	--[[ ----------- VISUALS ----------- ]]
	-- Colorscheme
	"nvim-tree/nvim-web-devicons",

	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme terafox")
		end,
	},

	"lewis6991/gitsigns.nvim",

	--[[ ----------- LANGUAGE & COMPLETION ----------- ]]
	-- Treesitter (language parsing & highlights)
	{
		"lukas-reineke/headlines.nvim",
		dependencies = "nvim-treesitter/nvim-treesitter",
		ft = { "org", "norg", "markdown", "yaml" },
		config = function()
			require("headlines").setup({
				markdown = {
					query = vim.treesitter.query.parse(
						"markdown",
						[[
                  (atx_heading [
                      (atx_h1_marker)
                      (atx_h2_marker)
                      (atx_h3_marker)
                      (atx_h4_marker)
                      (atx_h5_marker)
                      (atx_h6_marker)
                  ] @headline)

                  (thematic_break) @dash

                  (fenced_code_block) @codeblock

                  (block_quote_marker) @quote
                  (block_quote (paragraph (inline (block_continuation) @quote)))
              ]]
					),
					headline_highlights = { "Headline" },
					codeblock_highlight = "CodeBlock",
					dash_highlight = "Dash",
					dash_string = "-",
					quote_highlight = "Quote",
					quote_string = "┃",
					fat_headlines = true,
					fat_headline_upper_string = "▃",
					fat_headline_lower_string = "🬂",
					----------
					-- code_fence_content = "CodeBlock",
					-- fenced_code_block_delimiter = "CodeBlock",
				},
			})
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
	},

	"nvim-treesitter/nvim-treesitter-context",
	"nvim-treesitter/playground",

	{
		"zbirenbaum/copilot.lua",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
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

	"onsails/lspkind.nvim",

	-- -- Quickstart configs for Nvim LSP
	-- -- use 'neovim/nvim-lspconfig'
	-- :LspInfo
	-- :LspRestart (find new files, imports etc.)
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v1.x",
		dependencies = {
			-- LSP Support
			{ "neovim/nvim-lspconfig" }, -- Required
			{ "williamboman/mason.nvim" }, -- Optional
			{ "williamboman/mason-lspconfig.nvim" }, -- Optional

			-- Autocompletion
			{ "hrsh7th/nvim-cmp" }, -- Required
			{ "hrsh7th/cmp-nvim-lsp" }, -- Required
			{ "hrsh7th/cmp-buffer" }, -- Optional
			{ "hrsh7th/cmp-path" }, -- Optional
			{ "saadparwaiz1/cmp_luasnip" }, -- Optional
			{ "hrsh7th/cmp-nvim-lua" }, -- Optional

			-- Snippets
			{ "L3MON4D3/LuaSnip" }, -- Required
			{ "rafamadriz/friendly-snippets" }, -- Optional
		},
	},

	-- show lsp status
	"j-hui/fidget.nvim",

	-- show function signature
	"ray-x/lsp_signature.nvim",

	-- https://github.com/jose-elias-alvarez/null-ls.nvim
	-- also responsible for diagnostics
	-- lua vim.diagnostic.setqflist()
	{
		"jose-elias-alvarez/null-ls.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"neovim/nvim-lspconfig",
		},
	},

	{
		"jay-babu/mason-null-ls.nvim",
	},

	{
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup({})
		end,
	},

	--[[ ----------- TESTING ----------- ]]
	-- Start tests from within neovim (vimscript)
	"vim-test/vim-test",

	-- Floating window used for vim-test
	"voldikss/vim-floaterm",

	-- https://github.com/andythigpen/nvim-coverage
	{
		"andythigpen/nvim-coverage",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},

	--[[ ----------- MENUS ----------- ]]
	{ "akinsho/git-conflict.nvim", version = "*", config = true },

	-- Nvim-Tree - File Explorer For Neovim Written In Lua
	-- https://github.com/kyazdani42/nvim-tree.lua
	{
		"kyazdani42/nvim-tree.lua",
		dependencies = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icons
			"elihunter173/dirbuf.nvim",
		},
		tag = "nightly", -- optional, updated every week. (see issue #1193)
	},

	-- Telescope
	-- Use :Telescope to see all (quick) usage options
	{
		"nvim-telescope/telescope.nvim",
		dependencies = { { "nvim-lua/plenary.nvim" } },
		config = function()
			require("telescope").load_extension("fzy_native")
			require("telescope").load_extension("ui-select")
			-- require("telescope").load_extension("noice")
		end,
	},

	"nvim-telescope/telescope-ui-select.nvim",
	"nvim-telescope/telescope-fzy-native.nvim",

	-- Startup screen
	{
		"goolord/alpha-nvim",
		dependencies = { "kyazdani42/nvim-web-devicons" },
		config = function()
			require("alpha").setup(require("alpha.themes.startify").config)
		end,
	},

	-- https://github.com/feline-nvim/feline.nvim
	-- A minimal, stylish and customizable statusline for Neovim written in Lua
	"feline-nvim/feline.nvim",

	-- Keymaps custom menu:
	-- https://github.com/folke/which-key.nvim
	{
		"folke/which-key.nvim",
		config = function()
			require("which-key").setup({
				-- your configuration comes here
				-- or leave it empty to use the default settings
				-- refer to the configuration section below
			})
		end,
	},

	-- https://github.com/mrjones2014/legendary.nvim
	"mrjones2014/legendary.nvim",

	-- https://github.com/numToStr/Comment.nvim
	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	},

	-- Alignment
	-- https://github.com/echasnovski/mini.align
	{
		"echasnovski/mini.nvim",
		branch = "main",
		config = function()
			require("mini.align").setup()
		end,
	},
})
