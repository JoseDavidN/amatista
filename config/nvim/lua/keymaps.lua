local map = vim.keymap.set

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Guardar
map("n", "<leader>w", "<cmd>write<cr>", {
    desc = "Guardar",
})

-- Salir
map("n", "<leader>q", "<cmd>quit<cr>", {
    desc = "Salir",
})

-- Guardar y salir
map("n", "<leader>x", "<cmd>x<cr>", {
    desc = "Guardar y salir",
})

-- Limpiar búsqueda
map("n", "<Esc>", "<cmd>nohlsearch<cr>", {
    desc = "Limpiar búsqueda",
})

-- Explorador
map("n", "<leader>e", "<cmd>Explore<cr>", {
    desc = "Explorador de archivos",
})

map("n", "-", "<cmd>Explore %:p:h<cr>", {
    desc = "Directorio actual",
})

-- Navegación entre ventanas
map("n", "<C-h>", "<C-w>h", {
    desc = "Ventana izquierda",
})

map("n", "<C-j>", "<C-w>j", {
    desc = "Ventana abajo",
})

map("n", "<C-k>", "<C-w>k", {
    desc = "Ventana arriba",
})

map("n", "<C-l>", "<C-w>l", {
    desc = "Ventana derecha",
})

-- Mover líneas
map("n", "<A-j>", "<cmd>move .+1<cr>==", {
    desc = "Mover línea abajo",
})

map("n", "<A-k>", "<cmd>move .-2<cr>==", {
    desc = "Mover línea arriba",
})

map("v", "<A-j>", ":move '>+1<cr>gv=gv", {
    desc = "Mover selección abajo",
})

map("v", "<A-k>", ":move '<-2<cr>gv=gv", {
    desc = "Mover selección arriba",
})
