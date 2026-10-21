" Test fixture: mimics coc#config's merge semantics (dot-path merge into
" g:coc_user_config) and records every call for inspection by run.vim.

function! coc#config(key, val) abort
    if !exists('g:coc_user_config')
        let g:coc_user_config = {}
    endif
    let l:parts = split(a:key, '\.')
    if len(l:parts) == 2
        if !has_key(g:coc_user_config, l:parts[0]) || type(g:coc_user_config[l:parts[0]]) != v:t_dict
            let g:coc_user_config[l:parts[0]] = {}
        endif
        let g:coc_user_config[l:parts[0]][l:parts[1]] = a:val
    else
        let g:coc_user_config[a:key] = a:val
    endif
    if !exists('g:fake_coc_configs')
        let g:fake_coc_configs = []
    endif
    call add(g:fake_coc_configs, {'key': a:key, 'val': a:val})
endfunction
