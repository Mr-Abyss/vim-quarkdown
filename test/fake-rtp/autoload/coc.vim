" Test fixture: records coc#config calls for inspection by run.vim.

function! coc#config(key, val) abort
    if !exists('g:fake_coc_configs')
        let g:fake_coc_configs = []
    endif
    call add(g:fake_coc_configs, {'key': a:key, 'val': a:val})
endfunction
