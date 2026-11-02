local M = {}
local notified_clients = {}

-- Install common navigation, completion, and connection feedback on attach.
local function setup_keymaps()
  local group = vim.api.nvim_create_augroup("NativeLspKeymaps", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local client_id = event.data.client_id
      local client = vim.lsp.get_client_by_id(client_id)
      local bufnr = event.buf
      local opts = { buffer = bufnr, silent = true }

      if client and not notified_clients[client_id] then
        notified_clients[client_id] = true
        vim.notify(
          ("%s connected"):format(client.name),
          vim.log.levels.INFO,
          { title = "Language server" }
        )
      end

      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
      vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)

      vim.lsp.completion.enable(true, client_id, bufnr, { autotrigger = true })
    end,
  })
end

-- Load each configured client module through the shared setup contract.
local function setup_clients(options)
  options = options or {}
  local server_options = options.servers or {}
  local enabled, missing, setup_scripts = {}, {}, {}

  for _, client_name in ipairs(options.clients or {}) do
    local client_module = require("lsp.clients." .. client_name)
    local client = client_module.setup(server_options[client_name] or {})
    if vim.fn.executable(client.command[1]) == 1 then
      enabled[#enabled + 1] = client.name
    else
      missing[#missing + 1] = client.name
      if client.setup_script then
        setup_scripts[#setup_scripts + 1] = client.setup_script
      end
    end
  end

  if #enabled > 0 then
    vim.lsp.enable(enabled)
  end
  if #missing > 0 then
    local install_hint = #setup_scripts > 0
        and (" Run %s."):format(table.concat(setup_scripts, " and "))
      or ""
    vim.notify(
      ("LSP clients unavailable: %s.%s"):format(table.concat(missing, ", "), install_hint),
      vim.log.levels.WARN,
      { title = "Language servers" }
    )
  end
end

-- Report clients attached to the current buffer.
local function show_status()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local lines = {}
  for _, client in ipairs(clients) do
    local root = client.config.root_dir
    lines[#lines + 1] = root and (client.name .. " connected\n" .. root)
      or (client.name .. " connected")
  end

  if #lines == 0 then
    lines[1] = "No LSP client is attached to this buffer."
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP status" })
end

local function client_details(client)
  local details = {
    "Client: " .. client.name,
    "ID: " .. client.id,
    "Root: " .. (client.config.root_dir or "(none)"),
    "Command: " .. table.concat(client.config.cmd or {}, " "),
    "",
    "Filetypes:",
  }

  local filetypes = client.config.filetypes or {}
  if #filetypes == 0 then
    details[#details + 1] = "  (unspecified)"
  else
    for _, filetype in ipairs(filetypes) do
      details[#details + 1] = "  - " .. filetype
    end
  end

  details[#details + 1] = ""
  details[#details + 1] = "Attached buffers:"

  local attached = {}
  for bufnr in pairs(client.attached_buffers or {}) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      attached[#attached + 1] = bufnr
    end
  end
  table.sort(attached)
  if #attached == 0 then
    details[#details + 1] = "  (none)"
  else
    for _, bufnr in ipairs(attached) do
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == "" then
        name = "[No Name]"
      end
      details[#details + 1] = ("  %s  [%s]"):format(name, vim.bo[bufnr].filetype)
    end
  end

  details[#details + 1] = ""
  details[#details + 1] = "Capabilities:"
  local capabilities = {}
  for capability, supported in pairs(client.server_capabilities or {}) do
    if supported and capability:match("Provider$") then
      capabilities[#capabilities + 1] = capability:gsub("Provider$", "")
    end
  end
  table.sort(capabilities)
  if #capabilities == 0 then
    details[#details + 1] = "  (none reported)"
  else
    for _, capability in ipairs(capabilities) do
      details[#details + 1] = "  - " .. capability
    end
  end
  return details
end

-- Show all running clients in a searchable Telescope picker with a detail preview.
local function show_clients()
  local clients = vim.lsp.get_clients()
  if #clients == 0 then
    vim.notify("No LSP clients are running.", vim.log.levels.INFO, { title = "LSP clients" })
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local config = require("telescope.config").values
  local previewers = require("telescope.previewers")

  table.sort(clients, function(left, right)
    return left.name:lower() < right.name:lower()
  end)

  pickers.new({}, {
    prompt_title = "Running LSP Clients",
    finder = finders.new_table({
      results = clients,
      entry_maker = function(client)
        local filetypes = client.config.filetypes or {}
        local attached_count = vim.tbl_count(client.attached_buffers or {})
        local display = ("%s  (%d buffers, %d filetypes)"):format(
          client.name,
          attached_count,
          #filetypes
        )
        return {
          value = client,
          display = display,
          ordinal = client.name .. " " .. table.concat(filetypes, " "),
        }
      end,
    }),
    sorter = config.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Client Details",
      define_preview = function(self, entry)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, client_details(entry.value))
      end,
    }),
  }):find()
end

function M.setup(options)
  setup_keymaps()
  setup_clients(options)
  vim.api.nvim_create_user_command("LspStatus", show_status, {
    desc = "Show language servers attached to the current buffer",
    force = true,
  })
  vim.api.nvim_create_user_command("LspClients", show_clients, {
    desc = "Search running LSP clients and inspect their buffers",
    force = true,
  })
  vim.diagnostic.config({
    underline = true,
    virtual_text = true,
    signs = true,
    severity_sort = true,
  })
end

return M