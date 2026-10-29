vim9script
# vim-quarkdown test runner (headless).
# Run from the repository root:
#   vim -es -Nu NONE -U NONE --not-a-term -S test/run.vim; echo "exit=$?"

set nocompatible
set noswapfile
execute 'set rtp^=' .. fnameescape(getcwd())
filetype plugin indent on
syntax on

var failures = 0
redir! > test/last-result.txt

def Check(cond: bool, msg: string)
  if !cond
    failures += 1
    echo $'FAIL: {msg}'
  endif
enddef

def GroupAt(l: number, c: number): string
  # Raw (untranslated) item name: stable regardless of colorscheme cascades.
  return synIDattr(synID(l, c, 1), 'name')
enddef

# --- 1. filetype detection ---------------------------------------------
edit test/examples/sample.qd
Check(&filetype ==# 'quarkdown', $'filetype is quarkdown (got {&filetype})')

# --- 2. ftplugin --------------------------------------------------------
Check(exists(':QuarkdownToc') == 2, 'buffer command :QuarkdownToc exists')
Check(&l:commentstring ==# '<!--%s-->', $'commentstring (got {&l:commentstring})')

# --- 2b. plugin mappings -------------------------------------------------
runtime plugin/quarkdown.vim
Check(maparg('<Plug>(quarkdown-toc)', 'n') !=# '', '<Plug>(quarkdown-toc) defined')
Check(maparg('<Plug>(quarkdown-compile)', 'n') !=# '', '<Plug>(quarkdown-compile) defined')
Check(maparg('<Plug>(quarkdown-next-heading)', 'n') !=# ''
      && maparg('<Plug>(quarkdown-next-heading)', 'x') !=# ''
      && maparg('<Plug>(quarkdown-next-heading)', 'o') !=# '',
      '<Plug>(quarkdown-next-heading) defined in n/x/o')
Check(maparg('<Plug>(quarkdown-prev-heading)', 'n') !=# '',
      '<Plug>(quarkdown-prev-heading) defined')
Check(maparg('<Plug>(quarkdown-compile-pdf)', 'n') !=# '',
      '<Plug>(quarkdown-compile-pdf) defined')
Check(maparg('<Plug>(quarkdown-preview-watch)', 'n') !=# '',
      '<Plug>(quarkdown-preview-watch) defined')
Check(maparg('<Plug>(quarkdown-stop)', 'n') !=# '',
      '<Plug>(quarkdown-stop) defined')

# --- 3. syntax ----------------------------------------------------------
# Line 1: .docname {Sample}
Check(GroupAt(1, 1) ==# 'qdFuncName', $'function name colored (got {GroupAt(1, 1)})')
Check(GroupAt(1, 10) ==# 'qdBraceDelim', $'brace colored as delimiter (got {GroupAt(1, 10)})')
# Line 6: Some text with .sum {1} {2} inline...
Check(GroupAt(6, 16) ==# 'qdFuncName', $'inline call colored (got {GroupAt(6, 16)})')
Check(GroupAt(6, 22) ==# 'qdNumber', $'number arg colored (got {GroupAt(6, 22)})')
# Line 8: ##! Decorative
Check(GroupAt(8, 1) ==# 'qdDecoHeading', $'decorative heading colored (got {GroupAt(8, 1)})')
# Line 13: .notafunc inside fenced code — must NOT be a function
Check(GroupAt(13, 1) !=# 'qdFuncName', $'no function color inside fenced code (got {GroupAt(13, 1)})')
# Line 16/17: math block — delimiter colored, content untouched
Check(GroupAt(16, 1) ==# 'qdMathDelim', $'math delimiter colored (got {GroupAt(16, 1)})')
Check(GroupAt(17, 1) !=# 'qdFuncName', $'math content has no function color (got {GroupAt(17, 1)})')

# --- 4. TOC: heading collection ----------------------------------------
var entries = quarkdown#CollectHeadings(bufnr())
Check(len(entries) == 5, $'5 headings collected (got {len(entries)})')
if len(entries) == 5
  Check(entries[0].text ==# 'Main Title' && entries[0].level == 1 && !entries[0].deco
        && entries[0].lnum == 4, 'entry 0: Main Title, level 1, line 4')
  Check(entries[1].text ==# 'Decorative' && entries[1].level == 2 && entries[1].deco
        && entries[1].lnum == 8, 'entry 1: Decorative, level 2, deco, line 8')
  Check(entries[2].text ==# 'Sub One' && entries[2].level == 2 && entries[2].lnum == 20,
        'entry 2: Sub One, level 2, line 20')
  Check(entries[3].level == 3 && entries[3].lnum == 21, 'entry 3: Deep, level 3, line 21')
  Check(entries[4].deco && entries[4].level == 4 && entries[4].lnum == 22,
        'entry 4: deco, level 4, line 22')
endif
# `#hashtag` (no space) is not a heading; check on a scratch buffer
new
setline(1, ['#hashtag', '####### seven hashes too deep', '# Real'])
var scratch = bufnr()
var sentries = quarkdown#CollectHeadings(scratch)
Check(len(sentries) == 1 && sentries[0].text ==# 'Real', $'non-headings skipped (got {len(sentries)})')
bwipe!

# --- 5. TOC window ------------------------------------------------------
quarkdown#Toc()
Check(winnr('$') == 2, $'toc window opened (windows: {winnr("$")})')
Check(&filetype ==# 'qf', $'toc window is a qf window (got {&filetype})')
Check(len(getloclist(0)) == 5, $'toc loclist has 5 entries (got {len(getloclist(0))})')
# Vim's default quickfix formatting strips leading whitespace of the item
# text, flattening the level indentation; Toc() installs a quickfixtextfunc
# renderer. Assert on the rendered window buffer, not just the loclist data.
var tocwinid = 0
for tw in range(1, winnr('$'))
  if getwinvar(tw, '&filetype') ==# 'qf'
    tocwinid = tw
  endif
endfor
Check(tocwinid > 0, 'toc qf window found')
if tocwinid > 0
  var toclines: list<string> = getbufline(winbufnr(tocwinid), 1, '$')
  Check(len(toclines) == 5, $'toc window renders 5 lines (got {len(toclines)})')
  Check(match(toclines, '|4| Main Title$') >= 0, 'level 1 rendered without indent')
  # '\~': an unescaped ~ in a magic pattern means "last :s pattern" (E33
  # on a fresh session), not a literal tilde.
  Check(match(toclines, '|8|   \~ Decorative$') >= 0, 'level 2 deco rendered with 2-space indent')
  Check(match(toclines, '|20|   Sub One$') >= 0, 'level 2 rendered with 2-space indent')
  Check(match(toclines, '|21|     Deep$') >= 0, 'level 3 rendered with 4-space indent')
  Check(match(toclines, '|22|       \~ Deco deep$') >= 0, 'level 4 deco rendered with 6-space indent')
endif
# q must close the toc window, as both README and the help file promise
# (feedkeys with 't' so the buffer mapping fires; :normal! bypasses mappings)
feedkeys('q', 'xt')
Check(winnr('$') == 1, $'q closes the toc window (windows: {winnr("$")})')

# --- 5b. heading-based folding ------------------------------------------
# sample.qd headings: 4 (#), 8 (##!), 20 (##), 21 (###), 22 (####!)
Check(&l:foldmethod ==# 'expr', $'foldmethod is expr (got {&l:foldmethod})')
Check(&l:foldexpr ==# 'quarkdown#FoldExpr(v:lnum)', $'foldexpr wired (got {&l:foldexpr})')
Check(quarkdown#FoldExpr(1) ==# '=', 'preamble line inherits (no fold start)')
Check(quarkdown#FoldExpr(4) ==# '1', 'level-1 heading folds at 1')
Check(quarkdown#FoldExpr(8) ==# '2', 'deco level-2 heading folds at 2')
Check(quarkdown#FoldExpr(22) ==# '4', 'deco level-4 heading folds at 4')
Check(foldlevel(1) == 0, 'preamble is not folded')
Check(foldlevel(6) == 1, $'body inside level-1 fold (got {foldlevel(6)})')
Check(foldlevel(10) == 2, $'body inside level-2 fold (got {foldlevel(10)})')
Check(foldlevel(22) == 4, $'last heading nests to level 4 (got {foldlevel(22)})')
# fold extents via :setlocal foldlevel (zc closes the outermost fold
# under the cursor; and adjacent closed folds merge in foldclosedend,
# so boundaries are asserted on non-adjacent folds)
setl foldlevel=1
Check(foldclosed(9) == 8, 'level-2 fold starts on its heading line')
setl foldlevel=2
Check(foldclosed(21) == 21 && foldclosedend(21) == 22,
      'level-3 fold spans 21..22 (nested folds)')
setl foldlevel=0
Check(foldclosed(6) == 4 && foldclosedend(6) == line('$'),
      'level-1 fold spans 4..buffer end')
normal! zR
# a fold ends where the next same-or-higher level heading starts; in
# sample.qd the level-2 folds are adjacent (8..19, 20..end) and merge
# visually when closed, so check the boundary on a scratch buffer
new
setline(1, ['# a', 'x', '## b', 'y', '# c', 'z'])
setf quarkdown
setl foldlevel=1
Check(foldclosed(4) == 3 && foldclosedend(4) == 4,
      'level-2 fold ends before the next level-1 heading')
bwipe!

# --- 5c. [[/]] heading motions -------------------------------------------
cursor(1, 1)
quarkdown#MoveHeading(1)
Check(line('.') == 4, $']] from the top lands on the first heading (got {line(".")})')
quarkdown#MoveHeading(1)
Check(line('.') == 8, $']] lands on the next heading (got {line(".")})')
quarkdown#MoveHeading(-1)
Check(line('.') == 4, $'[[ lands on the previous heading (got {line(".")})')
cursor(1, 1)
quarkdown#MoveHeading(-1)
Check(line('.') == 1, '[[ before the first heading stays put (no wrap)')
cursor(line('$'), 1)
quarkdown#MoveHeading(1)
Check(line('.') == line('$'), ']] past the last heading stays put (no wrap)')
# mapped by default to [[ / ]]
Check(maparg(']]', 'n') !=# '' && maparg('[[', 'n') !=# '',
      '[[ and ]] mapped by default')
cursor(1, 1)
feedkeys(']]', 'xt')
Check(line('.') == 4, 'feedkeys ]] moves to the first heading')
# operator target + visual selection on a scratch buffer; :normal drives
# visual-mode mappings reliably headless (feedkeys cannot). The visual
# case runs first: d]] mutates the buffer.
new
setline(1, ['# a', 'text', '# b', 'tail'])
setf quarkdown
cursor(1, 1)
execute 'normal v]]y'
Check(getreg('"') == "# a\ntext\n#", $'v]]y extends the selection (got {string(getreg("\""))})')
cursor(1, 1)
feedkeys('d]]', 'xt')
Check(getline(1, '$') == ['# b', 'tail'], 'd]] deletes up to the next heading')
bwipe!
# g:quarkdown_mappings = 0 installs nothing
g:quarkdown_mappings = 0
new
setf quarkdown
Check(maparg(']]', 'n') ==# '', 'g:quarkdown_mappings = 0 installs no mappings')
bwipe!
unlet! g:quarkdown_mappings

# --- 5d. default <LocalLeader>q mappings ---------------------------------
# <LocalLeader> defaults to a single backslash when unset
var ll = get(g:, 'maplocalleader', '\')
for k in ['qt', 'qcc', 'qcs', 'qcp', 'qo', 'qp', 'qw', 'qs', 'qd']
  Check(maparg(ll .. k, 'n') !=# '', $'<localleader>{k} mapped by default')
endfor
# end-to-end: <localleader>qt opens the TOC window, q closes it
feedkeys(ll .. 'qt', 'xt')
Check(winnr('$') == 2, $'<localleader>qt opens the toc window (windows: {winnr("$")})')
feedkeys('q', 'xt')
Check(winnr('$') == 1, $'q closes the toc window again (windows: {winnr("$")})')
# g:quarkdown_folding = 0 leaves foldmethod alone
g:quarkdown_folding = 0
new
setf quarkdown
Check(&l:foldmethod !=# 'expr', 'folding can be disabled')
bwipe!
unlet! g:quarkdown_folding

# --- 5e. string option values from legacy vimrcs --------------------------
# a legacy vimrc may quote values (`let g:x = '1'`); vim9script rejects
# `if '1'` (E1135), which used to abort the ftplugin and silently drop
# every mapping while commands and folding kept working
g:quarkdown_mappings = '0'
new
setf quarkdown
Check(maparg(']]', 'n') ==# '', 'quarkdown_mappings = "0" (string) installs no mappings')
bwipe!
g:quarkdown_mappings = '1'
new
setf quarkdown
Check(maparg(ll .. 'qt', 'n') !=# '', 'quarkdown_mappings = "1" (string) installs mappings')
bwipe!
unlet! g:quarkdown_mappings

# --- 6. compilation -----------------------------------------------------
if executable('quarkdown')
  var tmp = $'{tempname()}-qdtest'
  mkdir(tmp, 'p')
  writefile(['.docname {Good}', '', '# Hi', '', 'Hello .sum {2} {3}'], tmp .. '/good.qd')
  writefile(['.docname {Bad}', '', '.nosuchfunc {1}'], tmp .. '/bad.qd')

  # sync, success
  execute 'edit' fnameescape(tmp .. '/good.qd')
  var r = quarkdown#Compile(true, ['-o', tmp .. '/out1'])
  Check(r.ok, $'sync compile succeeds (exit {r.code})')

  # sync, failure -> quickfix
  execute 'edit' fnameescape(tmp .. '/bad.qd')
  r = quarkdown#Compile(true, ['-o', tmp .. '/out2'])
  Check(!r.ok, $'sync compile of broken file fails (exit {r.code})')
  var qf = getqflist()
  Check(len(qf) >= 1, $'quickfix populated (got {len(qf)})')
  Check(empty(filter(copy(qf), (_, e: dict<any>): bool => e.text =~ '^\s*at ')),
        'no java stack lines in quickfix')
  cclose

  # async job
  execute 'edit' fnameescape(tmp .. '/good.qd')
  var started = quarkdown#Compile(false, ['-o', tmp .. '/out3'])
  Check(started.ok && get(started, 'started', false), 'async job started')
  var waited = 0
  while quarkdown#Running() && waited < 600
    sleep 100m
    waited += 1
  endwhile
  Check(!quarkdown#Running(), 'async job finished')
  Check(quarkdown#LastResult().ok, $'async compile succeeds (exit {quarkdown#LastResult().code})')

  # --- 6b. command assembly (BuildCmd) -----------------------------------
  var bc = quarkdown#BuildCmd('x.qd', ['-o', 'b'])
  Check(index(bc, '--strict') >= 0, '--strict default on')
  var ti = index(bc, '--timeout')
  Check(ti >= 0 && bc[ti + 1] ==# '0', '--timeout 0 default (30s CLI default disabled)')
  Check(index(bc, '-o') >= 0, 'extra args appended')
  g:quarkdown_compile_timeout = 120
  bc = quarkdown#BuildCmd('x.qd', [])
  ti = index(bc, '--timeout')
  Check(ti >= 0 && bc[ti + 1] ==# '120', 'g:quarkdown_compile_timeout respected')
  g:quarkdown_compile_timeout = -1
  Check(index(quarkdown#BuildCmd('x.qd', []), '--timeout') < 0, 'timeout -1 omits flag')
  g:quarkdown_compile_timeout = 0
  g:quarkdown_compile_strict = 0
  Check(index(quarkdown#BuildCmd('x.qd', []), '--strict') < 0, 'strict can be disabled')
  g:quarkdown_compile_strict = 1

  # --- 6c. sync output lands beside the file, not beside vim's cwd -------
  mkdir(tmp .. '/deep', 'p')
  writefile(['.docname {Deep}', '', '# Deep doc', ''], tmp .. '/deep/good.qd')
  var repoDir = getcwd()
  chdir(tmp)
  execute 'edit' fnameescape(tmp .. '/deep/good.qd')
  var deep = quarkdown#Compile(true, [])
  Check(deep.ok, $'sync compile from foreign cwd ok (exit {deep.code})')
  Check(isdirectory(tmp .. '/deep/quarkdown-output'), 'output beside the file')
  Check(!isdirectory(tmp .. '/quarkdown-output'), 'no output in vim cwd')
  Check(quarkdown#LastOut() !=# '' && isdirectory(quarkdown#LastOut()),
        $'Success@ path parsed (got {quarkdown#LastOut()})')
  Check(filereadable(quarkdown#LastOut() .. '/index.html'), 'index.html exists in output')
  chdir(repoDir)

  # --- 6d. Stop() is a safe no-op when idle ------------------------------
  quarkdown#Stop()

  # --- 6e. preview server lifecycle ---------------------------------------
  # random port: a fixed one can collide with anything already listening
  # on the machine (Zotero grabbed 19876 one day)
  var port = string(20000 + reltime()[1] % 20000)
  execute 'edit' fnameescape(tmp .. '/good.qd')
  var pv = quarkdown#Preview(['-b', 'none', '--server-port', port])
  Check(pv.ok && get(pv, 'started', false), 'preview job started')
  var code = '000'
  waited = 0
  while waited < 250
    code = system($'curl -s -m 2 -o /dev/null -w "%{{http_code}}" http://127.0.0.1:{port}')
    if code =~ '^[1-5]'
      break
    endif
    sleep 100m
    waited += 1
  endwhile
  Check(code =~ '^[1-5]', $'preview server responds (http {code})')
  Check(quarkdown#PreviewRunning(), 'PreviewRunning() true')
  quarkdown#Stop()
  sleep 1000m
  var after = system($'curl -s -m 2 -o /dev/null -w "%{{http_code}}" http://127.0.0.1:{port}')
  Check(after ==# '000', $'preview server stopped cleanly, no orphan (http {after})')
  Check(!quarkdown#PreviewRunning(), 'PreviewRunning() false after stop')
else
  echo 'SKIP: quarkdown compiler not executable'
endif

# --- 7. stdlib catalogue data -------------------------------------------
Check(quarkdown#data#Loaded(), 'stdlib catalogue loads from data/stdlib.json')
var funcs = quarkdown#data#Functions()
Check(len(funcs) > 100, $'catalogue has >100 functions (got {len(funcs)})')
var sumf = quarkdown#data#Find('sum')
Check(!empty(sumf), 'Find(sum) works')
Check(len(get(sumf, 'params', [])) == 2, $'sum has 2 params (got {len(get(sumf, "params", []))})')
Check(get(sumf, 'module', '') !=# '', 'sum carries its module name')
Check(empty(quarkdown#data#Find('zzz_nope')), 'Find of unknown function is empty')

# --- 7b. offline completion (omnifunc) ----------------------------------
# NOTE: in normal mode the cursor cannot sit past the last character of a
# line, so each test line carries trailing text to anchor the cursor right
# after the word being completed (as it would be in insert mode).
new
setf quarkdown
setline(1, ['.su x'])
cursor(1, 4)
var cstart = quarkdown#complete#Omni(1, '')
Check(cstart == 1, $'findstart after . is 1 (got {cstart})')
var citems = quarkdown#complete#Omni(0, 'su')
var cwords = map(copy(citems), (_, x: dict<any>): string => x.word)
Check(index(cwords, 'sum') >= 0, $'completes "sum" for .su (got {join(cwords, ",")})')
Check(!empty(citems) && citems[0].menu =~ '\[', 'function items carry [module] menu')

setline(2, ['.container wid x'])
cursor(2, 15)
citems = quarkdown#complete#Omni(0, 'wid')
cwords = map(copy(citems), (_, x: dict<any>): string => x.word)
Check(index(cwords, 'width:') >= 0, $'completes param "width:" (got {join(cwords, ",")})')

setline(3, ['.container width:{1px} he x'])
cursor(3, 24)
citems = quarkdown#complete#Omni(0, 'he')
cwords = map(copy(citems), (_, x: dict<any>): string => x.word)
Check(index(cwords, 'height:') >= 0, 'completes not-yet-used param "height:"')
Check(index(cwords, 'width:') < 0, 'already-used param "width:" is skipped')

# no completion context in prose
setline(4, ['plain text and more words'])
cursor(4, 21)
Check(quarkdown#complete#Omni(1, '') == -1, 'findstart is -1 in plain prose')
bwipe!

# --- 7c. documentation ---------------------------------------------------
var dlines = quarkdown#doc#Lines(sumf)
Check(!empty(dlines) && dlines[0] =~ 'sum', 'doc Lines() title contains name')
Check(len(dlines) > 5, 'doc Lines() renders some body')
var docok = true
try
  quarkdown#doc#Show('sum')
catch
  docok = false
endtry
Check(docok, 'QuarkdownDoc opens the popup')
if docok
  Check(len(popup_list()) > 0, 'doc popup exists')
  popup_clear()
endif

# --- 8. LSP client glue (fake clients on the runtimepath) ---------------
execute 'set rtp^=' .. fnameescape(getcwd() .. '/test/fake-rtp')
unlet! g:loaded_quarkdown
runtime plugin/quarkdown.vim
Check(exists('g:fake_coc_configs'), 'plugin load registers with coc when present')
if exists('g:fake_coc_configs')
  var cconf = g:fake_coc_configs[0]
  Check(cconf.key ==# 'languageserver.quarkdown', $'coc config key (got {cconf.key})')
  Check(type(cconf.val) == v:t_dict && get(cconf.val, 'filetypes', []) == ['quarkdown'],
        'coc entry targets quarkdown filetype')
  var cargs = get(cconf.val, 'args', [])
  Check(index(cargs, 'language-server') >= 0, 'coc entry launches language-server')
endif

# self-heal: a `let g:coc_user_config = {...}` in a user vimrc (sourced
# after plug#end() ran the plugin) replaces the dict and wipes the startup
# injection; Setup() must restore the entry without touching user keys.
g:coc_user_config = {'python.analysis.typeCheckingMode': 'off'}
quarkdown#lsp#Setup()
var healed = get(get(g:coc_user_config, 'languageserver', {}), 'quarkdown', {})
Check(type(healed) == v:t_dict && !empty(healed), 'coc entry re-injected after vimrc clobber')
Check(g:coc_user_config['python.analysis.typeCheckingMode'] ==# 'off',
      'user coc config keys survive re-injection')
# second Setup() on the healed config must not re-inject (idempotent)
var ncoc = len(g:fake_coc_configs)
quarkdown#lsp#Setup()
Check(len(g:fake_coc_configs) == ncoc, 'coc injection is idempotent once present')

g:quarkdown_lsp_clients = ['ale', 'vim-lsp']
quarkdown#lsp#Setup()
Check(exists('g:fake_ale_defs') && len(g:fake_ale_defs) > 0, 'Setup registers ale linter')
if exists('g:fake_ale_defs')
  var aft = g:fake_ale_defs[0].ft
  var adef = g:fake_ale_defs[0].def
  Check(aft ==# 'quarkdown', $'ale linter filetype (got {aft})')
  Check(get(adef, 'lsp', '') ==# 'stdio', 'ale linter is stdio LSP')
  Check(get(adef, 'command', '') =~ 'language-server', 'ale command runs language-server')
  Check(get(adef, 'language', '') ==# 'quarkdown', 'ale linter language is quarkdown')
  var Aexe: any = get(adef, 'executable', '')
  if type(Aexe) == v:t_func
    Aexe = Aexe(0)
  endif
  Check(Aexe ==# 'quarkdown', $'ale executable resolves (got {Aexe})')
endif
Check(exists('g:fake_vimlsp_servers') && len(g:fake_vimlsp_servers) > 0, 'Setup registers vim-lsp server')
if exists('g:fake_vimlsp_servers')
  var vdef = g:fake_vimlsp_servers[0]
  Check(get(vdef, 'name', '') ==# 'quarkdown', 'vim-lsp server name')
  var vcmd = vdef.cmd({})
  Check(index(vcmd, 'language-server') >= 0, $'vim-lsp cmd launches language-server (got {string(vcmd)})')
  Check(get(vdef, 'allowlist', []) == ['quarkdown'], 'vim-lsp allowlist is quarkdown')
endif

# ActiveClient preference and omnifunc wiring
unlet! g:quarkdown_lsp_clients
if executable('quarkdown')
  Check(quarkdown#lsp#ActiveClient() ==# 'coc', $'auto picks coc first (got {quarkdown#lsp#ActiveClient()})')
  g:quarkdown_lsp_clients = ['vim-lsp']
  new
  setf quarkdown
  Check(&l:omnifunc ==# 'lsp#complete', $'omnifunc points at vim-lsp (got {&l:omnifunc})')
  Check(empty(maparg('.', 'i')), 'no offline auto-popup when a client is active')
  bwipe!
  g:quarkdown_lsp_clients = 0  # no supported client -> offline mode
  new
  setf quarkdown
  Check(&l:omnifunc ==# 'quarkdown#complete#Omni', $'omnifunc falls back offline (got {&l:omnifunc})')
  Check(!empty(maparg('.', 'i')), 'offline auto-popup installed without a client')
  bwipe!
  unlet! g:quarkdown_lsp_clients
endif
# isolate: drop fakes again for the LSP smoke test below
execute 'set rtp-=' .. fnameescape(getcwd() .. '/test/fake-rtp')
unlet! g:fake_coc_configs g:fake_ale_defs g:fake_vimlsp_servers

# --- 9. LSP server smoke test (real server over a vim channel) ------
# State and helpers live at script level: :def functions cannot capture
# variables declared inside an if-block. The channel uses vim's built-in
# 'lsp' mode, which does the Content-Length framing and JSON decoding.
var lsp_diags: list<any> = []
var lsp_gotdiag = false
var lsp_caps: dict<any> = {}
var lsp_stage = 0
var lsp_doc = $'{tempname()}-lsp.qd'
var lsp_uri = ''

def LspOnMessage(ch: channel, msg: any)
  if type(msg) != v:t_dict
    return
  endif
  var d: dict<any> = msg
  if lsp_stage == 0 && d->get('id', -1) == 1 && has_key(d, 'result')
    lsp_caps = d.result->get('capabilities', {})
    lsp_stage = 1
    ch_sendexpr(ch, {jsonrpc: '2.0', method: 'initialized', params: {}})
    ch_sendexpr(ch, {jsonrpc: '2.0', method: 'textDocument/didOpen', params: {
      textDocument: {uri: lsp_uri, languageId: 'quarkdown', version: 1,
                     text: "# Lint\n\n.row {bogus:{1}} {x}\n"},
    }})
    # the server only publishes diagnostics on didChange, never on didOpen
    ch_sendexpr(ch, {jsonrpc: '2.0', method: 'textDocument/didChange', params: {
      textDocument: {uri: lsp_uri, version: 2},
      contentChanges: [{text: "# Lint\n\n.row {bogus:{1}} {x}\n"}],
    }})
  elseif d->get('method', '') ==# 'textDocument/publishDiagnostics'
    lsp_diags = d->get('params', {})->get('diagnostics', [])
    lsp_gotdiag = true
  endif
enddef

if executable('quarkdown')
  mkdir(fnamemodify(lsp_doc, ':h'), 'p')
  writefile(['# Lint', '', '.row {bogus:{1}} {x}', ''], lsp_doc)
  lsp_uri = 'file:///' .. substitute(fnamemodify(lsp_doc, ':p'), '\', '/', 'g')
  var lsp_job = job_start(quarkdown#SpawnCmd(['quarkdown', 'language-server']), {
    mode: 'lsp',
    out_cb: (ch: channel, msg: any) => LspOnMessage(ch, msg),
    err_cb: (ch: channel, msg: string) => 0,
  })
  if job_status(lsp_job) ==# 'run'
    ch_sendexpr(job_getchannel(lsp_job), {
      jsonrpc: '2.0', id: 1, method: 'initialize',
      params: {
        processId: v:null,
        rootUri: 'file:///' .. substitute(fnamemodify(lsp_doc, ':h'), '\', '/', 'g'),
        capabilities: {},
      },
    })
    var waited = 0
    while lsp_stage == 0 && waited < 300
      sleep 100m
      waited += 1
    endwhile
    Check(lsp_stage == 1, $'language server answered initialize (stage {lsp_stage})')
    Check(type(get(lsp_caps, 'completionProvider', 0)) == v:t_dict, 'server advertises completion')
    Check(get(lsp_caps, 'hoverProvider', v:false) == v:true, 'server advertises hover')
    waited = 0
    while !lsp_gotdiag && waited < 300
      sleep 100m
      waited += 1
    endwhile
    Check(lsp_gotdiag, 'server publishes diagnostics for a bad parameter value')
    Check(!empty(lsp_diags), 'diagnostics are non-empty for a bad parameter value')
    if !empty(lsp_diags)
      Check(lsp_diags[0]->get('message', '') =~ 'Allowed values', 'diagnostic explains allowed values')
      Check(type(lsp_diags[0]->get('range', 0)) == v:t_dict, 'diagnostic carries a range')
    endif
    # graceful shutdown (avoids orphaning the JVM behind wrappers)
    ch_sendexpr(job_getchannel(lsp_job), {jsonrpc: '2.0', id: 2, method: 'shutdown', params: v:null})
    ch_sendexpr(job_getchannel(lsp_job), {jsonrpc: '2.0', method: 'exit', params: v:null})
    sleep 1500m
    if job_status(lsp_job) ==# 'run'
      quarkdown#KillJob(lsp_job)
    endif
  else
    echo 'SKIP: language server job did not start'
  endif
endif

# --- 10. help documentation ---------------------------------------------
# :helptags must accept the file, the entry tags must be generated, and
# :h vim-quarkdown must open the actual help buffer.
execute 'helptags' fnameescape(getcwd() .. '/doc')
var htagfile = getcwd() .. '/doc/tags'
Check(filereadable(htagfile), 'doc/tags generated by :helptags')
var htags = filereadable(htagfile) ? join(readfile(htagfile), "\n") : ''
Check(htags =~ "vim-quarkdown\t", ':h vim-quarkdown tag exists')
Check(htags =~ ":QuarkdownCompile\t", ':h :QuarkdownCompile tag exists')
Check(htags =~ ":QuarkdownDoc\t", ':h :QuarkdownDoc tag exists')
Check(htags =~ 'g:quarkdown_lsp\t', ':h g:quarkdown_lsp tag exists')
Check(htags =~ 'g:quarkdown_folding\t', ':h g:quarkdown_folding tag exists')
Check(htags =~ '<Plug>(quarkdown-doc)\t', ':h <Plug>(quarkdown-doc) tag exists')
Check(htags =~ '<Plug>(quarkdown-next-heading)\t',
      ':h <Plug>(quarkdown-next-heading) tag exists')
Check(htags =~ '<Plug>(quarkdown-compile-pdf)\t',
      ':h <Plug>(quarkdown-compile-pdf) tag exists')
Check(htags =~ 'g:quarkdown_mappings\t', ':h g:quarkdown_mappings tag exists')
var helpok = true
try
  execute 'help vim-quarkdown'
catch
  helpok = false
endtry
Check(helpok, ':h vim-quarkdown opens without error')
if helpok
  Check(&filetype ==# 'help', $'help buffer filetype (got {&filetype})')
  Check(getline(1) =~ 'vim-quarkdown\.txt', 'help buffer shows the doc file')
  Check(search('Known limitations', 'cwn') > 0, 'help buffer has real content')
  bwipe!
endif

redir END
if failures > 0
  echo $'{failures} check(s) FAILED'
  cquit 1
endif
echo 'All checks passed'
qall!
