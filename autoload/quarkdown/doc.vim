vim9script
# vim-quarkdown: :QuarkdownDoc — popup documentation for stdlib functions,
# from the bundled catalogue (data/stdlib.json; works offline, no LSP
# client needed). For live hover over user-defined functions, use your LSP
# client's own hover (coc: K, ale: :ALEHover, vim-lsp: :LspHover).

# Render one catalogue entry into popup lines: title, signature, then the
# markdown documentation flattened to plain text.
export def Lines(f: dict<any>): list<string>
  var out: list<string> = []
  var name = get(f, 'name', '?')
  var module = get(f, 'module', '')
  add(out, module != '' ? $'{name}  [{module}]' : name)
  add(out, repeat('-', 46))

  var sigparts = split(get(f, 'signature', ''), "\n")
  var sig = join(map(sigparts, (_, v: string): string => trim(substitute(v, '\\$', '', ''))), ' ')
  if sig != ''
    add(out, sig)
    add(out, '')
  endif

  # wiki link, extracted before [text](url) pairs are flattened
  var wiki = matchstr(get(f, 'doc', ''), 'https://quarkdown\.com/wiki/\S\+')

  var inExample = false
  for raw in split(get(f, 'doc', ''), "\n")
    var l = raw
    if l =~ '^\s*```'
      inExample = !inExample
      if inExample
        add(out, '')
      endif
      continue
    endif
    if l =~ '^#### '
      l = substitute(l, '^#### ', '', '')
      if l != ''
        l = toupper(l[0]) .. strpart(l, 1)
      endif
    endif
    if inExample
      l = '  ' .. l
    endif
    # [text](url) -> text
    l = substitute(l, '\[\([^]]*\)\]([^)]*)', '\1', 'g')
    add(out, l)
  endfor
  if wiki != ''
    add(out, '')
    add(out, $'Wiki: {wiki}')
  endif
  return out
enddef

def Filter(id: number, key: string): bool
  if index(['j', "\<C-E>", "\<Down>", "\<ScrollWheelDown>"], key) >= 0
    win_execute(id, "normal! \<C-E>")
    return true
  endif
  if index(['k', "\<C-Y>", "\<Up>", "\<ScrollWheelUp>"], key) >= 0
    win_execute(id, "normal! \<C-Y>")
    return true
  endif
  if key ==# 'd'
    win_execute(id, "normal! \<C-D>")
    return true
  endif
  if key ==# 'u'
    win_execute(id, "normal! \<C-U>")
    return true
  endif
  if index(['q', "\<Esc>", "\<CR>", "\<Space>"], key) >= 0
    popup_close(id)
    return true
  endif
  return false
enddef

# Show documentation for a function. Without an argument the word under the
# cursor is used (leading '.' / trailing ':' are stripped).
export def Show(name_arg: string)
  if !quarkdown#data#Loaded()
    echoerr 'Quarkdown: bundled stdlib catalogue (data/stdlib.json) missing or unreadable'
    return
  endif

  var name = name_arg
  if name == ''
    name = expand('<cword>')
  endif
  name = substitute(name, '^[.:]*', '', '')
  name = substitute(name, '[.:{}!]*$', '', '')
  if name == ''
    echo 'Usage: :QuarkdownDoc [function]'
    return
  endif

  var f = quarkdown#data#Find(name)
  if empty(f)
    for cand in quarkdown#data#Functions()
      if cand.name ==? name
        f = cand
        break
      endif
    endfor
  endif
  if empty(f)
    echo $'Quarkdown: no documentation for ''{name}'' in the bundled stdlib catalogue'
    return
  endif

  var id = popup_create(Lines(f), {
    line: 'cursor+1',
    col: 'cursor',
    pos: 'topleft',
    maxwidth: 72,
    minwidth: 40,
    maxheight: &lines - 6,
    border: [],
    padding: [0, 1, 0, 1],
    wrap: true,
    close: 'click',
    filter: (wid: number, key: string): bool => Filter(wid, key),
  })
  # title can only carry plain text; keep it short
  popup_setoptions(id, {title: $' {get(f, "name", "?")} - Quarkdown '})
enddef
