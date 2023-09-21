lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_port = '8085'
      vim.g.mkdp_theme = 'dark'
      vim.g.mkdp_page_title = '${name} - Markdown Preview'
    end,
    ft = { "markdown" },
  },
  "roobert/tailwindcss-colorizer-cmp.nvim",
  "NvChad/nvim-colorizer.lua",
  "mzlogin/vim-markdown-toc",
  "ThePrimeagen/vim-be-good",
  "Shatur/neovim-ayu"
}
