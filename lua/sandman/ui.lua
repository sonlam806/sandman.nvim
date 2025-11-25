-- UI components for Sandman
local M = {}
local config = require("sandman.config")

-- Window IDs
M.inspector_win = nil
M.inspector_buf = nil
M.log_win = nil
M.log_buf = nil

-- Create a floating window
local function create_float(title, width, height, row, col)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'sandman')
  
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  }
  
  local win = vim.api.nvim_open_win(buf, true, opts)
  return win, buf
end

-- Create a split window
local function create_split(title, position, size)
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create split
  if position == 'right' then
    vim.cmd('vsplit')
    vim.cmd('wincmd L')
    vim.api.nvim_win_set_width(0, size)
  elseif position == 'left' then
    vim.cmd('vsplit')
    vim.cmd('wincmd H')
    vim.api.nvim_win_set_width(0, size)
  elseif position == 'bottom' then
    vim.cmd('split')
    vim.cmd('wincmd J')
    vim.api.nvim_win_set_height(0, size)
  elseif position == 'top' then
    vim.cmd('split')
    vim.cmd('wincmd K')
    vim.api.nvim_win_set_height(0, size)
  end
  
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'sandman')
  vim.api.nvim_buf_set_name(buf, title)
  
  -- Return to original window
  vim.api.nvim_set_current_win(current_win)
  
  return win, buf
end

-- Show inspector window (open if not already open)
function M.show_inspector(bufnr, block_id)
  local opts = config.get()
  
  -- Get the state for this buffer
  local executor = require("sandman.executor")
  local state = executor.get_state(bufnr)
  
  -- Open inspector if not already open
  if not M.inspector_win or not vim.api.nvim_win_is_valid(M.inspector_win) then
    M.inspector_win, M.inspector_buf = create_split(
      "Sandman Inspector",
      opts.inspector_position,
      opts.inspector_size
    )
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
    M.inspector_win, M.inspector_buf = create_split(
      "Sandman Inspector",
      opts.inspector_position,
      opts.inspector_size
    )
    M.render_inspector(state)
  end
end

-- Render inspector content
function M.render_inspector(state, focus_block_id)
  if not M.inspector_buf or not vim.api.nvim_buf_is_valid(M.inspector_buf) then
    return
  end
  
  local lines = {"# Sandman Inspector", ""}
  
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
        
        table.insert(lines, string.format("%d. [%s] %s %s", i, status, method, url))
        
        -- Show headers
        if req.headers and next(req.headers) then
          table.insert(lines, "   Headers:")
          for k, v in pairs(req.headers) do
            table.insert(lines, string.format("     %s: %s", k, v))
          end
        end
        
        -- Show body preview
        if req.body and req.body ~= "" then
          local body_preview = req.body:sub(1, 100)
          if #req.body > 100 then
            body_preview = body_preview .. "..."
          end
          table.insert(lines, "   Body: " .. body_preview)
        end
        
        -- Show response
        if req.response then
          table.insert(lines, string.format("   Response: %s", req.response.status))
          if req.response.body then
            local resp_preview = req.response.body:sub(1, 100)
            if #req.response.body > 100 then
              resp_preview = resp_preview .. "..."
            end
            table.insert(lines, "   " .. resp_preview)
          end
        end
        
        table.insert(lines, "")
      end
    end
  end
  
  if total_requests == 0 then
    table.insert(lines, "No requests yet. Run a block with HTTP calls to see them here.")
  end
  
  vim.api.nvim_buf_set_option(M.inspector_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.inspector_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.inspector_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(M.inspector_buf, 'modified', false)
end

-- Toggle log window
function M.toggle_log(state)
  if M.log_win and vim.api.nvim_win_is_valid(M.log_win) then
    vim.api.nvim_win_close(M.log_win, true)
    M.log_win = nil
    M.log_buf = nil
  else
    local opts = config.get()
    M.log_win, M.log_buf = create_split(
      "Sandman Log",
      opts.log_position,
      opts.log_size
    )
    M.render_log(state)
  end
end

-- Render log content
function M.render_log(state)
  if not M.log_buf or not vim.api.nvim_buf_is_valid(M.log_buf) then
    return
  end
  
  local lines = {"# Sandman Log", ""}
  
  if #state.logs > 0 then
    for _, log in ipairs(state.logs) do
      local timestamp = os.date("%H:%M:%S", log.timestamp)
      table.insert(lines, string.format("[%s] Block %d: %s", timestamp, log.block_id, log.message))
    end
  else
    table.insert(lines, "No log messages yet.")
  end
  
  vim.api.nvim_buf_set_option(M.log_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.log_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.log_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(M.log_buf, 'modified', false)
end

-- Update signs for block states
function M.update_signs(bufnr, blocks, block_states)
  local opts = config.get()
  if not opts.show_signs then
    return
  end
  
  -- Clear existing signs
  vim.fn.sign_unplace("sandman", {buffer = bufnr})
  
  -- Place signs for each lua block
  for _, block in ipairs(blocks) do
    if block.type == "lua" then
      local state = block_states[block.id] or "empty"
      local sign_name = "SandmanSign" .. state:sub(1,1):upper() .. state:sub(2)
      
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
          virt_text = {{string.format(" %d request%s", #block_requests, #block_requests > 1 and "s" or ""), "SandmanVirtualText"}},
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
    local sign_name = "SandmanSign" .. name:sub(1,1):upper() .. name:sub(2)
    vim.fn.sign_define(sign_name, {
      text = sign.text,
      texthl = sign.hl,
    })
  end
end

-- Initialize highlights
function M.init_highlights()
  local opts = config.get()
  
  for name, hl in pairs(opts.highlights) do
    local hl_def = {}
    if hl.fg then hl_def.fg = hl.fg end
    if hl.bg then hl_def.bg = hl.bg end
    if hl.bold then hl_def.bold = true end
    if hl.italic then hl_def.italic = true end
    
    vim.api.nvim_set_hl(0, name, hl_def)
  end
end

return M
