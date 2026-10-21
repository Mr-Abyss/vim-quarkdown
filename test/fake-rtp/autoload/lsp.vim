" Test fixture: records lsp#register_server calls for inspection by run.vim.

function! lsp#register_server(opts) abort
    if !exists('g:fake_vimlsp_servers')
        let g:fake_vimlsp_servers = []
    endif
    call add(g:fake_vimlsp_servers, a:opts)
endfunction
