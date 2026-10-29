vim9script
# vim-quarkdown: buffer-local settings and commands for Quarkdown files.

if exists('b:did_quarkdown_ftplugin')
  finish
endif
b:did_quarkdown_ftplugin = 1

setl commentstring=<!--%s-->
setl comments=s:<!--,m:\ \ \ \ ,e:-->
setl matchpairs+={:}

# Heading-based folding: a level-N heading opens a fold of level N; the
# preamble above the first heading stays unfolded.
if quarkdown#Enabled('quarkdown_folding')
  setl foldmethod=expr
  setl foldexpr=quarkdown#FoldExpr(v:lnum)
endif

command -buffer QuarkdownToc call quarkdown#Toc()
command -buffer -bang -nargs=* QuarkdownCompile call quarkdown#Compile(<bang>0, [<f-args>])
command -buffer QuarkdownOpen call quarkdown#Open()
command -buffer -nargs=* QuarkdownPreview call quarkdown#Preview([<f-args>])
command -buffer QuarkdownStop call quarkdown#Stop()
command -buffer -nargs=? QuarkdownDoc call quarkdown#doc#Show(<q-args>)

# Default mappings (vimtex-style: the important features ship mapped;
# set g:quarkdown_mappings = 0 to install none of them). The <LocalLeader>
# bindings use spacemacs mnemonics — 'q' is the quarkdown prefix, 'c' the
# compile sub-prefix — so no leaf is a prefix of another and nothing
# waits on 'timeoutlen'.
if quarkdown#Enabled('quarkdown_mappings')
  nmap <buffer> [[ <Plug>(quarkdown-prev-heading)
  xmap <buffer> [[ <Plug>(quarkdown-prev-heading)
  omap <buffer> [[ <Plug>(quarkdown-prev-heading)
  nmap <buffer> ]] <Plug>(quarkdown-next-heading)
  xmap <buffer> ]] <Plug>(quarkdown-next-heading)
  omap <buffer> ]] <Plug>(quarkdown-next-heading)

  nmap <buffer> <LocalLeader>qt  <Plug>(quarkdown-toc)
  nmap <buffer> <LocalLeader>qcc <Plug>(quarkdown-compile)
  nmap <buffer> <LocalLeader>qcs <Plug>(quarkdown-compile-sync)
  nmap <buffer> <LocalLeader>qcp <Plug>(quarkdown-compile-pdf)
  nmap <buffer> <LocalLeader>qo  <Plug>(quarkdown-open)
  nmap <buffer> <LocalLeader>qp  <Plug>(quarkdown-preview)
  nmap <buffer> <LocalLeader>qw  <Plug>(quarkdown-preview-watch)
  nmap <buffer> <LocalLeader>qs  <Plug>(quarkdown-stop)
  nmap <buffer> <LocalLeader>qd  <Plug>(quarkdown-doc)
endif

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
if quarkdown#Enabled('quarkdown_complete_auto') && client ==# ''
  inoremap <buffer> <silent> . .<Cmd>call quarkdown#complete#Auto('func')<CR>
  inoremap <buffer> <silent> { {<Cmd>call quarkdown#complete#Auto('param')<CR>
endif
