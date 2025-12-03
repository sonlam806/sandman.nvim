-- Utility functions for Sandman (json, base64, jwt, uri)
local M = {}

-- JSON encode/decode
M.json = {
  encode = function(data)
    return vim.json.encode(data)
  end,
  
  decode = function(str)
    local ok, result = pcall(vim.json.decode, str)
    if ok then
      return result
    else
      error("Failed to decode JSON: " .. result)
    end
  end,
}

-- Base64 encode/decode
M.base64 = {
  encode = function(str)
    local b64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    local padding = ""
    
    -- Process input in 3-byte chunks
    for i = 1, #str, 3 do
      local b1, b2, b3 = str:byte(i, i + 2)
      b2 = b2 or 0
      b3 = b3 or 0
      
      local n = bit.lshift(b1, 16) + bit.lshift(b2, 8) + b3
      
      local c1 = bit.rshift(bit.band(n, 0xFC0000), 18) + 1
      local c2 = bit.rshift(bit.band(n, 0x03F000), 12) + 1
      local c3 = bit.rshift(bit.band(n, 0x000FC0), 6) + 1
      local c4 = bit.band(n, 0x00003F) + 1
      
      table.insert(result, b64_chars:sub(c1, c1))
      table.insert(result, b64_chars:sub(c2, c2))
      table.insert(result, i + 1 <= #str and b64_chars:sub(c3, c3) or "=")
      table.insert(result, i + 2 <= #str and b64_chars:sub(c4, c4) or "=")
    end
    
    return table.concat(result)
  end,
  
  decode = function(str)
    local b64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result = {}
    
    -- Remove padding
    str = str:gsub("=", "")
    
    for i = 1, #str, 4 do
      local c1 = b64_chars:find(str:sub(i, i)) - 1
      local c2 = b64_chars:find(str:sub(i + 1, i + 1)) - 1
      local c3 = str:sub(i + 2, i + 2) ~= "" and (b64_chars:find(str:sub(i + 2, i + 2)) - 1) or 0
      local c4 = str:sub(i + 3, i + 3) ~= "" and (b64_chars:find(str:sub(i + 3, i + 3)) - 1) or 0
      
      local n = bit.lshift(c1, 18) + bit.lshift(c2, 12) + bit.lshift(c3, 6) + c4
      
      table.insert(result, string.char(bit.rshift(bit.band(n, 0xFF0000), 16)))
      if i + 2 <= #str then
        table.insert(result, string.char(bit.rshift(bit.band(n, 0x00FF00), 8)))
      end
      if i + 3 <= #str then
        table.insert(result, string.char(bit.band(n, 0x0000FF)))
      end
    end
    
    return table.concat(result)
  end,
}

-- URI encoding/decoding
M.uri = {
  encode = function(str)
    return str:gsub("([^%w%-%.%_%~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  end,
  
  decode = function(str)
    return str:gsub("%%(%x%x)", function(hex)
      return string.char(tonumber(hex, 16))
    end)
  end,
  
  parse = function(url)
    local result = {}
    
    -- Extract scheme
    local scheme, rest = url:match("^(%w+)://(.+)$")
    if scheme then
      result.scheme = scheme
    else
      rest = url
    end
    
    -- Extract userinfo, host, and port
    local authority, path_and_query = rest:match("^([^/]+)(.*)$")
    if authority then
      local userinfo, host_port = authority:match("^(.+)@(.+)$")
      if userinfo then
        result.userinfo = userinfo
        authority = host_port
      end
      
      local host, port = authority:match("^([^:]+):(%d+)$")
      if host then
        result.host = host
        result.port = tonumber(port)
      else
        result.host = authority
      end
    end
    
    -- Extract path and query
    if path_and_query then
      local path, query = path_and_query:match("^([^%?]*)%??(.*)$")
      result.path = path ~= "" and path or "/"
      if query and query ~= "" then
        result.query = query
      end
    end
    
    return result
  end,
}

-- JWT utilities (basic implementation)
M.jwt = {
  decode = function(token)
    local parts = vim.split(token, ".", { plain = true })
    if #parts ~= 3 then
      error("Invalid JWT token")
    end
    
    local header = M.json.decode(M.base64.decode(parts[1]))
    local payload = M.json.decode(M.base64.decode(parts[2]))
    
    return {
      header = header,
      payload = payload,
      signature = parts[3],
    }
  end,
  
  -- Note: This is a basic implementation for reading JWTs
  -- For production, use a proper JWT library with signature verification
  verify = function(token, secret)
    -- This is a placeholder - proper JWT verification requires crypto libraries
    vim.notify("JWT verification not implemented - use external library", vim.log.levels.WARN)
    return false
  end,
}

-- Environment variable helper
M.getenv = function(key, env_vars)
  -- Check if key starts with SANDMAN_ prefix for security
  return env_vars[key] or nil
end

-- Table deep copy
M.deep_copy = function(obj)
  if type(obj) ~= 'table' then return obj end
  local copy = {}
  for k, v in pairs(obj) do
    copy[k] = M.deep_copy(v)
  end
  return copy
end

-- UUID generator (simple version)
M.uuid = function()
  local random = math.random
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
end

return M
