-- Decorate the current buffer with markers for functions and classes.
-- Corrected version with comprehensive error handling and performance improvements.

local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}

-- Configuration
local NAMESPACE_NAME = "bmark"
local DEFAULT_CONFIG = {
	markers = {
		func = { target = "function_definition", marker = string.rep("~", 100), hl_group = "Comment" },
		decofunc = { target = "decorated_definition", marker = string.rep("~", 100), hl_group = "Comment" },
		class = { target = "class_definition", marker = string.rep("#", 100), hl_group = "Comment" },
	},
	language = "python",
	file_patterns = { "*.py" },
	auto_refresh = true,
}

-- Cache for namespace ID to avoid repeated API calls
local cached_ns_id = nil

-- Get or create namespace ID (cached)
local function get_namespace_id()
	if not cached_ns_id then
		cached_ns_id = api.nvim_create_namespace(NAMESPACE_NAME)
	end
	return cached_ns_id
end

-- Validate buffer and language support
local function validate_buffer_and_language(bufnr, language)
	-- Check if buffer is valid
	if not api.nvim_buf_is_valid(bufnr) then
		return false, "Invalid buffer"
	end

	-- Check if buffer is loaded
	if not api.nvim_buf_is_loaded(bufnr) then
		return false, "Buffer not loaded"
	end

	-- Check if TreeSitter parser is available
	local ok, parser = pcall(ts.get_parser, bufnr, language)
	if not ok or not parser then
		return false, string.format("TreeSitter parser for '%s' not available", language)
	end

	return true, parser
end

-- Check if a line is empty or contains only whitespace
local function is_line_empty(bufnr, line_num)
	local ok, line_content = pcall(fn.getbufoneline, bufnr, line_num)
	if not ok then
		return false
	end
	return line_content:match("^%s*$") ~= nil
end

-- Create extmark with error handling
local function create_extmark(bufnr, ns_id, line_num, marker_text, hl_group)
	local opts = {
		end_line = line_num,
		id = line_num,
		virt_text = { { marker_text, hl_group } },
		virt_text_pos = "overlay",
	}

	local ok, mark_id = pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_num, 0, opts)
	if not ok then
		vim.notify(string.format("Failed to create extmark at line %d: %s", line_num + 1, mark_id), vim.log.levels.WARN)
		return nil
	end

	return mark_id
end

-- Main function to add block markers with comprehensive error handling
function M:add_block_markers(config)
	config = config or DEFAULT_CONFIG

	local bufnr = fn.bufnr("%")
	local ns_id = get_namespace_id()

	-- Validate buffer and language
	local valid, parser_or_error = validate_buffer_and_language(bufnr, config.language)
	if not valid then
		vim.notify(string.format("Block markers: %s", parser_or_error), vim.log.levels.WARN)
		return false
	end

	local parser = parser_or_error

	-- Parse syntax tree with error handling
	local ok, syntax_tree = pcall(function()
		return parser:parse()
	end)
	if not ok or not syntax_tree or #syntax_tree == 0 then
		vim.notify("Block markers: Failed to parse syntax tree", vim.log.levels.ERROR)
		return false
	end

	local root = syntax_tree[1]:root()
	if not root then
		vim.notify("Block markers: No root node found in syntax tree", vim.log.levels.ERROR)
		return false
	end

	local query_template = "(%s) @capture"
	local markers_added = 0
	local errors = 0

	-- Process each marker type
	for marker_name, params in pairs(config.markers) do
		local query_string = string.format(query_template, params.target)

		-- Parse query with error handling
		local query_ok, query = pcall(vim.treesitter.query.parse, config.language, query_string)
		if not query_ok then
			vim.notify(
				string.format("Block markers: Invalid query for %s: %s", marker_name, query),
				vim.log.levels.ERROR
			)
			errors = errors + 1
			goto continue
		end

		-- Iterate through captures with error handling
		local iter_ok, iter_result = pcall(function()
			local captures = {}
			for id, node in query:iter_captures(root, bufnr) do
				local start_row, _, _, _ = node:range()
				table.insert(captures, { id = id, node = node, start_row = start_row })
			end
			return captures
		end)

		if not iter_ok then
			vim.notify(
				string.format("Block markers: Error iterating captures for %s: %s", marker_name, iter_result),
				vim.log.levels.ERROR
			)
			errors = errors + 1
			goto continue
		end

		-- Process captures
		for _, capture in ipairs(iter_result) do
			local line_num = capture.start_row

			-- Validate line number
			if line_num < 0 then
				goto continue_capture
			end

			-- Check if the line above is empty (only add marker if it is)
			-- Fixed logic: we want to check the line BEFORE the definition
			if line_num == 0 or not is_line_empty(bufnr, line_num) then
				goto continue_capture
			end

			-- Create the extmark on the line BEFORE the definition
			local marker_line = line_num - 1
			local mark_id = create_extmark(bufnr, ns_id, marker_line, params.marker, params.hl_group)
			if mark_id then
				markers_added = markers_added + 1
			else
				errors = errors + 1
			end

			::continue_capture::
		end

		::continue::
	end

	-- Report results if there were issues
	if errors > 0 then
		vim.notify(
			string.format("Block markers: Added %d markers with %d errors", markers_added, errors),
			vim.log.levels.WARN
		)
	end

	return markers_added > 0
end

-- Clear markers with error handling
function M:clear_block_markers()
	local bufnr = fn.bufnr("%")
	local ns_id = get_namespace_id()

	if not api.nvim_buf_is_valid(bufnr) then
		vim.notify("Block markers: Cannot clear markers, invalid buffer", vim.log.levels.WARN)
		return false
	end

	local ok, result = pcall(api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
	if not ok then
		vim.notify(string.format("Block markers: Failed to clear markers: %s", result), vim.log.levels.ERROR)
		return false
	end

	return true
end

-- Refresh markers (clear and re-add)
function M:refresh_block_markers(config)
	if not self:clear_block_markers() then
		return false
	end
	return self:add_block_markers(config)
end

-- Enable markers with auto-refresh
function M:enable_block_markers(config)
	config = config or DEFAULT_CONFIG

	-- Initial marker setup
	if not self:refresh_block_markers(config) then
		vim.notify("Block markers: Failed to enable markers", vim.log.levels.ERROR)
		return false
	end

	-- Set up auto-refresh if enabled
	if config.auto_refresh then
		-- Clear any existing autocmds for this namespace
		local group_name = NAMESPACE_NAME .. "_auto_refresh"
		pcall(api.nvim_del_augroup_by_name, group_name)

		local group_id = api.nvim_create_augroup(group_name, { clear = true })

		local ok, autocmd_id = pcall(api.nvim_create_autocmd, { "InsertLeave", "TextChanged", "BufWritePost" }, {
			group = group_id,
			pattern = config.file_patterns,
			callback = function()
				-- Add small delay to avoid excessive refreshes
				vim.defer_fn(function()
					M:refresh_block_markers(config)
				end, 100)
			end,
			desc = "Refresh block markers",
		})

		if not ok then
			vim.notify(string.format("Block markers: Failed to create autocmd: %s", autocmd_id), vim.log.levels.WARN)
		end
	end

	return true
end

-- Disable markers and cleanup
function M:disable_block_markers()
	local bufnr = fn.bufnr("%")
	local ns_id = get_namespace_id()

	-- Check if there are any markers to disable
	local has_markers = false
	if api.nvim_buf_is_valid(bufnr) then
		local ok, extmarks = pcall(api.nvim_buf_get_extmarks, bufnr, ns_id, 0, -1, {})
		if ok and extmarks and #extmarks > 0 then
			has_markers = true
		end
	end

	if has_markers then
		local cleared = self:clear_block_markers()

		-- Clean up autocmds
		local group_name = NAMESPACE_NAME .. "_auto_refresh"
		pcall(api.nvim_del_augroup_by_name, group_name)

		return cleared
	end

	return false
end

-- Toggle markers on/off
function M:toggle_block_markers(config)
	local disabled = self:disable_block_markers()
	if not disabled then
		return self:enable_block_markers(config)
	end
	return true
end

-- Check if markers are currently enabled
function M:is_enabled()
	local bufnr = fn.bufnr("%")
	local ns_id = get_namespace_id()

	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local ok, extmarks = pcall(api.nvim_buf_get_extmarks, bufnr, ns_id, 0, -1, {})
	return ok and extmarks and #extmarks > 0
end

-- Get current status
function M:status()
	local bufnr = fn.bufnr("%")

	-- Use nvim_get_option_value instead of deprecated nvim_buf_get_option
	local ok, filetype = pcall(api.nvim_get_option_value, "filetype", { buf = bufnr })
	if not ok then
		filetype = "unknown"
	end

	local enabled = self:is_enabled()

	return {
		enabled = enabled,
		buffer = bufnr,
		filetype = filetype,
		namespace_id = cached_ns_id,
	}
end

return M
