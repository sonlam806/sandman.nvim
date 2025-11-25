-- sandman.nvim configuration
local M = {}

M.defaults = {
  -- Directory where notebooks are stored
  notebook_dir = vim.fn.expand("~/.sandman/notebooks"),
  
  -- Auto-save notebooks after changes
  auto_save = true,
  
  -- Time in ms before auto-save
  auto_save_delay = 2000,
  
  -- Show signs in the gutter for block states
  show_signs = true,
  
  -- Show virtual text for request counts
  show_virtual_text = true,
  
  -- Open inspector window on request
  auto_open_inspector = false,
  
  -- Inspector window position: 'right', 'left', 'bottom'
  inspector_position = "right",
  
  -- Inspector window size
  inspector_size = 50,
  
  -- Log window position
  log_position = "bottom",
  
  -- Log window size
  log_size = 10,
  
  -- HTTP timeout in seconds
  http_timeout = 30,
  
  -- Enable HTTP server support
  enable_server = true,
  
  -- Default server port range
  server_port_range = {8000, 9000},
  
  -- Keymaps (set to false to disable default keymaps)
  keymaps = {
    run_block = "<leader>sr",
    run_all = "<leader>sra",
    toggle_inspector = "<leader>si",
    toggle_log = "<leader>sl",
    clear_state = "<leader>sc",
    new_code_block = "<leader>sn",
    new_markdown_block = "<leader>sm",
  },
  
  -- Signs configuration
  signs = {
    empty = { text = "○", hl = "SandmanSignEmpty" },
    running = { text = "●", hl = "SandmanSignRunning" },
    executed = { text = "✓", hl = "SandmanSignExecuted" },
    errored = { text = "✗", hl = "SandmanSignErrored" },
  },
  
  -- Highlight groups
  highlights = {
    SandmanSignEmpty = { fg = "#6b7280" },
    SandmanSignRunning = { fg = "#3b82f6" },
    SandmanSignExecuted = { fg = "#10b981" },
    SandmanSignErrored = { fg = "#ef4444" },
    SandmanVirtualText = { fg = "#6b7280", italic = true },
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  
  -- Create notebook directory if it doesn't exist
  vim.fn.mkdir(M.options.notebook_dir, "p")
  
  return M.options
end

function M.get()
  return M.options
end

return M
