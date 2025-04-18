return function()
	-- Here is where you configure the autocompletion settings.
	local lsp_zero = require("lsp-zero")
	lsp_zero.extend_cmp()

	-- And you can configure cmp even more, if you want to.
	local cmp = require("cmp")
	local lspkind = require("lspkind")

	local has_words_before = function()
		if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
			return false
		end
		local line, col = unpack(vim.api.nvim_win_get_cursor(0))
		return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
	end

	cmp.setup({
		sources = {
			{ name = "copilot" },
			{ name = "nvim_lsp" },
      { name = "path", option = { label_trailing_slash = true } }, -- Allow trailing slashes
			{ name = "luasnip" },
		},

		formatting = {
			format = lspkind.cmp_format({
				mode = "symbol_text",
				maxwidth = 50,
				ellipsis_char = "...",
				symbol_map = { Copilot = "" },
			}),
		},

		mapping = {
			["<CR>"] = cmp.mapping.confirm({
				behavior = cmp.ConfirmBehavior.Replace,
				select = false,
			}),
			["<Tab>"] = vim.schedule_wrap(function(fallback)
				if cmp.visible() and has_words_before() then
					cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
				else
					fallback()
				end
			end),
		},
	})
end
