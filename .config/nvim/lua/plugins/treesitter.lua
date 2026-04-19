return function()
	require("nvim-treesitter").setup()

	vim.defer_fn(function()
		require("nvim-treesitter").install({ "lua", "python", "html" })
	end, 0)

	vim.api.nvim_create_autocmd("FileType", {
		callback = function(ev)
			if ev.match == "javascript" then
				return
			end
			pcall(require("nvim-treesitter").install, { ev.match })
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "c", "rust" },
		callback = function(ev)
			vim.schedule(function()
				vim.treesitter.stop(ev.buf)
			end)
		end,
	})
end
