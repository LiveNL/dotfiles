-- https://github.com/folke/which-key.nvim

return function()
	local wk = require("which-key")

	wk.setup({
		plugins = { spelling = true },
		key_labels = { ["<leader>"] = "COMMA" },
	})

	wk.register({
		["="] = { ":nohlsearch<CR>", "Clear search" },
		["+"] = { "<C-w>+", "Increase buffer size" },
		["-"] = { "<C-w>-", "Decrease buffer size" },

		["<C-n>"] = { ":NvimTreeToggle<CR>", "NvimTreeToggle" },
		["<C-t>"] = { ":TestClass<CR>", "TestClass" },

		c = {
			o = { "<cmd>GitConflictChooseOurs", "git merge conflict, choose ours" },
			t = { "<cmd>GitConflictChooseTheirs", "git merge conflict, choose theirs" },
			b = { "<cmd>GitConflictChooseBoth", "git merge conflict, choose both" },
			["0"] = { "<cmd>GitConflictChooseNone", "git merge conflict, choose none" },
			["<right>"] = { "<cmd>GitConflictNextConflict", "git merge conflict: move to previous conflict" },
			["<left>"] = { "<cmd>GitConflictPrevConflict", "git merge conflict: move to next conflict" },
		},

		h = {
			name = "helpers",
			d = {
				function()
					local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
					local seen = {}
					local duplicates = {}

					for _, line in ipairs(lines) do
						if seen[line] then
							duplicates[line] = (duplicates[line] or 1) + 1
						end
						seen[line] = true
					end

					for line, count in pairs(duplicates) do
						print(line .. " [" .. count .. " times]")
					end
				end,
				"Finds duplicate lines within a file",
			},

			j = { "<cmd>FormatJson<cr>", "Format json" },
		},

		["<leader>"] = {
			b = {
				mode = "n",
				name = "debuggers",
				p = { 'irequire"pry";binding.pry; <esc>:w<cr>', "Pry" },
				o = { "iimport pdb; pdb.set_trace(); <cr>", "Pdb" },
				i = { "idebugger; <cr>", "Debugger" },
			},

			d = { ":echom (strftime('%H:%M:%S'))<CR>", "Time" },

			f = {
				f = { "<cmd>Telescope find_files<cr>", "Find files" },
			},

			k = { mode = "v", ":!black -q -<CR>", "Run black on visual selection" },

			l = {
				mode = "n",
				name = "lazygit",
				l = { "<cmd>Lazy<cr>", "Lazy" },
				g = { "<cmd>LazyGit<cr>", "LazyGit" },
			},

			s = {
				mode = "n",
				name = "buffers",
				["<left>"] = { ":topleft vnew <CR>:Alpha<CR>", "New buffer left" },
				["<right>"] = { ":botright vnew <CR>:Alpha<CR>", "New buffer right" },
				["<up>"] = { ":above sp <CR>:Alpha<CR>", "New buffer top" },
				["<down>"] = { ":below sp <CR>:Alpha<CR>", "New buffer bottom" },
			},

			t = {
				mode = "n",
				name = "tabs",
				["<left>"] = { ":tabprevious<cr>", "Previous Tab" },
				["<right>"] = { ":tabnext<cr>", "Next Tab" },
				["<up>"] = { ":tabnew<cr>", "New Tab" },
				["<down>"] = { ":tabclose<cr>", "Close Tab" },
			},
		},
	})
end
