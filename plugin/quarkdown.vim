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
