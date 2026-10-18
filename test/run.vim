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
close

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
else
  echo 'SKIP: quarkdown compiler not executable'
endif

redir END
if failures > 0
  echo $'{failures} check(s) FAILED'
  cquit 1
endif
echo 'All checks passed'
qall!
