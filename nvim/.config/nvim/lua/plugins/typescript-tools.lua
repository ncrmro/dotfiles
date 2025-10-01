return {
  "pmizio/typescript-tools.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = {
    settings = {
      -- Separate TypeScript diagnostic server for better performance
      separate_diagnostic_server = true,
      
      -- Publish diagnostics on insert leave (reduce noise while typing)
      publish_diagnostic_on = "insert_leave",
      
      -- Expose as global to make it easier to access
      expose_as_code_action = {},
      
      -- TypeScript server preferences for enhanced autocomplete
      tsserver_file_preferences = {
        -- Enable library type completions (like @types packages)
        includeCompletionsForModuleExports = true,
        
        -- Include completions with insert text (better snippets)
        includeCompletionsWithInsertText = true,
        
        -- Auto-import suggestions
        includeCompletionsForImportStatements = true,
        
        -- Inlay hints for better code understanding
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
      
      -- TypeScript server configuration
      tsserver_plugins = {},
      
      -- Complete function calls with parameters
      complete_function_calls = true,
      
      -- JSX tag auto-closing
      jsx_close_tag = {
        enable = true,
        filetypes = { "javascriptreact", "typescriptreact" },
      },
    },
  },
}