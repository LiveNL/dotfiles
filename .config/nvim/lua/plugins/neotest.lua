return function()
	local function set_env_from_file(filename)
		local file = io.open(filename, "r")

		if file == nil then
			return
		end

		local content = file:read("*all")
		file:close()

		local lines = {}
		for line in content:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end

		local key, value, is_multiline, delimiter = nil, nil, false, nil
		for i, line in ipairs(lines) do
			if not is_multiline then
				key, value = string.match(line, "([^=]+)=['\"]?(.-)['\"]?$")

				if key then
					if string.match(value, "^-----BEGIN") and not string.match(value, "-----END") then
						is_multiline = true
						delimiter = line:sub(-1) -- get the delimiter
						value = value .. "\n" -- Start appending lines to value
					else
						-- Convert \\n to actual newline for single-line values
						value = value:gsub("\\\\n", "\n")
						vim.fn.setenv(key, value)
					end
				end
			else
				if string.match(line, "-----END" .. delimiter) then
					-- Detected end of multiline value
					value = value .. line

					-- Remove last quote character from value
					value = value:sub(1, -2)
					vim.fn.setenv(key, value)

					-- Reset variables
					key, value, is_multiline, delimiter = nil, nil, false, nil
				else
					value = value .. line .. "\n"
				end
			end
		end
	end

	set_env_from_file(os.getenv("PYTHONPATH") .. "/tests/env")
	--
	require("neotest").setup({
		adapters = {
			require("neotest-python")({
				-- Extra arguments for nvim-dap configuration
				-- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
				dap = { justMyCode = false },

				-- Command line arguments for runner
				-- Can also be a function to return dynamic values
				args = function(args, opts)
					local test_type = opts["type"]
					local base_args = os.getenv("PYTHONPATH") .. "/tests/setup.py", "--log-level", "DEBUG"

					if test_type == "file" then
						return { base_args }
					else
						return { base_args, "-n", "auto" }
					end
				end,

				-- Runner to use. Will use pytest if available by default.
				-- Can be a function to return dynamic value.
				runner = function()
					return "pytest"
				end,
			}),
		},
	})
end
