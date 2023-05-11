local execute = vim.api.nvim_command
local fn = vim.fn

-- NOTES
-- To install new plugins run:
-- :PackerInstall

-- Packer install - install packer if not installed
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(install_path)) > 0 then
	execute("!git clone https://github.com/wbthomason/packer.nvim " .. install_path)
	execute("packadd packer.nvim")
end

vim.cmd("packadd packer.nvim")

-- Auto reload this file + Packer to be able to call PackerInstall instantly
-- NOTE: this might cause 'too many open files'-errors
-- vim.cmd "autocmd BufWritePost plugins.lua source <afile> | PackerCompile"
-- END Packer install/setup

local packer = require("packer")
local util = require("packer.util")

packer.init({
	auto_reload_compiled = true,
	compile_on_sync = true,
	package_root = util.join_paths(vim.fn.stdpath("data"), "site", "pack"),
})

-- startup and add configure plugins
-- Check possible requirement: pip3 install pynvim
packer.startup(function()
	local use = use
	use({ "wbthomason/packer.nvim" })
	-- add you plugins here like:

	--[[ ----------- VISUALS ----------- ]]
	-- Colorscheme
	-- https://github.com/EdenEast/nightfox.nvim
	use({ "EdenEast/nightfox.nvim" })
	use({ "kyazdani42/nvim-web-devicons" })
	-- Set before other plugins to let them adhere to it
	vim.cmd("colorscheme terafox")

	-- Super fast git decorations implemented purely in lua/teal.
	-- + staging of hunks
	-- :GitSigns
	-- https://github.com/lewis6991/gitsigns.nvim
	use({ "lewis6991/gitsigns.nvim" })

	--[[ ----------- LANGUAGE & COMPLETION ----------- ]]
	-- Treesitter (language parsing & highlights)
	use({
		"lukas-reineke/headlines.nvim",
		after = "nvim-treesitter",
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
	})

	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
	})

	use("nvim-treesitter/nvim-treesitter-context")

	use({
		"zbirenbaum/copilot.lua",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
			})
		end,
	})

	use({
		"zbirenbaum/copilot-cmp",
		after = { "copilot.lua" },
		config = function()
			require("copilot_cmp").setup()
		end,
	})

	-- -- Quickstart configs for Nvim LSP
	-- -- use 'neovim/nvim-lspconfig'
	-- :LspInfo
	-- :LspRestart (find new files, imports etc.)
	use({
		"VonHeikemen/lsp-zero.nvim",
		branch = "v1.x",
		requires = {
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
	})

	-- show lsp status
	use({ "j-hui/fidget.nvim" })

	-- show function signature
	use("ray-x/lsp_signature.nvim")

	-- https://github.com/jose-elias-alvarez/null-ls.nvim
	-- also responsible for diagnostics
	-- lua vim.diagnostic.setqflist()
	use({
		"jose-elias-alvarez/null-ls.nvim",
		requires = {
			"nvim-lua/plenary.nvim",
			"neovim/nvim-lspconfig",
		},
	})

	use({
		"jay-babu/mason-null-ls.nvim",
	})

	use({
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup({})
		end,
	})

	--[[ ----------- TESTING ----------- ]]
	-- Start tests from within neovim (vimscript)
	use("vim-test/vim-test")

	-- Floating window used for vim-test
	use("voldikss/vim-floaterm")

	-- https://github.com/andythigpen/nvim-coverage
	use({
		"andythigpen/nvim-coverage",
		requires = {
			"nvim-lua/plenary.nvim",
		},
	})

	--[[ ----------- MENUS ----------- ]]
	use({
		"akinsho/git-conflict.nvim",
		tag = "*",
		config = function()
			require("git-conflict").setup()
		end,
	})

	-- Nvim-Tree - File Explorer For Neovim Written In Lua
	-- https://github.com/kyazdani42/nvim-tree.lua
	use({
		"kyazdani42/nvim-tree.lua",
		requires = {
			"kyazdani42/nvim-web-devicons", -- optional, for file icons
			"elihunter173/dirbuf.nvim",
		},
		tag = "nightly", -- optional, updated every week. (see issue #1193)
	})

	-- Telescope
	-- Use :Telescope to see all (quick) usage options
	use({
		"nvim-telescope/telescope.nvim",
		requires = { { "nvim-lua/plenary.nvim" } },
		config = function()
			require("telescope").load_extension("fzy_native")
			require("telescope").load_extension("ui-select")
			-- require("telescope").load_extension("noice")
		end,
	})

	use({ "nvim-telescope/telescope-ui-select.nvim" })
	use({ "nvim-telescope/telescope-fzy-native.nvim" })

	-- Startup screen
	use({
		"goolord/alpha-nvim",
		requires = { "kyazdani42/nvim-web-devicons" },
		config = function()
			require("alpha").setup(require("alpha.themes.startify").config)
		end,
	})

	-- https://github.com/feline-nvim/feline.nvim
	-- A minimal, stylish and customizable statusline for Neovim written in Lua
	use("feline-nvim/feline.nvim")

	-- Keymaps custom menu:
	-- https://github.com/folke/which-key.nvim
	use({
		"folke/which-key.nvim",
		config = function()
			require("which-key").setup({
				-- your configuration comes here
				-- or leave it empty to use the default settings
				-- refer to the configuration section below
			})
		end,
	})

	-- https://github.com/mrjones2014/legendary.nvim
	use({ "mrjones2014/legendary.nvim" })

	-- https://github.com/numToStr/Comment.nvim
	use({
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	})

	-- Alignment
	-- https://github.com/echasnovski/mini.align
	use({
		"echasnovski/mini.nvim",
		branch = "main",
		config = function()
			require("mini.align").setup()
		end,
	})
end)
