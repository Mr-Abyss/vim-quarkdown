" Test fixture: records ale#linter#Define calls for inspection by run.vim.

function! ale#linter#Define(ft, def) abort
    if !exists('g:fake_ale_defs')
        let g:fake_ale_defs = []
    endif
    call add(g:fake_ale_defs, {'ft': a:ft, 'def': a:def})
endfunction
