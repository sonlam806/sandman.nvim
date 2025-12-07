-- Storage manager for centralized notebook management
local M = {}

local config = require('sandman.config')
local uv = vim.loop

-- Get the notebooks directory
function M.get_notebooks_dir()
  local dir = vim.fn.expand(config.options.notebooks_dir)
  return dir
end

-- Ensure notebooks directory exists
function M.ensure_notebooks_dir()
  local dir = M.get_notebooks_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
  return dir
end

-- List all notebooks
function M.list_notebooks()
  local dir = M.ensure_notebooks_dir()
  local notebooks = {}
  
  local handle = uv.fs_scandir(dir)
  if handle then
    while true do
      local name, type = uv.fs_scandir_next(handle)
      if not name then break end
      
      if type == 'file' and name:match('%.md$') then
        local path = dir .. '/' .. name
        local stat = uv.fs_stat(path)
        table.insert(notebooks, {
          name = name,
          path = path,
          mtime = stat and stat.mtime.sec or 0,
        })
      end
    end
  end
  
  -- Sort by modification time (newest first)
  table.sort(notebooks, function(a, b)
    return a.mtime > b.mtime
  end)
  
  return notebooks
end

-- Create a new notebook
function M.create_notebook(name)
  local dir = M.ensure_notebooks_dir()
  
  -- Ensure .md extension
  if not name:match('%.md$') then
    name = name .. '.md'
  end
  
  local path = dir .. '/' .. name
  
  -- Check if file already exists
  if vim.fn.filereadable(path) == 1 then
    return nil, 'Notebook already exists: ' .. name
  end
  
  -- Create new file with template
  local template = [[# ]] .. name:gsub('%.md$', '') .. [[


## Example Request

```lua
local res = sandman.http.get('https://api.github.com')
sandman.log('Status: ' .. res.status)
```

## Notes

Add your API documentation and tests here.
]]
  
  local file = io.open(path, 'w')
  if not file then
    return nil, 'Failed to create notebook: ' .. name
  end
  
  file:write(template)
  file:close()
  
  return path
end

-- Open a notebook
function M.open_notebook(name_or_path)
  local path = name_or_path
  
  -- If not an absolute path, assume it's in notebooks dir
  if not vim.startswith(name_or_path, '/') then
    local dir = M.ensure_notebooks_dir()
    
    -- Ensure .md extension
    local name = name_or_path
    if not name:match('%.md$') then
      name = name .. '.md'
    end
    
    path = dir .. '/' .. name
  end
  
  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil, 'Notebook not found: ' .. path
  end
  
  -- Open in new tab
  vim.cmd('tabnew ' .. vim.fn.fnameescape(path))
  
  return path
end

-- Delete a notebook
function M.delete_notebook(name_or_path)
  local path = name_or_path
  
  -- If not an absolute path, assume it's in notebooks dir
  if not vim.startswith(name_or_path, '/') then
    local dir = M.get_notebooks_dir()
    
    -- Ensure .md extension
    local name = name_or_path
    if not name:match('%.md$') then
      name = name .. '.md'
    end
    
    path = dir .. '/' .. name
  end
  
  -- Check if file exists
  if vim.fn.filereadable(path) == 0 then
    return nil, 'Notebook not found: ' .. path
  end
  
  -- Confirm deletion
  local confirm = vim.fn.confirm('Delete notebook ' .. vim.fn.fnamemodify(path, ':t') .. '?', '&Yes\n&No', 2)
  if confirm ~= 1 then
    return nil, 'Cancelled'
  end
  
  -- Delete file
  local ok = vim.fn.delete(path)
  if ok ~= 0 then
    return nil, 'Failed to delete notebook'
  end
  
  return true
end

-- Get .env file path for current notebook
function M.get_env_file(notebook_path)
  local dir = vim.fn.fnamemodify(notebook_path, ':h')
  local name = vim.fn.fnamemodify(notebook_path, ':t:r')
  return dir .. '/' .. name .. '.env'
end

-- Load environment variables for notebook
function M.load_env(notebook_path)
  local env_file = M.get_env_file(notebook_path)
  
  if vim.fn.filereadable(env_file) == 0 then
    return {}
  end
  
  local env = {}
  local lines = vim.fn.readfile(env_file)
  
  for _, line in ipairs(lines) do
    -- Skip comments and empty lines
    if not line:match('^%s*#') and line:match('%S') then
      local key, value = line:match('^%s*([%w_]+)%s*=%s*(.*)%s*$')
      if key and value then
        -- Remove quotes if present
        value = value:gsub('^["\'](.*)["\'"]$', '%1')
        env[key] = value
      end
    end
  end
  
  return env
end

-- Copy notebook to another location
function M.copy_notebook(name_or_path, new_name)
  local src_path = name_or_path
  
  -- If not an absolute path, assume it's in notebooks dir
  if not vim.startswith(name_or_path, '/') then
    local dir = M.get_notebooks_dir()
    
    -- Ensure .md extension
    local name = name_or_path
    if not name:match('%.md$') then
      name = name .. '.md'
    end
    
    src_path = dir .. '/' .. name
  end
  
  -- Check if source exists
  if vim.fn.filereadable(src_path) == 0 then
    return nil, 'Notebook not found: ' .. src_path
  end
  
  -- Create destination path
  local dir = M.ensure_notebooks_dir()
  if not new_name:match('%.md$') then
    new_name = new_name .. '.md'
  end
  local dst_path = dir .. '/' .. new_name
  
  -- Check if destination already exists
  if vim.fn.filereadable(dst_path) == 1 then
    return nil, 'Notebook already exists: ' .. new_name
  end
  
  -- Copy file
  local lines = vim.fn.readfile(src_path)
  vim.fn.writefile(lines, dst_path)
  
  return dst_path
end

function M.open_env(notebook_path)
  local env_file = M.get_env_file(notebook_path)
  
  if vim.fn.filereadable(env_file) == 0 then
    local confirm = vim.fn.confirm('No .env file found. Create one?', '&Yes\n&No', 1)
    if confirm ~= 1 then
      return
    end
    
    local template = [[# Environment variables for ]] .. vim.fn.fnamemodify(notebook_path, ':t:r') .. [[

    # Example:
    # API_KEY=your-secret-key
    # API_URL=https://api.example.com
    ]]
    vim.fn.writefile(vim.split(template, '\n'), env_file)
  end
  
  vim.cmd('split ' .. vim.fn.fnameescape(env_file))
end

return M
