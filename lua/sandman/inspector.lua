local state = {
	left_buf = nil,
	right_buf = nil,
	left_win = nil,
	right_win = nil,
	current_tab = 1,
	collapsed = {},
	tabs = {
		{
			name = "1. Inspector",
			sections = {
				{ name = "Headers", content = { "  date = Fri, 05 Dec 2025 11:03:48 GMT" } },
				{ name = "Response", content = { "  obj1 = {}" } },
			},
		},
		{
			name = "2. Logs",
			sections = {
				{ name = "Errors", content = { "  Error 1", "  Error 2" } },
				{ name = "Warnings", content = { "  Warning 1" } },
				{ name = "Info", content = { "  Info log 1", "  Info log 2", "  Info log 3" } },
			},
		},
		{
			name = "3. Docs",
			sections = {
				{ name = "API Reference", content = { "  Documentation here" } },
			},
		},
	},
}

function M.open()
	state.left_buf = vim.api.nvim_create_buf(false, true)
	state.right_buf = vim.api.nvim_create_buf(false, true)

	vim.bo[state.left_buf].modifiable = true
	vim.bo[state.left_buf].buftype = "nofile"

	vim.bo[state.right_buf].modifiable = false
	vim.bo[state.right_buf].buftype = "nofile"

	vim.cmd("tabnew")
	state.left_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.left_win, state.left_buf)

	vim.cmd("vsplit")
	state.right_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.right_win, state.right_buf)

	local total_width = vim.o.columns
	vim.api.nvim_win_set_width(state.left_win, math.floor(total_width / 2))

	vim.api.nvim_set_current_win(state.left_win)

	for _, buf in ipairs({ state.left_buf, state.right_buf }) do
		vim.api.nvim_buf_set_keymap(buf, "n", "<leader>1", "", {
			callback = function()
				M.switch_tab(1)
			end,
			noremap = true,
		})
		vim.api.nvim_buf_set_keymap(buf, "n", "<leader>2", "", {
			callback = function()
				M.switch_tab(2)
			end,
			noremap = true,
		})
		vim.api.nvim_buf_set_keymap(buf, "n", "<leader>3", "", {
			callback = function()
				M.switch_tab(3)
			end,
			noremap = true,
		})
		vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
			callback = function()
				M.toggle_section()
			end,
			noremap = true,
		})
	end

	M.render_right_buffer()
end

function _G.my_fold_expr()
	local line = vim.fn.getline(vim.v.lnum)
	local next_line = vim.fn.getline(vim.v.lnum + 1)

	-- Current line starts with special char = start fold
	if line:match("^▼") then
		return ">1"
	end

	-- Next line starts with special char = end current fold
	if next_line:match("^▼") or vim.v.lnum == vim.fn.line("$") then
		return "<1"
	end

	-- Otherwise, same level as previous
	return "="
end

function _G.my_fold_text()
	local line = vim.fn.getline(vim.v.foldstart)
	return line:gsub("^▼", "▶")
end

function M.render_right_buffer()
	vim.wo[state.right_win].foldmethod = "expr"
	vim.wo[state.right_win].foldexpr = "v:lua.my_fold_expr()"
	vim.wo[state.right_win].foldlevel = 0 -- Start with folds closed
	vim.wo[state.right_win].foldtext = "v:lua.my_fold_text()"

	local lines = {}

	local tab_line = ""
	for i, tab in ipairs(state.tabs) do
		if i == state.current_tab then
			tab_line = tab_line .. "[ " .. tab.name .. " ]"
		else
			tab_line = tab_line .. "  " .. tab.name .. "  "
		end
	end
	table.insert(lines, tab_line)
	table.insert(lines, string.rep("─", 50))
	table.insert(lines, "")

	local current_tab_data = state.tabs[state.current_tab]
	if current_tab_data.sections then
		for _, section in ipairs(current_tab_data.sections) do
			local section_key = state.current_tab .. "_" .. section.name
			local is_collapsed = state.collapsed[section_key]
			local icon = is_collapsed and "▶" or "▼"

			table.insert(lines, icon .. " " .. section.name)

			if not is_collapsed then
				for _, content_line in ipairs(section.content) do
					table.insert(lines, content_line)
				end
			end
		end
	end

	vim.bo[state.right_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.right_buf, 0, -1, false, lines)
	vim.bo[state.right_buf].modifiable = false
end

function M.switch_tab(tab_index)
	state.current_tab = tab_index
	M.render_right_buffer()

	-- Place cursor on first section headline in right window
	local lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
	for idx, l in ipairs(lines) do
		if l:match("^[▶▼]") then
			vim.api.nvim_win_set_cursor(state.right_win, { idx, 0 })
			break
		end
	end
end

function M.toggle_section()
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	local line_nr = cursor[1]
	local lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
	local line = lines[line_nr] or ""

	if line:match("^[▶▼]") then
		local section_name = line:match("^[▶▼]%s*(.+)$")
		if section_name then
			local section_key = state.current_tab .. "_" .. section_name
			local old_val = state.collapsed[section_key]
			state.collapsed[section_key] = not old_val
			M.render_right_buffer()
			-- After redraw: find section line again; move cursor to it
			local new_lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
			for idx, l in ipairs(new_lines) do
				if l:match("^[▶▼]%s+" .. vim.pesc(section_name) .. "$") then
					vim.api.nvim_win_set_cursor(win, { idx, 0 })
					break
				end
			end
		end
	else
	end
end

function M.update_section_content(tab_index, section_name, content)
	local tab = state.tabs[tab_index]
	if not (tab and tab.sections) then
		return
	end

	for _, section in ipairs(tab.sections) do
		if section.name == section_name then
			section.content = content

			if state.current_tab == tab_index then
				local section_key = tab_index .. "_" .. section_name
				local is_collapsed = state.collapsed[section_key]

				if not is_collapsed then
					-- Find section line range
					local lines = vim.api.nvim_buf_get_lines(state.right_buf, 0, -1, false)
					local start_line, end_line

					for idx, line in ipairs(lines) do
						if line:match("^[▶▼]%s+" .. vim.pesc(section_name) .. "$") then
							start_line = idx
						elseif start_line and line:match("^[▶▼]") then
							end_line = idx - 1
							break
						end
					end

					if start_line then
						end_line = end_line or #lines

						-- Update only this section's content
						vim.bo[state.right_buf].modifiable = true
						vim.api.nvim_buf_set_lines(state.right_buf, start_line, end_line, false, content)
						vim.bo[state.right_buf].modifiable = false
					end
				end
			end
			break
		end
	end
end

return M
