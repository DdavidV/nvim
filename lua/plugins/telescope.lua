return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>ff",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Find buffers",
      },
      {
        "<leader>fh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "Find help tags",
      },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          get_selection_window = function()
            return require("ui.tabs").get_editor_window() or 0
          end,
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              preview_cutoff = 1,
              preview_width = 0.55,
            },
          },
        },
      })
    end,
  },
}
