vim9script
# vim-quarkdown: global setup. Commands live in ftplugin/quarkdown.vim.

if exists('g:loaded_quarkdown')
  finish
endif
if !has('vim9script')
  echoerr 'vim-quarkdown requires Vim 9.0 or later'
  finish
endif
g:loaded_quarkdown = 1

# A mapping rhs executes on the legacy command line: bare true/false are
# E121 there — v:-constants are the only spelling both dialects accept.
nnoremap <silent> <Plug>(quarkdown-toc) :<C-u>call quarkdown#Toc()<CR>
nnoremap <silent> <Plug>(quarkdown-compile) :<C-u>call quarkdown#Compile(v:false, [])<CR>
nnoremap <silent> <Plug>(quarkdown-compile-sync) :<C-u>call quarkdown#Compile(v:true, [])<CR>
nnoremap <silent> <Plug>(quarkdown-open) :<C-u>call quarkdown#Open()<CR>
nnoremap <silent> <Plug>(quarkdown-preview) :<C-u>call quarkdown#Preview([])<CR>
nnoremap <silent> <Plug>(quarkdown-preview-watch) :<C-u>call quarkdown#Preview(['-w'])<CR>
nnoremap <silent> <Plug>(quarkdown-doc) :<C-u>call quarkdown#doc#Show('')<CR>
nnoremap <silent> <Plug>(quarkdown-compile-pdf) :<C-u>call quarkdown#Compile(v:false, ['--pdf'])<CR>
nnoremap <silent> <Plug>(quarkdown-stop) :<C-u>call quarkdown#Stop()<CR>

nnoremap <silent> <Plug>(quarkdown-todo-md) :<C-u>call quarkdown#todo#CycleMarkdown()<CR>
nnoremap <silent> <Plug>(quarkdown-todo-note) :<C-u>call quarkdown#todo#CycleNote()<CR>
nnoremap <silent> <Plug>(quarkdown-todo-heading) :<C-u>call quarkdown#todo#CycleHeading()<CR>
nnoremap <silent> <Plug>(quarkdown-todo-forward) :<C-u>call quarkdown#todo#Shift(v:true)<CR>
nnoremap <silent> <Plug>(quarkdown-todo-back) :<C-u>call quarkdown#todo#Shift(v:false)<CR>
nnoremap <silent> <Plug>(quarkdown-todos) :<C-u>call quarkdown#todo#Agenda()<CR>

nnoremap <silent> <Plug>(quarkdown-next-heading) :<C-u>call quarkdown#MoveHeading(1)<CR>
onoremap <silent> <Plug>(quarkdown-next-heading) :<C-u>call quarkdown#MoveHeading(1)<CR>
# visual variant rebuilds the selection from the fixed anchor: neither
# an ex-call nor a '/'-rhs can extend a selection from a visual mapping
xnoremap <silent> <Plug>(quarkdown-next-heading) :<C-u>call quarkdown#MoveHeadingV(1)<CR>
nnoremap <silent> <Plug>(quarkdown-prev-heading) :<C-u>call quarkdown#MoveHeading(-1)<CR>
onoremap <silent> <Plug>(quarkdown-prev-heading) :<C-u>call quarkdown#MoveHeading(-1)<CR>
xnoremap <silent> <Plug>(quarkdown-prev-heading) :<C-u>call quarkdown#MoveHeadingV(-1)<CR>

# Register the quarkdown language server with any installed LSP client
# (coc / ale / vim-lsp; see :h quarkdown-lsp). This early call matters for
# coc: its server config must land in g:coc_user_config before the coc
# service starts reading it.
quarkdown#lsp#Setup()
