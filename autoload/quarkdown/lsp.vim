vim9script
# vim-quarkdown: registration glue for the quarkdown language server.
#
# The server ships inside the quarkdown CLI (`quarkdown language-server`,
# quarkdown >= 1.9.0) and provides completion, hover and diagnostics over
# stdio. No LSP client is presupposed: whichever of the supported clients —
# coc.nvim, ale or vim-lsp — is installed gets the server registered, and
# without any of them the plugin falls back to bundled-data completion.
#
#   coc      config pushed into g:coc_user_config (session-only, never
#            written to coc-settings.json); alternatively install the
#            coc-quarkdown extension.
#   ale      LSP linter definition via ale#linter#Define (diagnostics,
#            completion, :ALEHover).
#   vim-lsp  server via lsp#register_server (diagnostics, completion,
#            :LspHover).

import autoload 'quarkdown.vim' as main

var done: dict<bool> = {}

# The raw launch command (binary + subcommand), before platform wrapping.
export def ServerCmd(): list<string>
  return [Compiler(), 'language-server']
enddef

# Launch list suitable for vim-lsp, which hands it straight to job_start():
# on native Windows vim, CreateProcess cannot run the .cmd wrapper the
# quarkdown CLI ships as, so route through cmd.exe (same trick as compile
# jobs; see the comment on quarkdown#SpawnCmd for the has() caveats).
export def SpawnList(): list<string>
  return main.SpawnCmd(ServerCmd())
enddef

def Compiler(): string
  return get(g:, 'quarkdown_compiler', 'quarkdown')
enddef

def HasCoc(): bool
  return exists('*coc#config') == 1 || RtpHas('autoload/coc.vim')
enddef

def HasAle(): bool
  return exists('*ale#linter#Define') == 1 || RtpHas('autoload/ale/linter.vim')
enddef

def HasVimLsp(): bool
  return exists('*lsp#register_server') == 1 || RtpHas('autoload/lsp.vim')
enddef

# exists('*client#Func') does not reliably find not-yet-sourced autoload
# scripts on every build, so scan the runtimepath directly (filereadable
# is trustworthy everywhere).
def RtpHas(relpath: string): bool
  for d in split(&rtp, ',')
    if d !=# '' && filereadable(d .. '/' .. relpath)
      return true
    endif
  endfor
  return false
enddef

# Which clients to register with. g:quarkdown_lsp_clients is 'auto'
# (default; picks the first available of coc, ale, vim-lsp — one server is
# enough) or a list like ['ale', 'vim-lsp'] to force specific clients.
def ChosenClients(): list<string>
  var pref = get(g:, 'quarkdown_lsp_clients', 'auto')
  if type(pref) == v:t_string && pref ==# 'auto'
    if HasCoc()
      return ['coc']
    endif
    if HasAle()
      return ['ale']
    endif
    if HasVimLsp()
      return ['vim-lsp']
    endif
    return []
  endif
  if type(pref) != v:t_list
    return []
  endif
  return copy(pref)->filter((_, c: string): bool =>
        c ==# 'coc' || c ==# 'ale' || c ==# 'vim-lsp')
enddef

# Whether the quarkdown binary is on PATH (a proxy for the CLI being
# installed; a CLI older than 1.9.0 lacks the language-server subcommand).
export def Available(): bool
  return executable(Compiler()) != 0
enddef

# The client the current buffer should lean on ('' when none). Used by the
# ftplugin to pick &omnifunc and to suppress the offline auto-popup.
export def ActiveClient(): string
  if !get(g:, 'quarkdown_lsp', 1) || !Available()
    return ''
  endif
  var chosen = ChosenClients()
  if index(chosen, 'coc') >= 0 && HasCoc()
    return 'coc'
  endif
  if index(chosen, 'ale') >= 0 && HasAle()
    return 'ale'
  endif
  if index(chosen, 'vim-lsp') >= 0 && HasVimLsp()
    return 'vim-lsp'
  endif
  return ''
enddef

# Register the server with every chosen and installed client. Idempotent;
# called from plugin/quarkdown.vim at load time (early enough for coc's
# config to be picked up when its service starts) and from the ftplugin
# (covers clients that were lazy-loaded later).
export def Setup()
  if !get(g:, 'quarkdown_lsp', 1) || !Available()
    return
  endif
  for c in ChosenClients()
    if c ==# 'coc' && HasCoc()
      done.coc = true
      # node's spawn cannot run .cmd wrappers directly on Windows, so hand
      # coc the same platform-wrapped launch list as every other spawn.
      var cmd = SpawnList()
      var entry = {command: cmd[0], args: cmd[1 :], filetypes: ['quarkdown']}
      # A plain `let g:coc_user_config = {...}` further down in a user
      # vimrc (a very common pattern, sourced after plug#end() ran this
      # plugin) replaces the whole dict and wipes the startup injection.
      # Self-heal: re-inject whenever the entry is missing.
      # coc#config merges into g:coc_user_config only: session-only,
      # never written to the user's coc-settings.json.
      var servers: any = get(get(g:, 'coc_user_config', {}), 'languageserver', {})
      if type(servers) != v:t_dict || !has_key(servers, 'quarkdown')
        coc#config('languageserver.quarkdown', entry)
        if get(g:, 'coc_service_initialized', 0)
          # Service already running: reload config so it picks the server up.
          silent! execute 'CocRestart'
        endif
      endif
    elseif c ==# 'ale' && HasAle() && !get(done, 'ale', false)
      done.ale = true
      ale#linter#Define('quarkdown', {
        name: 'quarkdown',
        lsp: 'stdio',
        # funcref form so g:quarkdown_compiler is resolved at lint time
        executable: (b: number): string => Compiler(),
        command: '%e language-server',
        language: 'quarkdown',
      })
    elseif c ==# 'vim-lsp' && HasVimLsp() && !get(done, 'vim-lsp', false)
      done['vim-lsp'] = true
      try
        lsp#register_server({
          name: 'quarkdown',
          cmd: (server_info: dict<any>): list<string> => SpawnList(),
          allowlist: ['quarkdown'],
        })
      catch
        # the user registered their own 'quarkdown' server: leave it alone
      endtry
    endif
  endfor
enddef
