-- Markdown parser for extracting code blocks
local M = {}

-- Parse markdown content and extract code blocks
function M.parse(content)
  local blocks = {}
  local lines = vim.split(content, "\n", { plain = true })
  local current_block = nil
  local block_id = 1
  
  for i, line in ipairs(lines) do
    -- Check for code block start
    local lang = line:match("^```(%w*)$")
    if lang then
      if current_block then
        -- End of code block
        current_block.end_line = i - 1
        table.insert(blocks, current_block)
        current_block = nil
      else
        -- Start of code block
        current_block = {
          id = block_id,
          type = lang == "" and "lua" or lang,
          start_line = i,
          code = {},
          state = "empty",
        }
        block_id = block_id + 1
      end
    elseif current_block then
      -- Inside code block
      table.insert(current_block.code, line)
    else
      -- Markdown content outside code blocks
      -- Check if this line starts a markdown block
      if #blocks == 0 or blocks[#blocks].type ~= "markdown" or blocks[#blocks].end_line then
        table.insert(blocks, {
          id = block_id,
          type = "markdown",
          start_line = i,
          code = {line},
          state = "empty",
        })
        block_id = block_id + 1
      else
        -- Continue current markdown block
        table.insert(blocks[#blocks].code, line)
      end
    end
  end
  
  -- Close any open blocks
  if current_block then
    current_block.end_line = #lines
    table.insert(blocks, current_block)
  end
  
  -- Set end_line for markdown blocks and join code lines
  for _, block in ipairs(blocks) do
    if not block.end_line then
      block.end_line = block.start_line + #block.code - 1
    end
    block.code = table.concat(block.code, "\n")
  end
  
  return blocks
end

-- Find the block at a given line number
function M.find_block_at_line(blocks, line_nr)
  for _, block in ipairs(blocks) do
    if line_nr >= block.start_line and line_nr <= block.end_line then
      return block
    end
  end
  return nil
end

-- Get all lua blocks before a given block
function M.get_preceding_lua_blocks(blocks, block_id)
  local preceding = {}
  for _, block in ipairs(blocks) do
    if block.id == block_id then
      break
    end
    if block.type == "lua" then
      table.insert(preceding, block)
    end
  end
  return preceding
end

-- Encode blocks back to markdown
function M.encode(blocks)
  local lines = {}
  
  for i, block in ipairs(blocks) do
    if block.type == "markdown" then
      -- Add markdown content directly
      for line in block.code:gmatch("[^\n]+") do
        table.insert(lines, line)
      end
    else
      -- Add code block with fence
      table.insert(lines, "```" .. block.type)
      for line in block.code:gmatch("[^\n]+") do
        table.insert(lines, line)
      end
      table.insert(lines, "```")
    end
    
    -- Add spacing between blocks (except after last block)
    if i < #blocks then
      table.insert(lines, "")
    end
  end
  
  return table.concat(lines, "\n")
end

return M
