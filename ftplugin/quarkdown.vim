vim9script
# vim-quarkdown: buffer-local settings and commands for Quarkdown files.

if exists("b:did_quarkdown_ftplugin")
  finish
endif
b:did_quarkdown_ftplugin = 1

setl commentstring=<!--%s-->
setl comments=s:<!--,m:\ \ \ \ ,e:-->
setl matchpairs+={:}

command -buffer QuarkdownToc call quarkdown#Toc()
command -buffer -bang -nargs=* QuarkdownCompile call quarkdown#Compile(<bang>0, [<f-args>])
command -buffer QuarkdownOpen call quarkdown#Open()
command -buffer -nargs=* QuarkdownPreview call quarkdown#Preview([<f-args>])
command -buffer QuarkdownStop call quarkdown#Stop()
command -buffer -nargs=? QuarkdownDoc call quarkdown#doc#Show(<q-args>)

# Register the language server with any installed LSP client (covers
# clients that were lazy-loaded after plugin/quarkdown.vim ran).
quarkdown#lsp#Setup()

# Completion: point &omnifunc at the active LSP client when it serves
# completions; coc drives its own popup and keeps this omnifunc as an
# offline fallback for C-X C-O.
var client = quarkdown#lsp#ActiveClient()
if client ==# 'ale'
  setl omnifunc=ale#completion#OmniFunc
elseif client ==# 'vim-lsp'
  setl omnifunc=lsp#complete
else
  setl omnifunc=quarkdown#complete#Omni
endif

# Offline auto-popup right after '.' / '{' — only without an LSP client,
# which shows its own (live, context-aware) completions.
if get(g:, 'quarkdown_complete_auto', 1) && client ==# ''
  inoremap <buffer> <silent> . .<Cmd>call quarkdown#complete#Auto('func')<CR>
  inoremap <buffer> <silent> { {<Cmd>call quarkdown#complete#Auto('param')<CR>
endif
