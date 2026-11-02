local languages = {
  "elixir",
  "erlang",
  "python",
  "lua",
  "rust",
  "html",
  "javascript",
  "typescript"
}
-- Suppress repeated missing-parser warnings once per language per session.
local warned_languages = {}
local installation_finished = false

local function warn_unavailable(language)
  if warned_languages[language] then
    return
  end

  warned_languages[language] = true
  vim.notify(
    ("Tree-sitter setup failed for %s; see :TSLog."):format(language),
    vim.log.levels.WARN
  )
end

local function start_buffer(bufnr)
  local language = vim.bo[bufnr].filetype
  local ok = pcall(vim.treesitter.start, bufnr)
  if not ok and installation_finished then
    warn_unavailable(language)
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      local installed_before = treesitter.get_installed("parsers")
      local newly_installed = {}
      for _, language in ipairs(languages) do
        if not vim.list_contains(installed_before, language) then
          newly_installed[#newly_installed + 1] = language
        end
      end

      treesitter.install(languages):await(function(err, success)
        vim.schedule(function()
          installation_finished = true
          if err or not success then
            for _, language in ipairs(languages) do
              warn_unavailable(language)
            end
            return
          end

          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(bufnr)
                and vim.list_contains(languages, vim.bo[bufnr].filetype) then
              start_buffer(bufnr)
            end
          end

          if #newly_installed > 0 then
            vim.notify(
              ("Tree-sitter parser installed for: %s"):format(table.concat(newly_installed, ", ")),
              vim.log.levels.INFO
            )
          end
        end)
      end)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = languages,
        callback = function(event)
          start_buffer(event.buf)
        end,
      })
    end,
  },
}