-- Plugin loader for sandman.nvim
-- This file is loaded automatically by Neovim

if vim.g.loaded_sandman then
    return
end
vim.g.loaded_sandman = true

-- Create user commands
vim.api.nvim_create_user_command("SandmanSetup", function()
    -- Setup should be called from init.lua, not via command
    vim.notify(
        'Please call require("sandman").setup() from your init.lua instead',
        vim.log.levels.WARN
    )
end, {
    desc = 'Setup Sandman plugin (use require("sandman").setup() in init.lua instead)',
})

vim.api.nvim_create_user_command("SandmanRunBlock", function()
    require("sandman").run_block()
end, {
    desc = "Run code block under cursor",
})

vim.api.nvim_create_user_command("SandmanRunAll", function()
    require("sandman").run_all()
end, {
    desc = "Run all code blocks in buffer",
})

vim.api.nvim_create_user_command("SandmanClearResults", function()
    require("sandman").clear_results()
end, {
    desc = "Clear all execution results",
})

vim.api.nvim_create_user_command("SandmanToggleInspector", function()
    require("sandman").toggle_inspector()
end, {
    desc = "Toggle request inspector window",
})

vim.api.nvim_create_user_command("SandmanToggleLogs", function()
    require("sandman").toggle_logs()
end, {
    desc = "Toggle logs window",
})

vim.api.nvim_create_user_command("SandmanStartServer", function(opts)
    local port = tonumber(opts.args) or 8080
    require("sandman").start_server(nil, port)
end, {
    nargs = "?",
    desc = "Start HTTP server (default port: 8080)",
})

vim.api.nvim_create_user_command("SandmanStopServer", function()
    require("sandman").stop_server()
end, {
    desc = "Stop HTTP server",
})

vim.api.nvim_create_user_command("SandmanNew", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    require("sandman").new_notebook(name)
end, {
    nargs = "?",
    desc = "Create a new notebook",
})

vim.api.nvim_create_user_command("SandmanOpen", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    require("sandman").open_notebook(name)
end, {
    nargs = "?",
    complete = function()
        local storage = require("sandman.storage")
        local notebooks = storage.list_notebooks()
        local names = {}
        for _, nb in ipairs(notebooks) do
            table.insert(names, nb.name)
        end
        return names
    end,
    desc = "Open an existing notebook",
})

vim.api.nvim_create_user_command("SandmanDelete", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    require("sandman").delete_notebook(name)
end, {
    nargs = "?",
    complete = function()
        local storage = require("sandman.storage")
        local notebooks = storage.list_notebooks()
        local names = {}
        for _, nb in ipairs(notebooks) do
            table.insert(names, nb.name)
        end
        return names
    end,
    desc = "Delete a notebook",
})

vim.api.nvim_create_user_command("SandmanExport", function()
    require("sandman").export_state()
end, {
    desc = "Export execution state to JSON",
})

-- Telescope commands (if Telescope is available)
vim.api.nvim_create_user_command("SandmanPick", function()
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
        require("sandman.telescope").pick_notebook()
    else
        require("sandman").pick_notebook()
    end
end, {
    desc = "Pick a notebook to open",
})

vim.api.nvim_create_user_command("SandmanPickBlock", function()
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
        require("sandman.telescope").pick_block()
    else
        vim.notify(
            "Telescope is required for this command",
            vim.log.levels.WARN
        )
    end
end, {
    desc = "Pick a code block to jump to",
})

vim.api.nvim_create_user_command("SandmanPickRequests", function()
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
        require("sandman.telescope").pick_requests()
    else
        vim.notify(
            "Telescope is required for this command",
            vim.log.levels.WARN
        )
    end
end, {
    desc = "Pick from request history",
})

vim.api.nvim_create_user_command("SandmanEnv", function()
    require("sandman").open_env()
end, {
    desc = "Open .env file for current notebook",
})
