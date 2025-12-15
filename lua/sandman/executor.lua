-- Lua code executor with state management
local M = {}
local http = require("sandman.http")
local utils = require("sandman.utils")
local server = require("sandman.server")

-- Store for document states (one per file)
M.states = {}

-- Create a new sandman API table for use in executed code
local function create_sandman_api(state, block_id)
	local api = {
		http = {
			get = function(url, headers)
				local response = nil
				local error_msg = nil
				local done = false

				http.get(url, headers, function(res)
					if res.error then
						error_msg = res.message
						-- Log the error request
						table.insert(state.logs, {
							message = string.format("[GET] %s - error: %s", url, tostring(res.message)),
							timestamp = os.time(),
							block_id = block_id,
						})
					else
						response = res
						-- Record the request
						table.insert(state.requests[block_id], {
							method = "GET",
							url = url,
							headers = headers or {},
							body = nil,
							response = res,
							timestamp = os.time(),
						})
						-- Log the request automatically
						table.insert(state.logs, {
							message = string.format(
								"[GET] %s - status: %s",
								url,
								tostring(res and res.status or "unknown")
							),
							timestamp = os.time(),
							block_id = block_id,
						})
					end
					done = true
				end)

				-- Wait for completion
				local timeout = 100 -- 10 seconds
				while not done and timeout > 0 do
					vim.wait(100)
					timeout = timeout - 1
				end

				if error_msg then
					error(error_msg)
				end

				return response
			end,

			post = function(url, headers, body)
				local response = nil
				local error_msg = nil
				local done = false

				http.post(url, headers, body, function(res)
					if res.error then
						error_msg = res.message
						-- Log the error request
						table.insert(state.logs, {
							message = string.format("[POST] %s - error: %s", url, tostring(res.message)),
							timestamp = os.time(),
							block_id = block_id,
						})
					else
						response = res
						table.insert(state.requests[block_id], {
							method = "POST",
							url = url,
							headers = headers or {},
							body = body,
							response = res,
							timestamp = os.time(),
						})
						-- Log the request automatically
						table.insert(state.logs, {
							message = string.format(
								"[POST] %s - status: %s",
								url,
								tostring(res and res.status or "unknown")
							),
							timestamp = os.time(),
							block_id = block_id,
						})
					end
					done = true
				end)

				-- Wait for completion
				local timeout = 100
				while not done and timeout > 0 do
					vim.wait(100)
					timeout = timeout - 1
				end

				if error_msg then
					error(error_msg)
				end

				return response
			end,

			put = function(url, headers, body)
				local response = nil
				local error_msg = nil
				local done = false

				http.put(url, headers, body, function(res)
					if res.error then
						error_msg = res.message
						-- Log the error request
						table.insert(state.logs, {
							message = string.format("[PUT] %s - error: %s", url, tostring(res.message)),
							timestamp = os.time(),
							block_id = block_id,
						})
					else
						response = res
						table.insert(state.requests[block_id], {
							method = "PUT",
							url = url,
							headers = headers or {},
							body = body,
							response = res,
							timestamp = os.time(),
						})
						-- Log the request automatically
						table.insert(state.logs, {
							message = string.format(
								"[PUT] %s - status: %s",
								url,
								tostring(res and res.status or "unknown")
							),
							timestamp = os.time(),
							block_id = block_id,
						})
					end
					done = true
				end)

				-- Wait for completion
				local timeout = 100
				while not done and timeout > 0 do
					vim.wait(100)
					timeout = timeout - 1
				end

				if error_msg then
					error(error_msg)
				end

				return response
			end,

			delete = function(url, headers)
				local response = nil
				local error_msg = nil
				local done = false

				http.delete(url, headers, function(res)
					if res.error then
						error_msg = res.message
						-- Log the error request
						table.insert(state.logs, {
							message = string.format("[DELETE] %s - error: %s", url, tostring(res.message)),
							timestamp = os.time(),
							block_id = block_id,
						})
					else
						response = res
						table.insert(state.requests[block_id], {
							method = "DELETE",
							url = url,
							headers = headers or {},
							body = nil,
							response = res,
							timestamp = os.time(),
						})
						-- Log the request automatically
						table.insert(state.logs, {
							message = string.format(
								"[DELETE] %s - status: %s",
								url,
								tostring(res and res.status or "unknown")
							),
							timestamp = os.time(),
							block_id = block_id,
						})
					end
					done = true
				end)

				-- Wait for completion
				local timeout = 100
				while not done and timeout > 0 do
					vim.wait(100)
					timeout = timeout - 1
				end

				if error_msg then
					error(error_msg)
				end

				return response
			end,

			patch = function(url, headers, body)
				local response = nil
				local error_msg = nil
				local done = false

				http.patch(url, headers, body, function(res)
					if res.error then
						error_msg = res.message
						-- Log the error request
						table.insert(state.logs, {
							message = string.format("[PATCH] %s - error: %s", url, tostring(res.message)),
							timestamp = os.time(),
							block_id = block_id,
						})
					else
						response = res
						table.insert(state.requests[block_id], {
							method = "PATCH",
							url = url,
							headers = headers or {},
							body = body,
							response = res,
							timestamp = os.time(),
						})
						-- Log the request automatically
						table.insert(state.logs, {
							message = string.format(
								"[PATCH] %s - status: %s",
								url,
								tostring(res and res.status or "unknown")
							),
							timestamp = os.time(),
							block_id = block_id,
						})
					end
					done = true
				end)

				-- Wait for completion
				local timeout = 100
				while not done and timeout > 0 do
					vim.wait(100)
					timeout = timeout - 1
				end

				if error_msg then
					error(error_msg)
				end

				return response
			end,
		},

		server = {
			start = function(port)
				local server_id = server.start(port, state.file_path)
				state.servers[server_id] = {
					id = server_id,
					port = port,
					routes = {},
					block_id = block_id,
				}
				return server_id
			end,

			get = function(server_id, path, handler)
				server.add_route(server_id, "GET", path, handler)
				table.insert(state.servers[server_id].routes, {
					method = "GET",
					path = path,
					block_id = block_id,
				})
			end,

			post = function(server_id, path, handler)
				server.add_route(server_id, "POST", path, handler)
				table.insert(state.servers[server_id].routes, {
					method = "POST",
					path = path,
					block_id = block_id,
				})
			end,

			put = function(server_id, path, handler)
				server.add_route(server_id, "PUT", path, handler)
				table.insert(state.servers[server_id].routes, {
					method = "PUT",
					path = path,
					block_id = block_id,
				})
			end,

			delete = function(server_id, path, handler)
				server.add_route(server_id, "DELETE", path, handler)
				table.insert(state.servers[server_id].routes, {
					method = "DELETE",
					path = path,
					block_id = block_id,
				})
			end,

			stop = function(server_id)
				server.stop(server_id)
				state.servers[server_id] = nil
			end,
		},

		json = utils.json,
		base64 = utils.base64,
		uri = utils.uri,
		jwt = utils.jwt,
		getenv = function(key)
			local env = utils.getenv(key, state.env)
			return env
		end,

		document = {
			set = function(key, value)
				state.document_vars[key] = value
			end,

			get = function(key)
				return state.document_vars[key]
			end,
		},

		log = function(...)
			local args = { ... }
			local msg = table.concat(vim.tbl_map(tostring, args), " ")
			table.insert(state.logs, {
				message = msg,
				timestamp = os.time(),
				block_id = block_id,
			})
		end,
	}

	return api
end

-- Get or create state for a file
function M.get_state(file_path)
	if not M.states[file_path] then
		-- Create a new environment with standard library access
		local env = {
			-- Basic Lua functions
			assert = assert,
			error = error,
			ipairs = ipairs,
			next = next,
			pairs = pairs,
			pcall = pcall,
			print = print,
			select = select,
			tonumber = tonumber,
			tostring = tostring,
			type = type,
			unpack = unpack or table.unpack,
			xpcall = xpcall,
			rawget = rawget,
			rawset = rawset,
			getmetatable = getmetatable,
			setmetatable = setmetatable,

			-- Standard libraries
			coroutine = coroutine,
			string = string,
			table = table,
			math = math,
			io = io,
			os = os,
			debug = debug,

			-- Neovim specific
			vim = vim,

			-- Make _G reference itself
			_VERSION = _VERSION,
		}
		env._G = env

		M.states[file_path] = {
			file_path = file_path,
			env = env, -- Shared Lua environment across blocks
			requests = {}, -- Request history by block_id
			servers = {}, -- Server instances
			document_vars = {}, -- Document-level variables
			logs = {}, -- Log messages
			block_states = {}, -- Block execution states
			block_outputs = {}, -- Block outputs
		}
	end
	return M.states[file_path]
end

-- Set environment variables for a file
function M.set_env(file_path, env_vars)
	local state = M.get_state(file_path)
	for key, value in pairs(env_vars or {}) do
		state.env[key] = value
	end
end

-- Clear state for a file
function M.clear_state(file_path)
	local state = M.states[file_path]
	if state then
		-- Stop all servers
		for server_id, _ in pairs(state.servers) do
			server.stop(server_id)
		end
	end
	M.states[file_path] = nil
end

-- Reset state for blocks after a given block
function M.reset_following_blocks(file_path, block_id, all_blocks)
	local state = M.get_state(file_path)
	local found = false

	for _, block in ipairs(all_blocks) do
		if found and block.type == "lua" then
			-- Clear this block's state
			state.requests[block.id] = {}
			state.block_states[block.id] = "empty"

			-- Remove servers created in this block
			for server_id, srv in pairs(state.servers) do
				if srv.block_id == block.id then
					server.stop(server_id)
					state.servers[server_id] = nil
				end
			end
		end

		if block.id == block_id then
			found = true
		end
	end
end

-- Execute a block
function M.execute_block(file_path, block, preceding_blocks)
	local state = M.get_state(file_path)

	-- Initialize request storage for this block
	state.requests[block.id] = {}
	state.block_states[block.id] = "running"

	-- Build the execution environment
	-- Start with a clean environment but preserve state from preceding blocks
	local env = state.env

	-- Add sandman API
	local sandman_api = create_sandman_api(state, block.id)
	env.sandman = sandman_api

	-- Create a function from the code
	local chunk, err = load(block.code, "block_" .. block.id, "t", env)

	if not chunk then
		state.block_states[block.id] = "errored"
		state.block_outputs = state.block_outputs or {}
		state.block_outputs[block.id] = "Syntax error: " .. err
		return false, "Syntax error: " .. err
	end

	-- Execute the chunk
	local success, result = pcall(chunk)

	if not success then
		state.block_states[block.id] = "errored"
		state.block_outputs = state.block_outputs or {}
		state.block_outputs[block.id] = "Runtime error: " .. result
		return false, "Runtime error: " .. result
	end

	state.block_states[block.id] = "executed"

	-- Store output if there's a result
	state.block_outputs = state.block_outputs or {}
	if result ~= nil then
		state.block_outputs[block.id] = tostring(result)
	end

	return true, result
end

-- Execute all blocks
function M.execute_all(file_path, blocks)
	local lua_blocks = vim.tbl_filter(function(b)
		return b.type == "lua"
	end, blocks)

	for i, block in ipairs(lua_blocks) do
		local preceding = vim.list_slice(lua_blocks, 1, i - 1)
		local success, err = M.execute_block(file_path, block, preceding)

		if not success then
			return false, err, block.id
		end
	end

	return true
end

return M
