-- Telescope integration for sandman.nvim
local M = {}

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  return M
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local storage = require('sandman.storage')

-- Pick a notebook to open
function M.pick_notebook(opts)
  opts = opts or {}

  local notebooks = storage.list_notebooks()

  if #notebooks == 0 then
    vim.notify('No notebooks found', vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = 'Sandman Notebooks',
    finder = finders.new_table({
      results = notebooks,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.name,
          ordinal = entry.name,
          path = entry.path,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = 'Preview',
      define_preview = function(self, entry)
        local lines = vim.fn.readfile(entry.path)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        storage.open_notebook(selection.path)
      end)

      -- Delete notebook with <C-d>
      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        storage.delete_notebook(selection.path)
      end)

      -- Copy notebook with <C-c>
      map('i', '<C-c>', function()
        local selection = action_state.get_selected_entry()
        local new_name = vim.fn.input('New name: ')
        if new_name ~= '' then
          local path, err = storage.copy_notebook(selection.path, new_name)
          if path then
            vim.notify('Copied to ' .. new_name, vim.log.levels.INFO)
          else
            vim.notify(err, vim.log.levels.ERROR)
          end
        end
      end)

      return true
    end,
  }):find()
end

-- Pick a code block in the current buffer
function M.pick_block(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_get_current_buf()
  local parser = require('sandman.parser')
  local all_blocks = parser.parse_blocks(bufnr)

  local blocks = {}
  for _, block in ipairs(all_blocks) do
    if block.type == 'lua' then
      table.insert(blocks, block)
    end
  end

  if #blocks == 0 then
    vim.notify('No lua code blocks found', vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = 'Code Blocks',
    finder = finders.new_table({
      results = blocks,
      entry_maker = function(entry)
        local lang = entry.type or 'unknown'
        local lines = vim.split(entry.code, '\n', { plain = true })
        local line_count = #lines
        local display = string.format('[%s] Lines %d-%d (%d lines)', lang, entry.start_line, entry.end_line, line_count)
        return {
          value = entry,
          display = display,
          ordinal = display,
          lnum = entry.start_line,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = 'Block Preview',
      define_preview = function(self, entry)
        local lines = vim.split(entry.value.code, '\n', { plain = true })
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', entry.value.type or 'text')
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- Jump to block
        vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
      end)

      -- Execute block with <CR>
      map('i', '<C-e>', function()
        local selection = action_state.get_selected_entry()
        local sandman = require('sandman')
        -- Find block index in all blocks
        for i, block in ipairs(all_blocks) do
          if block.start_line == selection.value.start_line then
            sandman.run_block(bufnr, i)
            break
          end
        end
      end)

      return true
    end,
  }):find()
end

-- Pick requests from execution history
function M.pick_requests(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then
    vim.notify('No file associated with buffer', vim.log.levels.WARN)
    return
  end

  local executor = require('sandman.executor')
  local state = executor.get_state(path)

  local requests = {}
  for block_id, block_requests in pairs(state.requests) do
    for _, req in ipairs(block_requests) do
      table.insert(requests, {
        block_id = block_id,
        request = req,
      })
    end
  end

  if #requests == 0 then
    vim.notify('No requests found', vim.log.levels.WARN)
    return
  end

  pickers.new(opts, {
    prompt_title = 'Request History',
    finder = finders.new_table({
      results = requests,
      entry_maker = function(entry)
        local req = entry.request
        local display = string.format('[Block %d] %s %s - %d', entry.block_id, req.method, req.url, req.response.status or 0)
        return {
          value = entry,
          display = display,
          ordinal = display,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = 'Response Preview',
      define_preview = function(self, entry)
        local req = entry.value.request
        local lines = {}

        -- Request info
        table.insert(lines, '# Request')
        table.insert(lines, string.format('%s %s', req.method, req.url))
        table.insert(lines, '')

        -- Request headers
        if req.headers and next(req.headers) then
          table.insert(lines, '## Request Headers')
          for k, v in pairs(req.headers) do
            table.insert(lines, string.format('%s: %s', k, v))
          end
          table.insert(lines, '')
        end

        -- Response info
        table.insert(lines, '# Response')
        table.insert(lines, string.format('Status: %d', req.status or 0))
        table.insert(lines, '')

        -- Response headers
        if req.response_headers and next(req.response_headers) then
          table.insert(lines, '## Response Headers')
          for k, v in pairs(req.response_headers) do
            table.insert(lines, string.format('%s: %s', k, v))
          end
          table.insert(lines, '')
        end

        -- Response body
        if req.body then
          table.insert(lines, '## Response Body')
          table.insert(lines, req.body)
        end

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'markdown')
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        -- Open inspector at this request
        local ui = require('sandman.ui')
        ui.show_inspector(bufnr, selection.value.block_id)
      end)

      return true
    end,
  }):find()
end

return M
