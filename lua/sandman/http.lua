-- HTTP client using curl
local M = {}
local utils = require("sandman.utils")

-- Execute curl command
local function exec_curl(args, callback)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local stdout_data = {}
  local stderr_data = {}
  
  local handle, pid
  handle, pid = vim.loop.spawn("curl", {
    args = args,
    stdio = {nil, stdout, stderr}
  }, function(code, signal)
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
    handle:close()
    
    vim.schedule(function()
      callback(code, table.concat(stdout_data), table.concat(stderr_data))
    end)
  end)
  
  if not handle then
    callback(-1, "", "Failed to spawn curl process")
    return
  end
  
  stdout:read_start(function(err, data)
    if err then
      callback(-1, "", err)
    elseif data then
      table.insert(stdout_data, data)
    end
  end)
  
  stderr:read_start(function(err, data)
    if err then
      -- Ignore stderr read errors
    elseif data then
      table.insert(stderr_data, data)
    end
  end)
end

-- Parse HTTP response
local function parse_response(raw_response)
  local headers_end = raw_response:find("\r?\n\r?\n")
  if not headers_end then
    return {
      status = 0,
      headers = {},
      body = raw_response,
    }
  end
  
  local headers_section = raw_response:sub(1, headers_end - 1)
  local body = raw_response:sub(headers_end + 4) -- Skip the double newline
  
  local lines = vim.split(headers_section, "\r?\n")
  local status_line = lines[1]
  local status = tonumber(status_line:match("HTTP/%S+ (%d+)")) or 0
  
  local headers = {}
  for i = 2, #lines do
    local key, value = lines[i]:match("^([^:]+):%s*(.+)$")
    if key and value then
      headers[key:lower()] = value
    end
  end
  
  return {
    status = status,
    headers = headers,
    body = body,
  }
end

-- Build headers array for curl
local function build_headers(headers)
  local result = {}
  if headers then
    for key, value in pairs(headers) do
      table.insert(result, "-H")
      table.insert(result, key .. ": " .. value)
    end
  end
  return result
end

-- HTTP request function
function M.request(method, url, headers, body, callback)
  local args = {
    "-i", -- Include headers in output
    "-s", -- Silent mode
    "-X", method,
  }
  
  -- Add headers
  local header_args = build_headers(headers)
  for _, arg in ipairs(header_args) do
    table.insert(args, arg)
  end
  
  -- Add body if present
  if body then
    table.insert(args, "-d")
    table.insert(args, body)
  end
  
  -- Add URL
  table.insert(args, url)
  
  exec_curl(args, function(code, stdout, stderr)
    if code ~= 0 then
      callback({
        error = true,
        message = stderr ~= "" and stderr or "HTTP request failed",
        status = 0,
      })
    else
      local response = parse_response(stdout)
      callback(response)
    end
  end)
end

-- Convenience methods
function M.get(url, headers, callback)
  return M.request("GET", url, headers, nil, callback)
end

function M.post(url, headers, body, callback)
  return M.request("POST", url, headers, body, callback)
end

function M.put(url, headers, body, callback)
  return M.request("PUT", url, headers, body, callback)
end

function M.delete(url, headers, callback)
  return M.request("DELETE", url, headers, nil, callback)
end

function M.patch(url, headers, body, callback)
  return M.request("PATCH", url, headers, body, callback)
end

return M
