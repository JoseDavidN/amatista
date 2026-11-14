vim.pack.add({
    {
        src = "https://github.com/nvim-lualine/lualine.nvim",
        name = "lualine",
    },
})

require("lualine").setup({
    options = {
        theme = "catppuccin-nvim",
        globalstatus = true,
        component_separators = {
            left = "│",
            right = "│",
        },
        section_separators = {
            left = "",
            right = "",
        },
        disabled_filetypes = {
            statusline = {
                "dashboard",
                "alpha",
            },
        },
    },

    sections = {
        lualine_a = {
            {
                "mode",
                fmt = function(str)
                    return str:sub(1, 1)
                end,
            },
        },

        lualine_b = {
            {
                "filename",
                path = 1,
            },
        },

        lualine_c = {},

        lualine_x = {
            "encoding",
            "fileformat",
        },

        lualine_y = {
            "location",
        },

        lualine_z = {
            {
                "datetime",
                style = "%H:%M",
            },
        },
    },
})
