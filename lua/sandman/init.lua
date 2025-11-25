-- Main plugin orchestrator for sandman.nvim
local M = {}

M.config = require('sandman.config')
M.parser = require('sandman.parser')
M.executor = require('sandman.executor')
M.http = require('sandman.http')
M.server = require('sandman.server')
M.ui = require('sandman.ui')
M.storage = require('sandman.storage')
M.utils = require('sandman.utils')

-- Track active servers per buffer
M.servers = {}

-- Setup function called by user
function M.setup(opts)
  M.config.setup(opts)

  -- Set up autocommands
  M.setup_autocommands()

  -- Set up highlights
  M.setup_highlights()
end

-- Set up autocommands for markdown files
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup('Sandman', { clear = true })

  -- Initialize buffer when markdown file is opened
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      M.init_buffer(ev.buf)
    end,
  })

  -- Auto-save when leaving buffer or idle
  if M.config.options.auto_save then
    vim.api.nvim_create_autocmd({ 'BufLeave', 'CursorHold' }, {
      group = group,
      pattern = '*.md',
      callback = function(ev)
        if vim.bo[ev.buf].modified then
          vim.cmd('silent write')
        end
      end,
    })
  end

  -- Clean up when buffer is closed
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    pattern = '*.md',
    callback = function(ev)
      M.cleanup_buffer(ev.buf)
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
  if M.config.options.signs.enabled then
    M.ui.setup_signs(bufnr)
  end

  -- Set up buffer-local keymaps if enabled
  if M.config.options.keymaps.enabled then
    M.setup_keymaps(bufnr)
  end

  -- Load environment variables
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path ~= '' then
    local env = M.storage.load_env(path)
    M.executor.set_env(bufnr, env)
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
  M.executor.clear_state(bufnr)

  -- Clear signs
  M.ui.clear_signs(bufnr)
end

-- Set up buffer-local keymaps
function M.setup_keymaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local opts = { buffer = bufnr, silent = true }
  local km = M.config.options.keymaps

  if km.run_block then
    vim.keymap.set('n', km.run_block, function() M.run_block() end, opts)
  end

  if km.run_all then
    vim.keymap.set('n', km.run_all, function() M.run_all() end, opts)
  end

  if km.clear_results then
    vim.keymap.set('n', km.clear_results, function() M.clear_results() end, opts)
  end

  if km.toggle_inspector then
    vim.keymap.set('n', km.toggle_inspector, function() M.toggle_inspector() end, opts)
  end

  if km.toggle_logs then
    vim.keymap.set('n', km.toggle_logs, function() M.toggle_logs() end, opts)
  end
end

-- Run the code block under cursor
function M.run_block(bufnr, block_index)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Parse blocks if not specified
  if not block_index then
    local blocks = M.parser.parse_blocks(bufnr)
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
      vim.notify('No code block found at cursor', vim.log.levels.WARN)
      return
    end
  end

  -- Execute the block
  M.executor.execute_block(bufnr, block_index)

  -- Update UI
  M.update_ui(bufnr)
end

-- Run all code blocks in buffer
function M.run_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local blocks = M.parser.parse_blocks(bufnr)

  for i = 1, #blocks do
    M.executor.execute_block(bufnr, i)
  end

  -- Update UI
  M.update_ui(bufnr)
end

-- Clear all results
function M.clear_results(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M.executor.clear_state(bufnr)
  M.ui.clear_signs(bufnr)
  M.ui.clear_virtual_text(bufnr)

  vim.notify('Cleared all results', vim.log.levels.INFO)
end

-- Toggle inspector window
function M.toggle_inspector(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.ui.toggle_inspector(bufnr)
end

-- Toggle logs window
function M.toggle_logs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.ui.toggle_logs(bufnr)
end

-- Update UI (signs, virtual text)
function M.update_ui(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local blocks = M.parser.parse_blocks(bufnr)
  local state = M.executor.get_state(bufnr)

  -- Update signs
  if M.config.options.signs.enabled then
    for i, block in ipairs(blocks) do
      local block_state = state.blocks[i]
      if block_state then
        M.ui.set_block_sign(bufnr, block.start_line, block_state.state)
      end
    end
  end

  -- Update virtual text
  if M.config.options.virtual_text.enabled then
    for i, block in ipairs(blocks) do
      local block_state = state.blocks[i]
      if block_state and #block_state.requests > 0 then
        local text = string.format('%d request%s', #block_state.requests, #block_state.requests == 1 and '' or 's')
        M.ui.set_virtual_text(bufnr, block.end_line, text)
      end
    end
  end
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
    vim.notify('Server started on port ' .. port, vim.log.levels.INFO)
    return server_id
  else
    vim.notify('Failed to start server', vim.log.levels.ERROR)
    return nil
  end
end

-- Stop HTTP server for current buffer
function M.stop_server(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if M.servers[bufnr] then
    M.server.stop(M.servers[bufnr])
    M.servers[bufnr] = nil
    vim.notify('Server stopped', vim.log.levels.INFO)
  else
    vim.notify('No server running', vim.log.levels.WARN)
  end
end

-- Create a new notebook
function M.new_notebook(name)
  if not name or name == '' then
    name = vim.fn.input('Notebook name: ')
    if name == '' then
      return
    end
  end

  local path, err = M.storage.create_notebook(name)
  if not path then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Open the new notebook
  M.storage.open_notebook(path)
  vim.notify('Created notebook: ' .. name, vim.log.levels.INFO)
end

-- Open an existing notebook
function M.open_notebook(name)
  if not name or name == '' then
    -- Show picker if no name provided
    M.pick_notebook()
    return
  end

  local path, err = M.storage.open_notebook(name)
  if not path then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
end

-- Pick a notebook using Telescope or vim.ui.select
function M.pick_notebook()
  local notebooks = M.storage.list_notebooks()

  if #notebooks == 0 then
    vim.notify('No notebooks found', vim.log.levels.WARN)
    return
  end

  -- Check if Telescope is available
  local has_telescope = pcall(require, 'telescope')
  if has_telescope then
    require('sandman.telescope').pick_notebook()
  else
    -- Fallback to vim.ui.select
    local items = {}
    for _, nb in ipairs(notebooks) do
      table.insert(items, nb.name)
    end

    vim.ui.select(items, {
      prompt = 'Select notebook:',
    }, function(choice)
      if choice then
        M.storage.open_notebook(choice)
      end
    end)
  end
end

-- Delete a notebook
function M.delete_notebook(name)
  if not name or name == '' then
    name = vim.fn.expand('%:t')
  end

  local ok, err = M.storage.delete_notebook(name)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.notify('Deleted notebook: ' .. name, vim.log.levels.INFO)
end

-- Export notebook state to JSON
function M.export_state(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = M.executor.get_state(bufnr)

  local json = M.utils.json_encode(state)
  local path = vim.fn.expand('%:r') .. '_state.json'

  local file = io.open(path, 'w')
  if file then
    file:write(json)
    file:close()
    vim.notify('Exported state to ' .. path, vim.log.levels.INFO)
  else
    vim.notify('Failed to export state', vim.log.levels.ERROR)
  end
end

return M
