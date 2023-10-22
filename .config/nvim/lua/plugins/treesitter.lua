-- Tree-sitter is a parser generator tool and an incremental parsing library.
-- It can build a concrete syntax tree for a source file and efficiently update
-- the syntax tree as the source file is edited.
-- https://github.com/tree-sitter/tree-sitter

return function()
	require("nvim-treesitter.configs").setup({
		playground = {
			enable = true,
			disable = {},
			updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
			persist_queries = false, -- Whether the query persists across vim sessions
			keybindings = {
				toggle_query_editor = "o",
				toggle_hl_groups = "i",
				toggle_injected_languages = "t",
				toggle_anonymous_nodes = "a",
				toggle_language_display = "I",
				focus_language = "f",
				unfocus_language = "F",
				update = "R",
				goto_node = "<cr>",
				show_help = "?",
			},
		},
		-- A list of parser names, or "all"
		ensure_installed = { "c", "lua", "rust", "python", "html" },

		-- Install parsers synchronously (only applied to `ensure_installed`)
		sync_install = false,

		-- Automatically install missing parsers when entering buffer
		auto_install = true,

		-- List of parsers to ignore installing (for "all")
		ignore_install = { "javascript" },

		highlight = {
			-- `false` will disable the whole extension
			enable = true,

			-- NOTE: these are the names of the parsers and not the filetype.
			-- (for example if you want to
			-- disable highlighting for the `tex` filetype, you need to include
			-- `latex` in this list as this is
			-- the name of the parser)
			-- list of language that will be disabled
			disable = { "c", "rust" },

			-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
			-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
			-- Using this option may slow down your editor, and you may see some duplicate highlights.
			-- Instead of true it can also be a list of languages
			additional_vim_regex_highlighting = false,
		},
	})
end
