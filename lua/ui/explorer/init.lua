local M = {}
local Tree = require("ui.explorer.tree")
local Git = require("ui.explorer.git")
local ExplorerActions = require("ui.explorer.actions")

local config = {
	width = 30,
	min_width = 12,
	resize_delay = 1000,
}

-- Keep tree, filesystem, and window state together for the explorer lifecycle.
local state = {
	expanded = {},
	nodes = {},
	root = nil,
	buffer = nil,
	window = nil,
	editor_window = nil,
	git_status = {},
	git_status_request = 0,
}

local namespace = vim.api.nvim_create_namespace("HandRolledExplorer")
local resize_check_timer
local render

render = function(preferred_path)
	Tree.render(state, namespace, preferred_path)
end

local function refresh_git_status()
	Git.refresh(state, render)
end

local actions = ExplorerActions.new(state, Tree, render, refresh_git_status)

local function cancel_resize_check()
	if resize_check_timer then
		resize_check_timer:stop()
		resize_check_timer:close()
		resize_check_timer = nil
	end
end

local function normalize(path)
	return vim.fs.normalize(path)
end

local function is_directory(path)
	return vim.fn.isdirectory(path) == 1
end

local function node_at_cursor()
	return Tree.node_at_cursor(state)
end

local function open_node(node, preview)
	node = node or node_at_cursor()
	if not node then
		return
	end

	if node.directory then
		state.expanded[node.path] = not state.expanded[node.path]
		render()
		return
	end

	local path = node.path
	local tabpage = vim.api.nvim_win_get_tabpage(state.window)
	local editor_window = state.editor_window
	if not editor_window or not vim.api.nvim_win_is_valid(editor_window)
			or editor_window == state.window
			or vim.api.nvim_win_get_tabpage(editor_window) ~= tabpage then
		editor_window = nil
		for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
			if winid ~= state.window
					and vim.bo[vim.api.nvim_win_get_buf(winid)].filetype ~= "native-explorer" then
				editor_window = winid
				break
			end
		end
	end

	if not editor_window then
		return
	end

	state.editor_window = editor_window
	local bufnr = vim.fn.bufadd(path)
	require("ui.tabs").open_in_window(editor_window, bufnr, preview)
	require("ui.tabs").update_window_ui(editor_window)
end

local function click_node()
	if not state.window or not vim.api.nvim_win_is_valid(state.window) then
		return
	end

	local mouse = vim.fn.getmousepos()
	local row = mouse.line
	if row < 1 or (mouse.winid ~= 0 and mouse.winid ~= state.window) or not state.nodes[row] then
		return
	end

	local node = state.nodes[row]
	vim.schedule(function()
		if not state.window or not vim.api.nvim_win_is_valid(state.window) then
			return
		end
		vim.api.nvim_win_set_cursor(state.window, { row, 0 })
		open_node(node, true)
	end)
end

local function schedule_resize_check()
	cancel_resize_check()
	local window = state.window
	if not window or not vim.api.nvim_win_is_valid(window) then
		return
	end

	resize_check_timer = vim.defer_fn(function()
		resize_check_timer = nil
		if state.window ~= window or not vim.api.nvim_win_is_valid(window)
				or vim.api.nvim_win_get_width(window) > config.min_width then
			return
		end

		vim.schedule(function()
			if state.window == window and vim.api.nvim_win_is_valid(window)
					and vim.api.nvim_win_get_width(window) <= config.min_width then
				M.close()
			end
		end)
	end, config.resize_delay)
end

local function create_buffer()
	if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
		return
	end

	state.buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buffer].buftype = "nofile"
	vim.bo[state.buffer].bufhidden = "hide"
	vim.bo[state.buffer].swapfile = false
	vim.bo[state.buffer].filetype = "native-explorer"

	local function map(lhs, callback, description)
		vim.keymap.set("n", lhs, callback, {
			buffer = state.buffer,
			silent = true,
			desc = description,
		})
	end

	local function open_preview()
		open_node(nil, true)
	end
	map("<CR>", open_preview, "Preview file or toggle directory")
	map("o", open_preview, "Preview file or toggle directory")
	map("a", actions.create_file, "Create file")
	map("A", actions.create_directory, "Create directory")
	map("r", actions.rename, "Rename file or directory")
	map("m", actions.move, "Move file or directory")
	map("d", actions.delete, "Delete file or directory")
	map("R", refresh_git_status, "Refresh explorer")
	map("q", M.close, "Close explorer")
	map("<LeftRelease>", click_node, "Open or toggle clicked entry")
	local function prevent_split()
		vim.notify("The explorer cannot be split.", vim.log.levels.INFO)
	end
	map("<C-w>s", prevent_split, "Prevent splitting the explorer")
	map("<C-w>v", prevent_split, "Prevent splitting the explorer")
	map("<C-w><C-s>", prevent_split, "Prevent splitting the explorer")
	map("<C-w><C-v>", prevent_split, "Prevent splitting the explorer")
end

function M.open()
	if state.window and vim.api.nvim_win_is_valid(state.window) then
		vim.api.nvim_set_current_win(state.window)
		return
	end

	state.root = normalize(vim.fn.getcwd())
	state.expanded = { [state.root] = true }
	create_buffer()

	local previous_window = vim.api.nvim_get_current_win()
	vim.cmd("topleft vertical split")
	state.window = vim.api.nvim_get_current_win()
	state.editor_window = previous_window
	vim.api.nvim_win_set_buf(state.window, state.buffer)
	vim.api.nvim_win_set_width(state.window, config.width)
	vim.wo[state.window].number = false
	vim.wo[state.window].relativenumber = false
	vim.wo[state.window].signcolumn = "no"
	vim.wo[state.window].foldcolumn = "0"
	vim.wo[state.window].wrap = false
	vim.wo[state.window].list = false
	vim.wo[state.window].cursorline = true

	render()
	refresh_git_status()
	vim.api.nvim_set_current_win(state.window)
end

function M.close()
	cancel_resize_check()
	local window = state.window
	local editor_window = state.editor_window
	state.window = nil

	if window and vim.api.nvim_win_is_valid(window) then
		if editor_window and vim.api.nvim_win_is_valid(editor_window)
				and vim.api.nvim_win_get_tabpage(editor_window) == vim.api.nvim_win_get_tabpage(window)
				and vim.api.nvim_get_current_win() == window then
			vim.api.nvim_set_current_win(editor_window)
		end
		vim.api.nvim_win_close(window, true)
	end
	state.editor_window = nil
end

function M.toggle()
	if state.window and vim.api.nvim_win_is_valid(state.window) then
		M.close()
	else
		M.open()
	end
end

function M.setup(options)
	options = options or {}
	config = vim.tbl_deep_extend("force", config, options)
	assert(
		type(config.min_width) == "number" and config.min_width >= 1
			and config.min_width % 1 == 0,
		"explorer min_width must be a positive integer"
	)
	assert(
		type(config.resize_delay) == "number" and config.resize_delay >= 1
			and config.resize_delay % 1 == 0,
		"explorer resize_delay must be a positive integer"
	)

	local group = vim.api.nvim_create_augroup("HandRolledExplorer", { clear = true })
	vim.api.nvim_create_autocmd("WinNew", {
		group = group,
		callback = function()
			local new_window = vim.api.nvim_get_current_win()
			vim.schedule(function()
				local explorer_window = state.window
				if not explorer_window or explorer_window == new_window
						or not vim.api.nvim_win_is_valid(explorer_window)
						or not vim.api.nvim_win_is_valid(new_window)
						or vim.api.nvim_win_get_config(new_window).relative ~= ""
						or vim.bo[vim.api.nvim_win_get_buf(new_window)].filetype ~= "native-explorer" then
					return
				end

				if vim.api.nvim_get_current_win() == new_window then
					vim.api.nvim_set_current_win(explorer_window)
				end
				vim.api.nvim_win_close(new_window, true)
				vim.notify("The explorer cannot be split.", vim.log.levels.INFO)
			end)
		end,
	})
	vim.api.nvim_create_autocmd("WinEnter", {
		group = group,
		callback = function()
			local winid = vim.api.nvim_get_current_win()
			local bufnr = vim.api.nvim_win_get_buf(winid)
			if vim.api.nvim_win_get_config(winid).relative == ""
					and vim.bo[bufnr].filetype ~= "native-explorer" then
				state.editor_window = winid
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		once = true,
		callback = function()
			for index = 0, vim.fn.argc() - 1 do
				local argument = vim.fn.argv(index)
				local path = vim.fn.fnamemodify(argument, ":p")
				if is_directory(path) then
					vim.cmd.cd(vim.fn.fnameescape(path))
					local directory_buffer = vim.api.nvim_get_current_buf()
					if is_directory(vim.api.nvim_buf_get_name(directory_buffer)) then
						vim.cmd.enew()
						if vim.api.nvim_buf_is_valid(directory_buffer) then
							vim.api.nvim_buf_delete(directory_buffer, { force = false })
						end
					end
					M.open()
					return
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd("WinResized", {
		group = group,
		callback = schedule_resize_check,
	})
	vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained" }, {
		group = group,
		callback = function()
			if state.window and vim.api.nvim_win_is_valid(state.window) then
				refresh_git_status()
			end
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "GitSignsUpdate",
		callback = refresh_git_status,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(event)
			local closed_window = tonumber(event.match)
			if state.window == closed_window then
				state.window = nil
			end
			if state.editor_window == closed_window then
				state.editor_window = nil
			end
		end,
	})
end

return M