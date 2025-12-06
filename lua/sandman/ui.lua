-- UI components for Sandman
local M = {}
local config = require("sandman.config")

-- Window IDs
M.inspector_win = nil
M.inspector_buf = nil
M.log_win = nil
M.log_buf = nil
M.output_win = nil
M.output_buf = nil
M.current_output_block_id = nil

-- Create a floating window
local function create_float(title, width, height, row, col)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	return win, buf
end

-- Create a split window
local function create_split(title, position, size)
	local current_win = vim.api.nvim_get_current_win()

	-- Create split
	if position == "right" then
		vim.cmd("vsplit")
		vim.cmd("wincmd L")
		vim.api.nvim_win_set_width(0, size)
	elseif position == "left" then
		vim.cmd("vsplit")
		vim.cmd("wincmd H")
		vim.api.nvim_win_set_width(0, size)
	elseif position == "bottom" then
		vim.cmd("split")
		vim.cmd("wincmd J")
		vim.api.nvim_win_set_height(0, size)
	elseif position == "top" then
		vim.cmd("split")
		vim.cmd("wincmd K")
		vim.api.nvim_win_set_height(0, size)
	end

	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.api.nvim_buf_set_name(buf, title)

	-- Return to original window
	vim.api.nvim_set_current_win(current_win)

	return win, buf
end

-- Show inspector window (open if not already open)
function M.show_inspector(bufnr, block_id)
	-- Get the state for this buffer
	local executor = require("sandman.executor")
	local state = executor.get_state(bufnr)

	-- Open inspector if not already open
	if not M.inspector_win or not vim.api.nvim_win_is_valid(M.inspector_win) then
		local opts = config.get()
		M.inspector_win, M.inspector_buf =
			create_split(" Sandman Inspector ", opts.inspector_position or "right", opts.inspector_size or 100)

		-- Set up keybind to close with Shift-Q
		vim.api.nvim_buf_set_keymap(M.inspector_buf, "n", "Q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.inspector_win and vim.api.nvim_win_is_valid(M.inspector_win) then
					vim.api.nvim_win_close(M.inspector_win, true)
					M.inspector_win = nil
					M.inspector_buf = nil
				end
			end,
		})

		-- Also allow 'q' to close
		vim.api.nvim_buf_set_keymap(M.inspector_buf, "n", "q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.inspector_win and vim.api.nvim_win_is_valid(M.inspector_win) then
					vim.api.nvim_win_close(M.inspector_win, true)
					M.inspector_win = nil
					M.inspector_buf = nil
				end
			end,
		})
	end

	-- Render inspector with optional block focus
	M.render_inspector(state, block_id)

	-- Set focus to inspector window
	vim.api.nvim_set_current_win(M.inspector_win)
end

-- Toggle inspector window
function M.toggle_inspector(state)
	if M.inspector_win and vim.api.nvim_win_is_valid(M.inspector_win) then
		vim.api.nvim_win_close(M.inspector_win, true)
		M.inspector_win = nil
		M.inspector_buf = nil
	else
		local opts = config.get()
		M.inspector_win, M.inspector_buf =
			create_split(" Sandman Inspector ", opts.inspector_position or "right", opts.inspector_size or 100)

		-- Set up keybind to close with Shift-Q
		vim.api.nvim_buf_set_keymap(M.inspector_buf, "n", "Q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.inspector_win and vim.api.nvim_win_is_valid(M.inspector_win) then
					vim.api.nvim_win_close(M.inspector_win, true)
					M.inspector_win = nil
					M.inspector_buf = nil
				end
			end,
		})

		-- Also allow 'q' to close
		vim.api.nvim_buf_set_keymap(M.inspector_buf, "n", "q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.inspector_win and vim.api.nvim_win_is_valid(M.inspector_win) then
					vim.api.nvim_win_close(M.inspector_win, true)
					M.inspector_win = nil
					M.inspector_buf = nil
				end
			end,
		})

		M.render_inspector(state)
	end
end

-- Render inspector content
function M.render_inspector(state, focus_block_id)
	if not M.inspector_buf or not vim.api.nvim_buf_is_valid(M.inspector_buf) then
		return
	end

	local lines = { "# Sandman Inspector", "" }

	-- Show all requests grouped by block
	local total_requests = 0
	for block_id, requests in pairs(state.requests) do
		if #requests > 0 then
			local is_focused = focus_block_id and block_id == focus_block_id
			local prefix = is_focused and ">>> " or ""
			table.insert(lines, string.format("%s## Block %d (%d requests)", prefix, block_id, #requests))
			table.insert(lines, "")

			for i, req in ipairs(requests) do
				total_requests = total_requests + 1
				local status = req.response.status or "ERR"
				local method = req.method
				local url = req.url

				table.insert(lines, string.format("### Request %d: `%s` %s", i, method, url))
				table.insert(lines, "")
				table.insert(lines, string.format("**Status:** `%s`", status))
				table.insert(lines, "")

				-- Show headers
				if req.headers and next(req.headers) then
					table.insert(lines, "**Request Headers:**")
					table.insert(lines, "```")
					for k, v in pairs(req.headers) do
						table.insert(lines, string.format("%s: %s", k, v))
					end
					table.insert(lines, "```")
					table.insert(lines, "")
				end

				-- Show request body
				if req.body and req.body ~= "" then
					table.insert(lines, "**Request Body:**")
					table.insert(lines, "```json")
					if type(req.body) == "table" then
						local ok, encoded = pcall(vim.json.encode, req.body, { indent = "  "})
						-- table.insert(lines, vim.json.encode(req.body, { indent = "  "}))
						if ok then
							for line in encoded:gmatch("[^\r\n]+") do
								table.insert(lines, line)
							end
						else
							table.insert(lines, "-- Failed to encode body as JSON --")
						end
					else 
						for line in req.body:gmatch("[^\r\n]+") do
							table.insert(lines, line)
						end
					end
					table.insert(lines, "```")
					table.insert(lines, "")
				end

				-- Show response
				if req.response then
					if req.response.headers and next(req.response.headers) then
						table.insert(lines, "**Response Headers:**")
						table.insert(lines, "```")
						for k, v in pairs(req.response.headers) do
							table.insert(lines, string.format("%s: %s", k, v))
						end
						table.insert(lines, "```")
						table.insert(lines, "")
					end

					if req.response.body then
						table.insert(lines, "**Response Body:**")
						table.insert(lines, "```json")
						-- Try to decode as JSON first
						local ok, decoded = pcall(vim.json.decode, req.response.body)
						if ok and type(decoded) == "table" then
							local pretty = vim.json.encode(decoded, { indent = "  " })
							for line in pretty:gmatch("[^\r\n]+") do
								table.insert(lines, line)
							end
						else
							for line in req.response.body:gmatch("[^\r\n]+") do
								table.insert(lines, line)
							end
						end
						table.insert(lines, "```")
						table.insert(lines, "")
					end
				end

				table.insert(lines, "---")
				table.insert(lines, "")
			end
		end
	end

	if total_requests == 0 then
		table.insert(lines, "> No requests yet. Run a block with HTTP calls to see them here.")
	end

	vim.api.nvim_buf_set_option(M.inspector_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.inspector_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.inspector_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(M.inspector_buf, "modified", false)
end

-- Toggle log window
function M.toggle_log(state)
	if M.log_win and vim.api.nvim_win_is_valid(M.log_win) then
		vim.api.nvim_win_close(M.log_win, true)
		M.log_win = nil
		M.log_buf = nil
	else
		local opts = config.get()
		M.log_win, M.log_buf = create_split("Sandman Log", opts.log_position, opts.log_size)
		-- Set up keybind to close with Shift-Q
		vim.api.nvim_buf_set_keymap(M.log_buf, "n", "Q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.log_win and vim.api.nvim_win_is_valid(M.log_win) then
					vim.api.nvim_win_close(M.log_win, true)
					M.log_win = nil
					M.log_buf = nil
				end
			end,
		})

		-- Also allow 'q' to close
		vim.api.nvim_buf_set_keymap(M.log_buf, "n", "q", "", {
			noremap = true,
			silent = true,
			callback = function()
				if M.log_win and vim.api.nvim_win_is_valid(M.log_win) then
					vim.api.nvim_win_close(M.log_win, true)
					M.log_win = nil
					M.log_buf = nil
				end
			end,
		})

		M.render_log(state)
	end
end

-- Render log content
function M.render_log(state)
	if not M.log_buf or not vim.api.nvim_buf_is_valid(M.log_buf) then
		return
	end

	local lines = { "# Sandman Log", "" }

	if #state.logs > 0 then
		for _, log in ipairs(state.logs) do
			local timestamp = os.date("%H:%M:%S", log.timestamp)
			table.insert(lines, string.format("[%s] Block %d: %s", timestamp, log.block_id, log.message))
		end
	else
		table.insert(lines, "No log messages yet.")
	end

	vim.api.nvim_buf_set_option(M.log_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.log_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.log_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(M.log_buf, "modified", false)
end

-- Update signs for block states
function M.update_signs(bufnr, blocks, block_states)
	local opts = config.get()
	if not opts.show_signs then
		return
	end

	-- Clear existing signs
	vim.fn.sign_unplace("sandman", { buffer = bufnr })

	-- Place signs for each lua block
	for _, block in ipairs(blocks) do
		if block.type == "lua" then
			local state = block_states[block.id] or "empty"
			local sign_name = "SandmanSign" .. state:sub(1, 1):upper() .. state:sub(2)

			vim.fn.sign_place(0, "sandman", sign_name, bufnr, {
				lnum = block.start_line,
				priority = 10,
			})
		end
	end
end

-- Update virtual text for request counts
function M.update_virtual_text(bufnr, blocks, requests)
	local opts = config.get()
	if not opts.show_virtual_text then
		return
	end

	local ns_id = vim.api.nvim_create_namespace("sandman_virtual_text")

	-- Clear existing virtual text
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	-- Add virtual text for blocks with requests
	for _, block in ipairs(blocks) do
		if block.type == "lua" then
			local block_requests = requests[block.id] or {}
			if #block_requests > 0 then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, block.start_line - 1, 0, {
					virt_text = {
						{
							string.format(" %d request%s", #block_requests, #block_requests > 1 and "s" or ""),
							"SandmanVirtualText",
						},
					},
					virt_text_pos = "eol",
				})
			end
		end
	end
end

-- Initialize signs
function M.init_signs()
	local opts = config.get()

	for name, sign in pairs(opts.signs) do
		if type(sign) == "table" and sign.text then
			local sign_name = "SandmanSign" .. name:sub(1, 1):upper() .. name:sub(2)
			vim.fn.sign_define(sign_name, {
				text = sign.text,
				texthl = sign.hl,
			})
		end
	end
end

-- Initialize highlights
function M.init_highlights()
	local opts = config.get()

	for name, hl in pairs(opts.highlights) do
		local hl_def = {}
		if hl.fg then
			hl_def.fg = hl.fg
		end
		if hl.bg then
			hl_def.bg = hl.bg
		end
		if hl.bold then
			hl_def.bold = true
		end
		if hl.italic then
			hl_def.italic = true
		end

		vim.api.nvim_set_hl(0, name, hl_def)
	end
end

-- Set sign for a block
function M.set_block_sign(bufnr, line, state)
	local opts = config.get()
	if not opts.show_signs then
		return
	end

	local sign_name = "SandmanSign" .. state:sub(1, 1):upper() .. state:sub(2)
	vim.fn.sign_place(0, "sandman", sign_name, bufnr, {
		lnum = line,
		priority = 10,
	})
end

-- Clear all signs in buffer
function M.clear_signs(bufnr)
	vim.fn.sign_unplace("sandman", { buffer = bufnr })
end

-- Set virtual text for a line
function M.set_virtual_text(bufnr, line, text)
	local ns_id = vim.api.nvim_create_namespace("sandman_virtual_text")

	-- Truncate long output
	local max_length = 100
	if #text > max_length then
		text = text:sub(1, max_length) .. "..."
	end

	vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
		virt_text = { { text, "SandmanVirtualText" } },
		virt_text_pos = "eol",
	})
end

-- Clear all virtual text in buffer
function M.clear_virtual_text(bufnr)
	local ns_id = vim.api.nvim_create_namespace("sandman_virtual_text")
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

-- Toggle logs window
function M.toggle_logs(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end
	local executor = require("sandman.executor")
	local state = executor.get_state(path)
	M.toggle_log(state)
end

-- Show output pane for a specific block
function M.show_output(state, block_id, block)
	local opts = config.get()

	-- Close existing output window if open
	if M.output_win and vim.api.nvim_win_is_valid(M.output_win) then
		vim.api.nvim_win_close(M.output_win, true)
		M.output_win = nil
		M.output_buf = nil
	end

	-- Get output for this block
	local output = state.block_outputs and state.block_outputs[block_id]
	local requests = state.requests[block_id] or {}
	local block_state = state.block_states[block_id]

	-- Get editor dimensions
	local ui = vim.api.nvim_list_uis()[1]
	local width = math.floor(ui.width * (opts.output_pane.width or 0.6))
	local height = math.floor(ui.height * (opts.output_pane.height or 0.6))
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	-- Create floating window
	M.output_win, M.output_buf = create_float(string.format(" Block %d Output ", block_id), width, height, row, col)

	M.current_output_block_id = block_id

	-- Set up keybinds to close
	local close_fn = function()
		if M.output_win and vim.api.nvim_win_is_valid(M.output_win) then
			vim.api.nvim_win_close(M.output_win, true)
			M.output_win = nil
			M.output_buf = nil
			M.current_output_block_id = nil
		end
	end

	vim.api.nvim_buf_set_keymap(M.output_buf, "n", "q", "", {
		noremap = true,
		silent = true,
		callback = close_fn,
	})

	vim.api.nvim_buf_set_keymap(M.output_buf, "n", "Q", "", {
		noremap = true,
		silent = true,
		callback = close_fn,
	})

	vim.api.nvim_buf_set_keymap(M.output_buf, "n", "<Esc>", "", {
		noremap = true,
		silent = true,
		callback = close_fn,
	})

	-- Render content
	M.render_output(state, block_id, block)
end

-- Render output pane content
function M.render_output(state, block_id, block)
	if not M.output_buf or not vim.api.nvim_buf_is_valid(M.output_buf) then
		return
	end

	local lines = {}
	local output = state.block_outputs and state.block_outputs[block_id]
	local requests = state.requests[block_id] or {}
	local block_state = state.block_states[block_id]

	-- Show block info
	table.insert(lines, string.format("# Block %d - %s", block_id, block_state:upper()))
	table.insert(lines, "")

	-- Show block code
	if block and block.code then
		table.insert(lines, "## Code")
		table.insert(lines, "```lua")
		for line in block.code:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	-- Show output
	if output then
		table.insert(lines, "## Output")
		table.insert(lines, "```")
		for line in output:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	-- Show HTTP requests if any
	if #requests > 0 then
		table.insert(lines, string.format("## HTTP Requests (%d)", #requests))
		table.insert(lines, "")

		for i, req in ipairs(requests) do
			local status = req.response.status or "ERR"
			local method = req.method
			local url = req.url

			table.insert(lines, string.format("### Request %d: `%s` %s", i, method, url))
			table.insert(lines, "")
			table.insert(lines, string.format("**Status:** `%s`", status))
			table.insert(lines, "")

			-- Show request headers
			if req.headers and next(req.headers) then
				table.insert(lines, "**Request Headers:**")
				table.insert(lines, "```")
				for k, v in pairs(req.headers) do
					table.insert(lines, string.format("%s: %s", k, v))
				end
				table.insert(lines, "```")
				table.insert(lines, "")
			end

			-- Show request body
			if req.body and req.body ~= "" then
				table.insert(lines, "**Request Body:**")
				table.insert(lines, "```json")
				-- Try to decode JSON body first, just in case the request body is JSON
				local body = req.body
				if type(body) == "table" then
					table.insert(lines, vim.json.encode(body))
				elseif type(body) == "string" then
					for line in req.body:gmatch("[^\r\n]+") do
						table.insert(lines, line)
					end
				end
				table.insert(lines, "```")
				table.insert(lines, "")
			end

			-- Show response
			if req.response then
				if req.response.headers and next(req.response.headers) then
					table.insert(lines, "**Response Headers:**")
					table.insert(lines, "```")
					for k, v in pairs(req.response.headers) do
						table.insert(lines, string.format("%s: %s", k, v))
					end
					table.insert(lines, "```")
					table.insert(lines, "")
				end

				if req.response.body ~= nil then
					table.insert(lines, "**Response Body:**")
					table.insert(lines, "```json")
					if type(req.response.body) == "table" then
						print(vim.inspect(vim.json.encode(req.response.body, { indent = "  " })))
						table.insert(lines, vim.json.encode(req.response.body, { indent = "  " }))
					elseif type(req.response.body) == "string" then
						-- Try decode as JSON first
						local ok, decoded = pcall(vim.json.decode, req.response.body)
						if ok and type(decoded) == "table" then
							local pretty = vim.json.encode(decoded, { indent = "  " })
							for line in pretty:gmatch("[^\r\n]+") do
								table.insert(lines, line)
							end
						else
							for line in req.response.body:gmatch("[^\r\n]+") do
								table.insert(lines, line)
							end
						end
					end
					table.insert(lines, "```")
					table.insert(lines, "")
				end
			end

			if i < #requests then
				table.insert(lines, "---")
				table.insert(lines, "")
			end
		end
	end

	if not output and #requests == 0 then
		table.insert(lines, "> No output or requests")
	end

	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "_Press `q`, `Q`, or `<Esc>` to close_")

	vim.api.nvim_buf_set_option(M.output_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.output_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M.output_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(M.output_buf, "modified", false)
end

-- Toggle output pane
function M.toggle_output(bufnr, block_id, block)
	if M.output_win and vim.api.nvim_win_is_valid(M.output_win) then
		vim.api.nvim_win_close(M.output_win, true)
		M.output_win = nil
		M.output_buf = nil
		M.current_output_block_id = nil
	else
		local path = vim.api.nvim_buf_get_name(bufnr)
		if path == "" then
			return
		end
		local executor = require("sandman.executor")
		local state = executor.get_state(path)
		M.show_output(state, block_id, block)
	end
end

return M
