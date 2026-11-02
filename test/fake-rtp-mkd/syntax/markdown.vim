" Stand-in for preservim/vim-markdown, used by test/run.vim: html.vim at
" top level inside a block region and no markdownValid guard - so a bare
" "a < b" opens an htmlTag unless syntax/quarkdown.vim stops it.
runtime! syntax/html.vim
unlet! b:current_syntax
syn region mkdNonListItemBlock start=/^/ end=/$/ contains=@htmlTop
let b:current_syntax = 'markdown'
