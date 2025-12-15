-- Main plugin orchestrator for sandman.nvim
local M = {}

M.config = require("sandman.config")
M.parser = require("sandman.parser")
M.executor = require("sandman.executor")
M.http = require("sandman.http")
M.server = require("sandman.server")
M.ui = require("sandman.ui")
M.storage = require("sandman.storage")
M.utils = require("sandman.utils")

-- Track active servers per buffer
M.servers = {}

-- Setup function called by user
function M.setup(opts)
	M.config.setup(opts)

	-- Set up autocommands
	M.setup_autocommands()

	-- Set up highlights
	M.setup_highlights()

	-- Initialize signs
	M.ui.init_signs()
end

-- Set up autocommands for markdown files
function M.setup_autocommands()
	local group = vim.api.nvim_create_augroup("Sandman", { clear = true })

	-- Initialize buffer when markdown file is opened
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			M.init_buffer(ev.buf)
		end,
	})

	-- Auto-save when leaving buffer or idle
	if M.config.options.auto_save then
		vim.api.nvim_create_autocmd({ "BufLeave", "CursorHold" }, {
			group = group,
			pattern = "*.md",
			callback = function(ev)
				if vim.bo[ev.buf].modified then
					vim.cmd("silent write")
				end
			end,
		})
	end

	-- Clean up when buffer is closed
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		pattern = "*.md",
		callback = function(ev)
			M.cleanup_buffer(ev.buf)
		end,
	})

	-- Reload environment variables when .env file is saved
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.env",
		callback = function(ev)
			M.reload_env_for_notebook(ev.buf)
		end,
	})
end

-- Set up highlight groups
function M.setup_highlights()
	for name, hl in pairs(M.config.options.highlights) do
		vim.api.nvim_set_hl(0, name, hl)
	end
end

-- Initialize buffer with signs and keymaps
function M.init_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Set up signs if enabled
	-- if M.config.options.signs.enabled then
	--   M.ui.setup_signs(bufnr)
	-- end

	-- Set up buffer-local keymaps if enabled
	if M.config.options.keymaps.enabled then
		M.setup_keymaps(bufnr)
	end

	-- Load environment variables
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path ~= "" then
		local env = M.storage.load_env(path)
		M.executor.set_env(path, env)
	end
end

-- Clean up buffer resources
function M.cleanup_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Stop any running servers
	if M.servers[bufnr] then
		M.server.stop(M.servers[bufnr])
		M.servers[bufnr] = nil
	end

	-- Clear executor state
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path ~= "" then
		M.executor.clear_state(path)
	end

	-- Clear signs
	M.ui.clear_signs(bufnr)
end

-- Set up buffer-local keymaps
function M.setup_keymaps(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local opts = { buffer = bufnr, silent = true }
	local km = M.config.options.keymaps

	if km.run_block then
		vim.keymap.set("n", km.run_block, function()
			M.run_block()
		end, opts)
	end

	if km.run_all then
		vim.keymap.set("n", km.run_all, function()
			M.run_all()
		end, opts)
	end

	if km.clear_results then
		vim.keymap.set("n", km.clear_results, function()
			M.clear_results()
		end, opts)
	end

	if km.toggle_inspector then
		vim.keymap.set("n", km.toggle_inspector, function()
			M.toggle_inspector()
		end, opts)
	end

	if km.toggle_logs then
		vim.keymap.set("n", km.toggle_logs, function()
			M.toggle_logs()
		end, opts)
	end

	if km.toggle_output then
		vim.keymap.set("n", km.toggle_output, function()
			M.toggle_output()
		end, opts)
	end
end

-- Run the code block under cursor
function M.run_block(bufnr, block_index)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local blocks = M.parser.parse_blocks(bufnr)

	-- Parse blocks if not specified
	if not block_index then
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = cursor[1]

		-- Find which block the cursor is in
		for i, block in ipairs(blocks) do
			if line >= block.start_line and line <= block.end_line then
				block_index = i
				break
			end
		end

		if not block_index then
			vim.notify("No code block found at cursor", vim.log.levels.WARN)
			return
		end
	end

	-- Get the block object
	local block = blocks[block_index]
	if not block then
		vim.notify("Invalid block index", vim.log.levels.ERROR)
		return
	end

	-- Get preceding lua blocks
	local preceding = M.parser.get_preceding_lua_blocks(blocks, block.id)

	-- Execute the block
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end

	-- Set running state and update UI
	local state = M.executor.get_state(path)
	state.block_states[block.id] = "running"
	M.ui.set_block_sign(bufnr, block.start_line, "running")
	vim.cmd("redraw")

	M.executor.execute_block(path, block, preceding)

	-- Update UI
	M.update_ui(bufnr)

	-- Auto-open output pane if configured (only if inspector is not open)
	if
		M.config.options.auto_open_output and not (M.ui.inspector_win and vim.api.nvim_win_is_valid(M.ui.inspector_win))
	then
		M.ui.toggle_inspector(state)
		-- M.ui.show_output(state, block.id, block)
	end
end

-- Run all code blocks in buffer
function M.run_all(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end

	local blocks = M.parser.parse_blocks(bufnr)
	local state = M.executor.get_state(path)

	for i, block in ipairs(blocks) do
		if block.type == "lua" then
			-- Set running state and update UI
			state.block_states[block.id] = "running"
			M.ui.set_block_sign(bufnr, block.start_line, "running")
			vim.cmd("redraw")

			local preceding = M.parser.get_preceding_lua_blocks(blocks, block.id)
			M.executor.execute_block(path, block, preceding)

			-- Update UI after each block
			M.update_ui(bufnr)
		end
	end

	-- Update UI
	M.update_ui(bufnr)
end

-- Clear all results
function M.clear_results(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path ~= "" then
		M.executor.clear_state(path)
	end
	M.ui.clear_signs(bufnr)
	M.ui.clear_virtual_text(bufnr)

	vim.notify("Cleared all results", vim.log.levels.INFO)
end

-- Toggle inspector window
function M.toggle_inspector(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end
	local state = M.executor.get_state(path)
	M.ui.toggle_inspector(state)
end

-- Toggle logs window
function M.toggle_logs(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	M.ui.toggle_logs(bufnr)
end

-- Toggle output window
function M.toggle_output(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end

	-- Find the block under cursor
	local blocks = M.parser.parse_blocks(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local block_id = nil
	local block = nil

	for i, b in ipairs(blocks) do
		if line >= b.start_line and line <= b.end_line then
			block_id = b.id
			block = b
			break
		end
	end

	if not block_id then
		vim.notify("No code block found at cursor", vim.log.levels.WARN)
		return
	end

	M.ui.toggle_output(bufnr, block_id, block)
end

-- Update UI (signs, virtual text)
function M.update_ui(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local blocks = M.parser.parse_blocks(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end
	local state = M.executor.get_state(path)

	-- Clear existing virtual text
	M.ui.clear_virtual_text(bufnr)

	-- Update signs
	if M.config.options.signs.enabled then
		for _, block in ipairs(blocks) do
			local block_state = state.block_states[block.id]
			if block_state then
				M.ui.set_block_sign(bufnr, block.start_line, block_state)
			end
		end
	end

	-- Update virtual text for outputs and request counts
	if M.config.options.virtual_text.enabled then
		for _, block in ipairs(blocks) do
			-- Show output if available
			local output = state.block_outputs and state.block_outputs[block.id]
			if output then
				M.ui.set_virtual_text(bufnr, block.end_line, " → " .. output)
			end

			-- Show request count
			local requests = state.requests[block.id]
			if requests and #requests > 0 then
				local text = string.format(" (%d request%s)", #requests, #requests == 1 and "" or "s")
				M.ui.set_virtual_text(bufnr, block.start_line, text)
			end
		end
	end

	-- Update inspector if it's open
	M.ui.render_inspector(state)
	-- Update log window if it's open
	M.ui.render_log(state)
	-- if M.ui.inspector_win and vim.api.nvim_win_is_valid(M.ui.inspector_win) then
	--     M.ui.render_inspector(state)
	-- end

	-- Update output pane if it's open for one of these blocks
	-- if M.ui.output_win and vim.api.nvim_win_is_valid(M.ui.output_win) and M.ui.current_output_block_id then
	--     for _, block in ipairs(blocks) do
	--         if block.id == M.ui.current_output_block_id then
	--             M.ui.render_output(state, M.ui.current_output_block_id, block)
	--             break
	--         end
	--     end
	-- end
end

-- Start HTTP server for current buffer
function M.start_server(bufnr, port)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	port = port or 8080

	-- Stop existing server if any
	if M.servers[bufnr] then
		M.server.stop(M.servers[bufnr])
	end

	-- Start new server
	local path = vim.api.nvim_buf_get_name(bufnr)
	local server_id = M.server.start(port, path)

	if server_id then
		M.servers[bufnr] = server_id
		vim.notify("Server started on port " .. port, vim.log.levels.INFO)
		return server_id
	else
		vim.notify("Failed to start server", vim.log.levels.ERROR)
		return nil
	end
end

-- Stop HTTP server for current buffer
function M.stop_server(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.servers[bufnr] then
		M.server.stop(M.servers[bufnr])
		M.servers[bufnr] = nil
		vim.notify("Server stopped", vim.log.levels.INFO)
	else
		vim.notify("No server running", vim.log.levels.WARN)
	end
end

-- Create a new notebook
function M.new_notebook(name)
	if not name or name == "" then
		name = vim.fn.input("Notebook name: ")
		if name == "" then
			return
		end
	end

	local path, err = M.storage.create_notebook(name)
	if not path then
		vim.notify(err or "Failed to create notebook", vim.log.levels.ERROR)
		return
	end

	-- Open the new notebook
	M.storage.open_notebook(path)
	vim.notify("Created notebook: " .. name, vim.log.levels.INFO)
end

-- Open an existing notebook
function M.open_notebook(name)
	if not name or name == "" then
		-- Show picker if no name provided
		M.pick_notebook()
		return
	end

	local path, err = M.storage.open_notebook(name)
	if not path then
		vim.notify(err or "Failed to open notebook", vim.log.levels.ERROR)
		return
	end
end

-- Pick a notebook using Telescope or vim.ui.select
function M.pick_notebook()
	local notebooks = M.storage.list_notebooks()

	if #notebooks == 0 then
		vim.notify("No notebooks found", vim.log.levels.WARN)
		return
	end

	-- Check if Telescope is available
	local has_telescope = pcall(require, "telescope")
	if has_telescope then
		require("sandman.telescope").pick_notebook()
	else
		-- Fallback to vim.ui.select
		local items = {}
		for _, nb in ipairs(notebooks) do
			table.insert(items, nb.name)
		end

		vim.ui.select(items, {
			prompt = "Select notebook:",
		}, function(choice)
			if choice then
				M.storage.open_notebook(choice)
			end
		end)
	end
end

-- Delete a notebook
function M.delete_notebook(name)
	if not name or name == "" then
		name = vim.fn.expand("%:t")
	end

	local ok, err = M.storage.delete_notebook(name)
	if not ok then
		vim.notify(err or "Failed to delete notebook", vim.log.levels.ERROR)
		return
	end

	vim.notify("Deleted notebook: " .. name, vim.log.levels.INFO)
end

-- Export notebook state to JSON
function M.export_state(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end
	local state = M.executor.get_state(path)

	local exportable = {
		block_states = state.block_states,
		block_outputs = state.block_outputs,
		requests = state.requests,
		logs = state.logs,
	}

	local json = M.utils.json.encode(exportable)

	local export_dir = vim.fn.expand("~/.sandman/exported_states")
	vim.fn.mkdir(export_dir, "p")

	local filename = vim.fn.fnamemodify(path, ":t:r") .. "_state.json"
	local export_path = export_dir .. "/" .. filename

	local file = io.open(export_path, "w")
	if file then
		file:write(json)
		file:close()
		vim.notify("Exported state to " .. export_path, vim.log.levels.INFO)
	else
		vim.notify("Failed to export state", vim.log.levels.ERROR)
	end
end

function M.open_env(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		vim.notify("No file associated with buffer", vim.log.levels.WARN)
		return
	end

	M.storage.open_env(path)
end

function M.reload_env_for_notebook(env_bufnr)
	local env_path = vim.api.nvim_buf_get_name(env_bufnr)
	if env_path == "" then
		return
	end

	local notebook_path = env_path:gsub("%.env$", ".md")
	
	if vim.fn.filereadable(notebook_path) == 1 then
		local env = M.storage.load_env(notebook_path)
		M.executor.set_env(notebook_path, env)
		vim.notify("Reloaded environment variables", vim.log.levels.INFO)
	end
end

return M
