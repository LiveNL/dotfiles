-- https://github.com/folke/which-key.nvim

return function()
	local wk = require("which-key")
	local Util = require("lazyvim.util")
	local conceallevel = vim.o.conceallevel > 0 and vim.o.conceallevel or 3

	wk.setup({
		plugins = { spelling = true },
		key_labels = { ["<leader>"] = "COMMA" },
	})

	wk.register({
		["="] = { ":nohlsearch<CR>", "Clear search" },
		["+"] = { "<C-w>+", "Increase buffer size" },
		["-"] = { "<C-w>-", "Decrease buffer size" },

		["<C-n>"] = { ":NvimTreeToggle<CR>", "NvimTreeToggle" },

		["<C-t>"] = {
			name = "Tests",
			j = { "<cmd>Neotest run file<CR>", "Neotest run file" },
			O = { "<cmd>Neotest output<CR>", "Neotest show output" },
			o = { "<cmd>Neotest output-panel<CR>", "Neotest show output panel" },
			s = { "<cmd>Neotest summary<CR>", "Neotest show summary" },
			a = { "<cmd>Neotest run tests<CR>", "Neotest run all" },
			l = { "<cmd>Neotest attach<CR>", "Neotest attatch to test console" },
		},

		g = {
			D = { "<cmd>Glance definitions<cr>", "Glance definitions" },
			R = { "<cmd>Glance references<cr>", "Glance references" },
			Y = { "<cmd>Glance type_definitions<cr>", "Glance type definitions" },
			M = { "<cmd>Glance implementations<cr>", "Glance implementations" },
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
			c = { "<cmd>PickColor<cr>", "Pick Color" },
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
				name = "Telescope functions",
				f = { "<cmd>Telescope find_files<cr>", "Find files" },
				d = { "<cmd>Telescope diagnostics<cr>", "Find diagnostics issues" },
				h = { "<cmd>Telescope command history<cr>", "Find command history" },
				c = { "<cmd>Telescope commands<cr>", "Find commands" },
				g = {
					s = { "<cmd>Telescope git_status<cr>", "Find git status" },
					c = { "<cmd>Telescope git_commits<cr>", "Find git commits" },
					b = { "<cmd>Telescope git_branches<cr>", "Find git branches" },
					r = { "<cmd>Telescope git_bcommits<cr>", "Find git bcommits" },
					o = { "<cmd>Telescope git_stash<cr>", "Find git stash" },
				},
				l = { "<cmd>Telescope live_grep<cr>", "Find live grep" },
				w = { "<cmd>Telescope grep_string<cr>", "Find grep string" },
			},

			k = {
				name = "black",
				mode = "v",
				":!black -q -<CR>",
				"Run black on visual selection",
			},

			l = {
				mode = "n",
				name = "lazygit",
				l = { "<cmd>Lazy<cr>", "Lazy" },
				g = { "<cmd>LazyGit<cr>", "LazyGit" },
			},

			m = {
				name = "git merge conflict",
				o = { "<cmd>GitConflictChooseOurs<cr>", "git merge conflict, choose ours" },
				t = { "<cmd>GitConflictChooseTheirs<cr>", "git merge conflict, choose theirs" },
				b = { "<cmd>GitConflictChooseBoth<cr>", "git merge conflict, choose both" },
				["0"] = { "<cmd>GitConflictChooseNone<cr>", "git merge conflict, choose none" },
				["<right>"] = { "<cmd>GitConflictNextConflict<cr>", "git merge conflict: move to previous conflict" },
				["<left>"] = { "<cmd>GitConflictPrevConflict<cr>", "git merge conflict: move to next conflict" },
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

			u = {
				name = "toggles",
				f = {
					function()
						Util.format.toggle()
					end,
					"Toggle auto format (global)",
				},
				F = {
					function()
						Util.format.toggle(true)
					end,
					"Toggle auto format (buffer)",
				},
				s = {
					function()
						Util.toggle("spell")
					end,
					"Toggle Spelling",
				},
				w = {
					function()
						Util.toggle("wrap")
					end,
					"Toggle Word Wrap",
				},
				L = {
					function()
						Util.toggle("relativenumber")
					end,
					"Toggle Relative Line Numbers",
				},
				l = {
					function()
						Util.toggle.number()
					end,
					"Toggle Line Numbers",
				},
				d = {
					function()
						Util.toggle.diagnostics()
					end,
					"Toggle Diagnostics",
				},
				c = {
					function()
						Util.toggle("conceallevel", false, { 0, conceallevel })
					end,
					"Toggle Conceal",
				},
				h = {
					function()
						vim.lsp.inlay_hint(0, nil)
					end,
					"Toggle Inlay Hints",
				},
				T = {
					function()
						if vim.b.ts_highlight then
							vim.treesitter.stop()
						else
							vim.treesitter.start()
						end
					end,
					"Toggle Treesitter Highlight",
				},
			},
		},
	})
end
