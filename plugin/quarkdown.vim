vim9script
# vim-quarkdown: global setup. Commands live in ftplugin/quarkdown.vim.

if exists("g:loaded_quarkdown")
  finish
endif
if !has('vim9script')
  echoerr 'vim-quarkdown requires Vim 9.0 or later'
  finish
endif
g:loaded_quarkdown = 1

nnoremap <silent> <Plug>(quarkdown-toc) :<C-u>call quarkdown#Toc()<CR>
nnoremap <silent> <Plug>(quarkdown-compile) :<C-u>call quarkdown#Compile(false, [])<CR>
nnoremap <silent> <Plug>(quarkdown-compile-sync) :<C-u>call quarkdown#Compile(true, [])<CR>
nnoremap <silent> <Plug>(quarkdown-open) :<C-u>call quarkdown#Open()<CR>
nnoremap <silent> <Plug>(quarkdown-preview) :<C-u>call quarkdown#Preview([])<CR>
nnoremap <silent> <Plug>(quarkdown-doc) :<C-u>call quarkdown#doc#Show('')<CR>

# Register the quarkdown language server with any installed LSP client
# (coc / ale / vim-lsp; see :h quarkdown-lsp). This early call matters for
# coc: its server config must land in g:coc_user_config before the coc
# service starts reading it.
quarkdown#lsp#Setup()
