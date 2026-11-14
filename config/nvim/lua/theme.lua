vim.pack.add({
    {
        src = "https://github.com/catppuccin/nvim",
        name = "catppuccin",
    },
})

require("catppuccin").setup({
    flavour = "mocha",

    transparent_background = false,

    styles = {
        comments = { "italic" },
        conditionals = { "italic" },
    },

    integrations = {
        mini = {
            enabled = true,
        },
    },
})

vim.cmd.colorscheme("catppuccin")
