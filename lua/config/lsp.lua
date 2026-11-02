local M = {}
local notified_clients = {}

local function elixir_root(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local projects = vim.fs.find({ "mix.exs" }, {
    upward = true,
    limit = 2,
    path = filename,
  })
  local project = projects[2] or projects[1]
  if project then
    on_dir(vim.fs.dirname(project))
    return
  end

  local git_root = vim.fs.find({ ".git" }, {
    upward = true,
    path = filename,
  })[1]
  if git_root then
    on_dir(vim.fs.dirname(git_root))
  end
end

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

local function setup_servers(options)
  options = options or {}
  local filetypes = options.filetypes or {}
  local server_dir = vim.fn.stdpath("data") .. "/servers"
  local elixir_ls = server_dir .. "/elixir-ls/language_server.sh"
  local elp = server_dir .. "/elp/elp"
  local enabled = {}
  local missing = {}
  local setup_scripts = {}

  vim.lsp.config("elixirls", {
    cmd = { elixir_ls },
    filetypes = filetypes.elixirls or { "elixir", "eelixir", "heex", "surface" },
    root_dir = elixir_root,
  })
  vim.lsp.config("elp", {
    cmd = { elp, "server" },
    filetypes = filetypes.elp or { "erlang" },
    root_markers = { { "rebar.config", "erlang.mk" }, ".git" },
  })

  for name, executable in pairs({ elixirls = elixir_ls, elp = elp }) do
    if vim.fn.executable(executable) == 1 then
      enabled[#enabled + 1] = name
    else
      missing[#missing + 1] = name
      setup_scripts[#setup_scripts + 1] = name == "elixirls"
          and "scripts/setup_elixir_ls.sh"
        or "scripts/setup_elp.sh"
    end
  end

  if #enabled > 0 then
    vim.lsp.enable(enabled)
  end
  if #missing > 0 then
    vim.notify(
      ("LSP servers not installed: %s. Run %s.")
        :format(table.concat(missing, ", "), table.concat(setup_scripts, " and ")),
      vim.log.levels.WARN,
      { title = "Language servers" }
    )
  end
end

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

function M.setup(options)
  setup_keymaps()
  setup_servers(options)
  vim.api.nvim_create_user_command("LspStatus", show_status, {
    desc = "Show language servers attached to the current buffer",
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