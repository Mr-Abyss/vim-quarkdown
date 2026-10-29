vim9script
# vim-quarkdown: offline completion from the bundled stdlib catalogue.
#
# Works with no LSP client installed. When ale or vim-lsp is active the
# ftplugin points &omnifunc at the client instead (live server data,
# including user-defined functions); coc drives its own popup and this
# omnifunc remains available as a C-X C-O fallback.

# Smart braces, fired from the ftplugin's CompleteDone hook. After any
# completion source (offline omnifunc, coc, ale, vim-lsp) inserts a
# stdlib function that takes parameters, open its {} and park the cursor
# inside.
export def ExpandBraces()
  # strip a leading dot (coc-style completion words carry one); vim9
  # single quotes pass backslashes through literally, so the regex is
  # '^\.' - '^\.' with two backslashes would match a literal backslash
  var word = substitute(get(v:completed_item, 'word', ''), '^\.', '', '')
  if word ==# ''
    return
  endif
  var ahead = getline('.')->strpart(col('.') - 1) =~# '^\s*{'
  var keys = BracesKeys(word, ahead)
  if keys !=# ''
    # queued, not executed: we are inside an ongoing insert, the keys
    # land in that same session
    feedkeys(keys, 'i')
  endif
enddef

# The pure decision: keys to open {} for a completed function name, ''
# when none apply. braceAhead = a '{' already follows the cursor.
export def BracesKeys(word: string, braceAhead: bool): string
  if !quarkdown#Enabled('quarkdown_complete_braces') || braceAhead
    return ''
  endif
  var f = quarkdown#data#Find(substitute(word, '^\.', '', ''))
  # any parameter counts: stdlib defaults are strings like "null" even
  # when the sensible call always passes the argument (.docname)
  if empty(f) || empty(get(f, 'params', []))
    return ''
  endif
  return '{}\\<C-g>U\\<Left>'
enddef

# Signature on one line: join '\'-continued lines back together.
def OneLineSig(sig: string): string
  var parts = split(sig, "\n")
  return join(map(parts, (_, v: string): string => trim(substitute(v, '\\$', '', ''))), ' ')
enddef

# Compact info text for the completion preview window.
def FuncInfo(f: dict<any>): string
  var info: list<string> = [OneLineSig(get(f, 'signature', ''))]
  var descs: list<string> = []
  for p in get(f, 'params', [])
    var d = $'  {p.name}: {get(p, 'type', '')}'
    if has_key(p, 'default') && p.default != null
      d ..= $' = {p.default}'
    endif
    if get(p, 'desc', '') != ''
      d ..= $' — {p.desc}'
    endif
    add(descs, d)
  endfor
  if !empty(descs)
    add(info, '')
    info += descs
  endif
  add(info, '')
  add(info, $':QuarkdownDoc {f.name} for full documentation')
  return join(info, "\n")
enddef

def ParamInfo(p: dict<any>): string
  var info: list<string> = [$'{p.name}: {get(p, 'type', '')}']
  if has_key(p, 'default') && p.default != null
    add(info, $'default: {p.default}')
  endif
  if get(p, 'desc', '') != ''
    add(info, '')
    add(info, p.desc)
  endif
  return join(info, "\n")
enddef

# Function-name items matching a prefix.
def FuncItems(base: string): list<dict<any>>
  var pat = base != '' ? '^' .. escape(base, '~.*[]\^$') : ''
  var items: list<dict<any>> = []
  for f in quarkdown#data#Functions()
    if pat != '' && f.name !~? pat
      continue
    endif
    add(items, {
      word: f.name,
      menu: $'[{get(f, "module", "")}]',
      kind: 'f',
      info: FuncInfo(f),
    })
  endfor
  return items
enddef

# Parameter-name items for a function call. `used` is the call text between
# the function name and the cursor, used to skip already-supplied params.
def ParamItems(f: dict<any>, base: string, used: string): list<dict<any>>
  var pat = base != '' ? '^' .. escape(base, '~.*[]\^$') : ''
  var items: list<dict<any>> = []
  for p in get(f, 'params', [])
    if pat != '' && p.name !~? pat
      continue
    endif
    if used =~ $'\<{p.name}:'
      continue
    endif
    add(items, {
      word: $'{p.name}:',
      menu: '[param]',
      kind: 'p',
      info: ParamInfo(p),
    })
  endfor
  return items
enddef

# Last '.name' occurrence in `pre`: [name, startIdx, endIdx] or ['', -1, -1].
def LastCall(pre: string): list<any>
  var best = ['', -1, -1]
  var pos = 0
  while true
    var r = matchstrpos(pre, '\.\h\w*', pos)
    if r[1] < 0
      break
    endif
    best = [matchstr(r[0], '\.\zs\h\w*'), r[1], r[2]]
    pos = r[2]
  endwhile
  return best
enddef

# Whether the completion context is a function name: the word being typed
# directly follows '.' (or a '::' chain), and the '.' is not glued to a
# preceding word (which would be prose like "end.", not a call).
def AfterDot(pre: string): bool
  if pre =~ '\.$'
    return len(pre) == 1 || pre[-2] !~ '\w'
  endif
  if pre =~ '::$'
    return len(pre) == 2 || pre[-3] !~ '\w'
  endif
  return false
enddef

# omnifunc: complete function names after '.' and parameter names inside a
# call's argument region.
export def Omni(findstart: number, base: string): any
  var line = getline('.')
  var col = col('.') - 1
  var before = strpart(line, 0, col)

  if findstart == 1
    var wstart = match(before, '\w*$')
    var pre0 = strpart(before, 0, wstart)
    if AfterDot(pre0) || pre0 =~ '\.\h\w'
      return wstart
    endif
    return -1
  endif

  if !quarkdown#data#Loaded()
    return []
  endif
  var wordStart = len(before) - len(base)
  var pre = strpart(before, 0, wordStart)

  if AfterDot(pre)
    return FuncItems(base)
  endif

  var call = LastCall(pre)
  if call[1] < 0
    return []
  endif
  var f = quarkdown#data#Find(call[0])
  if empty(f)
    return []
  endif
  return ParamItems(f, base, strpart(pre, call[1]))
enddef

# Whether the syntax under the cursor is code or math, where quarkdown
# function syntax does not apply (see syntax/quarkdown.vim).
def InCode(): bool
  var gname = synIDattr(synID(line('.'), col('.') - 1, 1), 'name')
  return gname =~? 'code\|math'
enddef

# Auto-popup, called from insert-mode mappings right after '.' or '{' is
# typed (ftplugin installs them only when no LSP client is active).
#   kind 'func':  '.' was just typed and starts a function call
#   kind 'param': '{' was just typed right after a call's name
export def Auto(kind: string)
  if !quarkdown#Enabled('quarkdown_complete_auto') || pumvisible() || InCode()
    return
  endif
  if !quarkdown#data#Loaded()
    return
  endif
  var line = getline('.')
  var col = col('.') - 1
  var before = strpart(line, 0, col)
  var start = match(before, '\w*$')
  var base = strpart(before, start)
  var pre = strpart(before, 0, start)

  var ok = false
  if kind ==# 'func'
    ok = AfterDot(pre)
  elseif kind ==# 'param'
    # '{' just typed directly after .funcname (modulo blanks)
    ok = substitute(pre, '[{ ]$', '', '') =~ '\.\h\w*\s*$'
  endif
  if !ok
    return
  endif
  var items = Omni(0, base)
  if !empty(items)
    complete(start + 1, items)
  endif
enddef
