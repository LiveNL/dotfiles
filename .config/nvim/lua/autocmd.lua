---@param group string
local augroup = function(group)
	vim.api.nvim_create_augroup(group, { clear = true })

	---@param autocmds fun(autocmd: fun(event: table | string, opts: table, command: function | string))
	return function(autocmds)
		autocmds(function(event, opts, command)
			opts.group = group
			if type(command) == "function" then
				opts.callback = command
			else
				opts.command = command
			end
			vim.api.nvim_create_autocmd(event, opts)
		end)
	end
end

augroup("test_coverage_show")(function(autocmd)
	autocmd({ "FileType" }, { pattern = "python" }, function()
		local file_exists = io.open(".coverage", "r") ~= nil
		if file_exists and vim.g.coverage_loaded == 0 then
			require("coverage").load(true)
		end
	end)
end)

augroup("refresh")(function(autocmd)
	autocmd({ "BufWritePost" }, { pattern = "*.py" }, function()
		pcall(LspRestart)
	end)
end)

augroup("cleanup")(function(autocmd)
	autocmd({ "BufWritePre" }, { pattern = "*[^.md]" }, [[%s/\s\+$//e]])
end)

function get_file_name(file)
	return file:match("^.+/(.+)$")
end

augroup("luaupdates")(function(autocmd)
	autocmd({ "BufWritePost" }, { pattern = "*.lua" }, function()
		pcall(PackerCompile)
	end)
end)

augroup("BlackFormatOnSave")(function(autocmd)
	autocmd({ "BufWritePost" }, { pattern = "*.py" }, function()
    vim.fn.system({"black", "-l", "80", "--fast", vim.fn.expand("%:p")})
		vim.fn.system({"ruff", "--select", "I", "--fix", vim.fn.expand("%:p")})
    vim.fn.system({"ruff", "--fix", vim.fn.expand("%:p")})
    vim.cmd("checktime")
	end)
end)


local function format_json()
	local start_line = vim.fn.getpos("'<")[2]
	local end_line = vim.fn.getpos("'>")[2]
	vim.api.nvim_command(start_line .. "," .. end_line .. "!python -m json.tool --indent 2")
end

_G.format_json = format_json

vim.api.nvim_exec(
	[[
  command! -range FormatJson <line1>,<line2>lua _G.format_json()
]],
	false
)

vim.api.nvim_create_augroup("diagnostics", { clear = true })

vim.api.nvim_create_autocmd("DiagnosticChanged", {
	group = "diagnostics",
	callback = function()
		vim.diagnostic.setloclist({ open = false })
		vim.diagnostic.enable(true, { bufnr = 0 })
	end,
})

vim.api.nvim_create_user_command("LspStatus", function()
  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  if #clients == 0 then
    vim.notify("No LSP clients attached to this buffer", vim.log.levels.WARN)
    return
  end

  local message = "LSP clients attached to this buffer:\n"
  for _, client in ipairs(clients) do
    message = message .. "- " .. client.name .. "\n"
  end

  vim.notify(message, vim.log.levels.INFO)
end, {})
