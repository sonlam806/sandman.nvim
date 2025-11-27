# sandman.nvim

An executable notebook plugin for Neovim, designed for testing and documenting HTTP APIs directly from markdown files.

## Features

- 📝 **Markdown-based notebooks** - Write API tests and documentation in familiar markdown format
- 🚀 **Execute Lua code blocks** - Run HTTP requests and scripts directly in your notebook
- 🔍 **Request inspector** - View request/response history with detailed information
- 📊 **Logs window** - Monitor execution logs in real-time
- 🎯 **Visual feedback** - Signs and virtual text show execution state
- 🌐 **HTTP server** - Start local servers to test webhooks and callbacks
- 📦 **Centralized storage** - All notebooks stored in `~/.sandman/notebooks/`
- 🔭 **Telescope integration** - Quick picker for notebooks, blocks, and requests
- 🔑 **Environment variables** - Support for `.env` files alongside notebooks
- ⚡ **Persistent state** - Execution context maintained across blocks

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'sonlam806/sandman.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',  -- Required
    'nvim-telescope/telescope.nvim',  -- Optional, for pickers
  },
  config = function()
    require('sandman').setup({
      -- Optional configuration (these are defaults)
      notebooks_dir = '~/.sandman/notebooks',
      auto_save = true,
      signs = { enabled = true },
      virtual_text = { enabled = true },
      keymaps = {
        enabled = true,
        run_block = '<leader>sr',
        run_all = '<leader>sR',
        clear_results = '<leader>sc',
        toggle_inspector = '<leader>si',
        toggle_logs = '<leader>sl',
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'sonlam806/sandman.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',  -- Optional
  },
  config = function()
    require('sandman').setup()
  end,
}
```

## Quick Start

### 1. Create a new notebook

```vim
:SandmanNew my-api-test
```

### 2. Write your first request

````markdown
# My API Test

## Basic GET Request

```lua
local res = sandman.http.get('https://api.github.com')
sandman.log('Status: ' .. res.status)
sandman.log('Body: ' .. res.body)
```

## POST Request with Headers

```lua
local res = sandman.http.post('https://httpbin.org/post', {
  headers = {
    ['Content-Type'] = 'application/json',
  },
  body = sandman.json.encode({
    name = 'John Doe',
    email = 'john@example.com',
  }),
})

sandman.log('Response: ' .. sandman.json.encode(res))
```
````

### 3. Run the code block

Position your cursor in a code block and press `<leader>sr` (or `:SandmanRunBlock`)

## Commands

| Command | Description |
|---------|-------------|
| `:SandmanNew [name]` | Create a new notebook |
| `:SandmanOpen [name]` | Open an existing notebook |
| `:SandmanPick` | Pick a notebook using Telescope |
| `:SandmanDelete [name]` | Delete a notebook |
| `:SandmanRunBlock` | Run code block under cursor |
| `:SandmanRunAll` | Run all code blocks in buffer |
| `:SandmanClearResults` | Clear all execution results |
| `:SandmanToggleInspector` | Toggle request inspector window |
| `:SandmanToggleLogs` | Toggle logs window |
| `:SandmanStartServer [port]` | Start HTTP server (default: 8080) |
| `:SandmanStopServer` | Stop HTTP server |
| `:SandmanPickBlock` | Pick a code block (Telescope) |
| `:SandmanPickRequests` | Pick from request history (Telescope) |
| `:SandmanExport` | Export execution state to JSON |

## Sandman API

The `sandman` object is available in all code blocks:

### HTTP Client

```lua
-- GET request
local res = sandman.http.get(url, options)

-- POST request
local res = sandman.http.post(url, options)

-- PUT request
local res = sandman.http.put(url, options)

-- DELETE request
local res = sandman.http.delete(url, options)

-- PATCH request
local res = sandman.http.patch(url, options)

-- Options:
-- {
--   headers = { ['Key'] = 'Value' },
--   body = 'request body',
-- }

-- Response:
-- {
--   status = 200,
--   headers = { ... },
--   body = '...',
-- }
```

### JSON Utilities

```lua
-- Encode table to JSON
local json_string = sandman.json.encode(table)

-- Decode JSON to table
local table = sandman.json.decode(json_string)
```

### Base64

```lua
-- Encode to base64
local encoded = sandman.base64.encode('hello')

-- Decode from base64
local decoded = sandman.base64.decode(encoded)
```

### URI Utilities

```lua
-- Parse URI
local parsed = sandman.uri.parse('https://example.com/path?foo=bar')
-- { scheme = 'https', host = 'example.com', path = '/path', query = 'foo=bar' }

-- Encode URI component
local encoded = sandman.uri.encode('hello world')
-- 'hello%20world'

-- Decode URI component
local decoded = sandman.uri.decode('hello%20world')
-- 'hello world'
```

### JWT

```lua
-- Decode JWT (header and payload only, no verification)
local token = sandman.jwt.decode('eyJhbGciOiJIUzI1...')
-- { header = {...}, payload = {...} }
```

### Environment Variables

```lua
-- Get environment variable (prefixed with SANDMAN_)
local api_key = sandman.getenv('API_KEY')
-- Reads SANDMAN_API_KEY from environment or .env file
```

### Logging

```lua
-- Log a message (shown in logs window)
sandman.log('This is a log message')
sandman.log('Status:', res.status)
```

### UUID Generation

```lua
-- Generate a random UUID
local id = sandman.uuid()
-- '550e8400-e29b-41d4-a716-446655440000'
```

## Environment Variables

Create a `.env` file alongside your notebook with the same name:

```
# my-api-test.env
API_KEY=your-secret-key
API_URL=https://api.example.com
```

Access in your notebook:

```lua
local api_key = sandman.getenv('API_KEY')  -- Reads SANDMAN_API_KEY
local res = sandman.http.get(sandman.getenv('API_URL') .. '/users')
```

## HTTP Server

Start a local server to test webhooks and callbacks:

```lua
-- Define request handlers
sandman.server.on('POST', '/webhook', function(req)
  sandman.log('Received webhook:', req.body)
  return {
    status = 200,
    body = sandman.json.encode({ success = true }),
  }
end)
```

Then start the server:

```vim
:SandmanStartServer 8080
```

## Configuration

Full configuration options:

```lua
require('sandman').setup({
  -- Directory for storing notebooks
  notebooks_dir = '~/.sandman/notebooks',

  -- Auto-save on buffer leave or idle
  auto_save = true,

  -- Signs in the gutter
  signs = {
    enabled = true,
    empty = '○',      -- Block not executed
    running = '●',    -- Block executing
    executed = '✓',   -- Block executed successfully
    errored = '✗',    -- Block errored
  },

  -- Virtual text at end of blocks
  virtual_text = {
    enabled = true,
    prefix = ' ',
  },

  -- Buffer-local keymaps
  keymaps = {
    enabled = true,
    run_block = '<leader>sr',
    run_all = '<leader>sR',
    clear_results = '<leader>sc',
    toggle_inspector = '<leader>si',
    toggle_logs = '<leader>sl',
  },

  -- Highlight groups
  highlights = {
    SandmanSignEmpty = { fg = '#6c7086' },
    SandmanSignRunning = { fg = '#f9e2af' },
    SandmanSignExecuted = { fg = '#a6e3a1' },
    SandmanSignErrored = { fg = '#f38ba8' },
    SandmanVirtualText = { fg = '#6c7086', italic = true },
  },
})
```

## Use Cases

### API Testing

Test your REST APIs directly from markdown documentation:

```lua
-- Test user creation
local user_res = sandman.http.post('https://api.example.com/users', {
  headers = { ['Authorization'] = 'Bearer ' .. sandman.getenv('API_KEY') },
  body = sandman.json.encode({ name = 'Test User', email = 'test@example.com' }),
})

local user_id = sandman.json.decode(user_res.body).id
sandman.log('Created user:', user_id)

-- Test user retrieval
local get_res = sandman.http.get('https://api.example.com/users/' .. user_id, {
  headers = { ['Authorization'] = 'Bearer ' .. sandman.getenv('API_KEY') },
})

sandman.log('Retrieved user:', get_res.body)
```

### Webhook Testing

Test webhook integrations:

```lua
-- Set up webhook handler
sandman.server.on('POST', '/github-webhook', function(req)
  local payload = sandman.json.decode(req.body)
  sandman.log('Received GitHub event:', payload.action)

  return {
    status = 200,
    headers = { ['Content-Type'] = 'application/json' },
    body = sandman.json.encode({ received = true }),
  }
end)

-- Register webhook with GitHub
local res = sandman.http.post('https://api.github.com/repos/owner/repo/hooks', {
  headers = {
    ['Authorization'] = 'Bearer ' .. sandman.getenv('GITHUB_TOKEN'),
    ['Content-Type'] = 'application/json',
  },
  body = sandman.json.encode({
    config = { url = 'http://localhost:8080/github-webhook' },
    events = { 'push', 'pull_request' },
  }),
})
```

### API Documentation

Document APIs with executable examples:

````markdown
# User API

## Create User

Creates a new user account.

**Endpoint:** `POST /api/users`

**Request:**

```lua
local res = sandman.http.post('https://api.example.com/users', {
  headers = { ['Content-Type'] = 'application/json' },
  body = sandman.json.encode({
    name = 'John Doe',
    email = 'john@example.com',
    password = 'secure123',
  }),
})

sandman.log('Status:', res.status)
sandman.log('Response:', res.body)
```

**Response:** `201 Created`

```json
{
  "id": "user_123",
  "name": "John Doe",
  "email": "john@example.com",
  "created_at": "2024-01-01T00:00:00Z"
}
```
````

## Comparison with Original Sandman

This is a Neovim plugin port of the original [Sandman](https://github.com/paullam/sandman) Elixir/Phoenix application. Key differences:

| Feature | Original Sandman | sandman.nvim |
|---------|------------------|--------------|
| Runtime | Elixir/Luerl | Neovim Lua (native) |
| Interface | Web UI | Neovim buffer |
| Storage | File system | Centralized `~/.sandman/notebooks/` |
| Execution | Luerl (Lua in Erlang) | Native Neovim Lua |
| HTTP Client | Elixir HTTP client | curl via vim.loop |
| HTTP Server | Phoenix/Cowboy | Python http.server |
| State Management | GenServer | Per-buffer Lua tables |

## Testing

A test notebook is included in `test_notebook.md` that covers basic functionality:

1. **Clone the repository** and add it to your Neovim runtime path
2. **Open the test notebook**:
   ```vim
   :e sandman.nvim/test_notebook.md
   ```
3. **Run the setup** (if not already done):
   ```vim
   :lua require('sandman').setup()
   ```
4. **Test basic execution**: Place your cursor in the first code block and press `<leader>sr`
5. **Test variable persistence**: Run blocks sequentially to verify state persists
6. **Test HTTP client**: Run the GitHub API example (requires internet connection)
7. **Test utilities**: Verify JSON and Base64 encoding/decoding work
8. **View logs**: Press `<leader>sl` to open the logs window
9. **View inspector**: Press `<leader>si` to see request history

### Known Limitations

- HTTP server functionality requires Python 3 installed
- Some HTTP requests may fail due to network restrictions
- Telescope integration requires telescope.nvim plugin

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Inspired by executable notebook tools like Jupyter and Observable
