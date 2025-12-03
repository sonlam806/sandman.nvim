local M = {}
local curl = require("plenary.curl")

function M.request(method, url, headers, body, callback)
  local opts = {
    url = url,
    method = method,
    headers = headers or {},
    body = vim.json.encode(body),
    callback = vim.schedule_wrap(function(response)
      if response.status == 0 then
        callback({
          error = true,
          message = response.body or "HTTP request failed",
          status = 0,
        })
      else
        callback({
          status = response.status,
          headers = response.headers or {},
          body = response.body,
        })
      end
    end),
  }
  curl[method:lower()](opts)
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
