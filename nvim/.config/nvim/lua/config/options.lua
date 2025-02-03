-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options before

local opt = vim.opt

-- Files
opt.autoread = true -- automatically reload files if they change on disk
opt.autowriteall = true -- Save files when switching buffers

-- Line numbers
opt.number = true -- always show line numbers
opt.relativenumber = false -- disable lazyvim's relative number
