-- HTTP server implementation using Python's http.server
local M = {}

-- Store active servers
M.servers = {}

-- Start an HTTP server on the specified port
function M.start(port, notebook_path)
  local server_id = require("sandman.utils").uuid()
  
  -- Create a temporary Python script to run the server
  local server_script = string.format([[
import http.server
import socketserver
import json
import sys
from urllib.parse import parse_qs, urlparse

PORT = %d
routes = {}

class SandmanHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request('GET')
    
    def do_POST(self):
        self.handle_request('POST')
    
    def do_PUT(self):
        self.handle_request('PUT')
    
    def do_DELETE(self):
        self.handle_request('DELETE')
    
    def handle_request(self, method):
        path = urlparse(self.path).path
        query = urlparse(self.path).query
        
        # Read body if present
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length else ''
        
        # Build request object
        request = {
            'method': method,
            'path': path,
            'query': parse_qs(query),
            'headers': dict(self.headers),
            'body': body
        }
        
        # Send to stdout for Neovim to handle
        print(json.dumps({'type': 'request', 'data': request}), flush=True)
        
        # Read response from stdin
        response_line = sys.stdin.readline()
        response = json.loads(response_line)
        
        # Send response
        self.send_response(response.get('status', 200))
        for key, value in response.get('headers', {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(response.get('body', '').encode('utf-8'))
    
    def log_message(self, format, *args):
        pass  # Suppress default logging

with socketserver.TCPServer(("", PORT), SandmanHandler) as httpd:
    print(json.dumps({'type': 'started', 'port': PORT}), flush=True)
    httpd.serve_forever()
]], port)
  
  -- Write the script to a temp file
  local temp_dir = vim.fn.stdpath("cache") .. "/sandman"
  vim.fn.mkdir(temp_dir, "p")
  local script_path = temp_dir .. "/" .. server_id .. ".py"
  local file = io.open(script_path, "w")
  if file then
    file:write(server_script)
    file:close()
  else
    error("Failed to create server script")
  end
  
  -- Start the Python server process
  local stdin = vim.loop.new_pipe(false)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  
  local handle, pid
  handle, pid = vim.loop.spawn("python3", {
    args = {script_path},
    stdio = {stdin, stdout, stderr},
  }, function(code, signal)
    -- Cleanup on exit
    stdin:close()
    stdout:close()
    stderr:close()
    if handle then
      handle:close()
    end
    M.servers[server_id] = nil
    
    -- Delete temp script
    vim.fn.delete(script_path)
  end)
  
  if not handle then
    error("Failed to start HTTP server")
  end
  
  -- Store server info
  M.servers[server_id] = {
    id = server_id,
    port = port,
    handle = handle,
    pid = pid,
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
    routes = {},
    script_path = script_path,
  }
  
  -- Read stdout for requests
  stdout:read_start(function(err, data)
    if err then
      vim.notify("Server error: " .. err, vim.log.levels.ERROR)
    elseif data then
      -- Parse JSON messages from server
      for line in data:gmatch("[^\n]+") do
        local ok, msg = pcall(vim.fn.json_decode, line)
        if ok then
          if msg.type == "started" then
            vim.notify("Server started on port " .. msg.port, vim.log.levels.INFO)
          elseif msg.type == "request" then
            -- Handle request
            M.handle_request(server_id, msg.data)
          end
        end
      end
    end
  end)
  
  return server_id
end

-- Add a route to a server
function M.add_route(server_id, method, path, handler)
  local server = M.servers[server_id]
  if not server then
    error("Server not found: " .. server_id)
  end
  
  -- Store the route
  table.insert(server.routes, {
    method = method,
    path = path,
    handler = handler,
  })
end

-- Handle incoming request
function M.handle_request(server_id, request)
  local server = M.servers[server_id]
  if not server then
    return
  end
  
  -- Find matching route
  local route = nil
  for _, r in ipairs(server.routes) do
    if r.method == request.method and r.path == request.path then
      route = r
      break
    end
  end
  
  if not route then
    -- Send 404
    M.send_response(server_id, {
      status = 404,
      headers = {["Content-Type"] = "text/plain"},
      body = "Not Found",
    })
    return
  end
  
  -- Execute handler
  local ok, response = pcall(route.handler, request)
  
  if not ok then
    -- Send 500
    M.send_response(server_id, {
      status = 500,
      headers = {["Content-Type"] = "text/plain"},
      body = "Internal Server Error: " .. tostring(response),
    })
    return
  end
  
  -- Send response
  M.send_response(server_id, response)
end

-- Send response back to Python server
function M.send_response(server_id, response)
  local server = M.servers[server_id]
  if not server then
    return
  end
  
  -- Default values
  response.status = response.status or 200
  response.headers = response.headers or {["Content-Type"] = "text/plain"}
  response.body = response.body or ""
  
  -- Send JSON response to Python server's stdin
  local json_response = vim.fn.json_encode(response) .. "\n"
  server.stdin:write(json_response)
end

-- Stop a server
function M.stop(server_id)
  local server = M.servers[server_id]
  if not server then
    return
  end
  
  -- Kill the process
  vim.loop.process_kill(server.handle, "sigterm")
  
  -- Cleanup
  M.servers[server_id] = nil
end

-- Stop all servers
function M.stop_all()
  for server_id, _ in pairs(M.servers) do
    M.stop(server_id)
  end
end

return M
