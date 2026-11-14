local opt = vim.opt

-- Números
opt.number = true
opt.relativenumber = false

-- Indentación
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Búsqueda
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Interfaz
opt.showmode = false
opt.showcmd = false
opt.laststatus = 3
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.pumheight = 10
opt.conceallevel = 0

-- Ventanas
opt.splitright = true
opt.splitbelow = true

-- Archivos
opt.swapfile = false
opt.backup = false
opt.undofile = true

-- Columna de texto
opt.colorcolumn = "100"

-- Clipboard
opt.clipboard = "unnamedplus"
