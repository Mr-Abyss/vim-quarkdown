vim9script
# vim-quarkdown: org-style multi-state todo tracking.
# Three flavors over one state table:
#   \qx  markdown checkbox   `- text` -> `- [ ] text` -> `- [x] text`
#   \qX  comment sticky note `text` -> `<!-- TODO: text -->` (never renders)
#   \qh  heading mission     `## Intro` -> `## Intro <!-- TODO -->` (never
#       renders; the draft compiles straight to a publishable document)
# States cycle through g:quarkdown_todo_states, org's pipe convention:
# states after the '|' count as done.

# Parse the state table into [open, done]. A missing pipe treats the last
# state as done; the pipe itself never becomes a state.
def Table(): list<list<string>>
  var raw: list<string> = get(g:, 'quarkdown_todo_states',
    ['TODO', 'WORKING', 'PENDING', '|', 'DONE'])
  var t: list<list<string>> = [[], []]
  var side = 0
  for s in raw
    if s ==# '|'
      side = 1
    elseif !empty(s)
      t[side]->add(s)
    endif
  endfor
  if side == 0 && !empty(t[0])
    add(t[1], remove(t[0], -1))
  endif
  return t
enddef

export def AllStates(): list<string>
  var t = Table()
  return t[0] + t[1]
enddef

export def IsDone(state: string): bool
  return index(Table()[1], state) >= 0
enddef

def NextState(cur: string): string
  var all = AllStates()
  return all[(index(all, cur) + 1) % len(all)]
enddef

# Opener of a state comment: '<!-- KEYWORD', optional (note) and ':'.
# The keyword alternation is a CAPTURING group: matchlist()[1] is how the
# callers read back which state matched.
def NotePattern(): string
  return '<!--\s*\(' .. join(AllStates(), '\|') .. '\)\%(([^)]*)\)\?\s*:\?'
enddef

# --- \qx: markdown checkbox flavor ----------------------------------------

export def CycleMarkdown()
  var text = getline('.')
  if text =~# '^\s*#'
    echo 'Quarkdown: heading line - \qah cycles heading mission states'
    return
  endif
  if text =~# '^\s*[-*+]\s\+\[[xX]\]'
    setline('.', substitute(text, '^\(\s*[-*+]\s\+\)\[[xX]\]', '\1[ ]', ''))
  elseif text =~# '^\s*[-*+]\s\+\[ \]'
    setline('.', substitute(text, '^\(\s*[-*+]\s\+\)\[ \]', '\1[x]', ''))
  elseif text =~# '^\s*[-*+]\s\+'
    setline('.', substitute(text, '^\(\s*[-*+]\s\+\)', '\1[ ] ', ''))
  elseif trim(text) ==# ''
    echo 'Quarkdown: empty line'
  else
    setline('.', matchstr(text, '^\s*') .. '- [ ] ' .. trim(text))
  endif
enddef

# --- \qX: comment sticky note flavor --------------------------------------

export def CycleNote()
  var text = getline('.')
  var m = matchlist(text, NotePattern())
  if !empty(m) && m[1] !=# ''
    setline('.', substitute(text, '<!--\s*' .. m[1], '<!-- ' .. NextState(m[1]), ''))
  elseif text =~# '<!--'
    echo 'Quarkdown: comment without a todo state, not wrapping'
  elseif trim(text) ==# ''
    echo 'Quarkdown: empty line'
  else
    setline('.', $'<!-- {AllStates()[0]}: {trim(text)} -->')
  endif
enddef

# --- \qh: heading mission state flavor ------------------------------------

export def CycleHeading()
  var text = getline('.')
  if text !~# '^\s*#'
    echo 'Quarkdown: not a heading line - \qah cycles heading mission states'
    return
  endif
  var m = matchlist(text, NotePattern() .. '\s*-->\s*$')
  if !empty(m) && m[1] !=# ''
    setline('.', substitute(text,
      '<!--\s*' .. m[1] .. '\s*-->\s*$', '<!-- ' .. NextState(m[1]) .. ' -->', ''))
  else
    setline('.', substitute(text, '\s*$', '', '') .. ' <!-- ' .. AllStates()[0] .. ' -->')
  endif
enddef

# --- \qj / \qk: step the todo under the cursor -----------------------------

# Move any flavor's state forward (dir = true) or backward by v:count1
# steps, wrapping at both table ends. Checkboxes are binary: forward
# checks, backward unchecks.
export def Shift(forward: bool)
  var text = getline('.')
  if text =~# '^\s*[-*+]\s\+\[[xX ]\]'
    var want = forward ? '[x]' : '[ ]'
    var have = forward ? '\[[xX]\]' : '\[ \]'
    if text =~# have
      return
    endif
    setline('.', substitute(text, '\[[xX ]\]', want, ''))
    return
  endif
  var e = EntryFor(text)
  if empty(e)
    echo 'Quarkdown: no todo under cursor'
    return
  endif
  var all = AllStates()
  var idx = (index(all, e.state) + (forward ? v:count1 : -v:count1)) % len(all)
  if idx < 0
    idx += len(all)
  endif
  setline('.', substitute(text, '<!--\s*' .. e.state, '<!-- ' .. all[idx], ''))
enddef

# --- \qT: the agenda -------------------------------------------------------

# State + label carried by a line; {} when the line holds no todo.
def EntryFor(text: string): dict<any>
  if text =~# '^\s*[-*+]\s\+\[[xX ]\]'
    var box = matchstr(text, '\[[xX ]\]')
    var state = box =~# '[xX]' ? Table()[1][-1] : AllStates()[0]
    return {state: state,
      label: trim(substitute(text, '^\s*[-*+]\s\+\[.\]\s*', '', ''))}
  endif
  var m = matchlist(text, NotePattern())
  if empty(m) || m[1] ==# ''
    return {}
  endif
  var label: string
  if text =~# '^\s*#'
    label = trim(substitute(text, '\s*<!--\s*.*$', '', ''))
  else
    label = trim(substitute(substitute(text, NotePattern(), '', ''), '-->\s*$', '', ''))
  endif
  return {state: m[1], label: label}
enddef

export def Agenda(filter = '')
  var want = toupper(trim(filter))
  var items: list<dict<any>> = []
  var lnum = 0
  for text in getline(1, '$')
    lnum += 1
    var e = EntryFor(text)
    if empty(e) || (want !=# '' && toupper(e.state) !=# want)
      continue
    endif
    add(items, {
      bufnr: bufnr(),
      lnum: lnum,
      text: $'[{e.state}]' .. (e.label ==# '' ? '' : $' {e.label}'),
    })
  endfor
  if empty(items)
    echo want ==# '' ? 'Quarkdown: no todos in this buffer'
      : $'Quarkdown: no {want} todos in this buffer'
    return
  endif
  setloclist(0, [], ' ', {title: 'Quarkdown Todos', items: items})
  exe 'vertical lopen 45'
  nnoremap <buffer> <silent> q :close<CR>
  # per-state tag colors in three visual tiers: the state you are IN is
  # the loudest thing on screen (externalized working memory), todo is
  # ordinary, waiting/done fade. matchadd highlights over the qf window's
  # own syntax and is deterministic headless; the window is reused across
  # calls, so clear stale matches first.
  clearmatches()
  for s in AllStates()
    matchadd(AgendaGroup(s), '\[' .. escape(s, '\^$.*[]~') .. '\]')
  endfor
enddef

# Visual tier of a state in the agenda, from its name: working-ish ->
# loud, todo-ish/unknown -> mid, waiting/done-ish -> low.
def AgendaGroup(state: string): string
  var s = toupper(state)
  if s =~# '^\%(WORKING\|WIP\|DOING\|ACTIVE\|NOW\|CURRENT\)'
    return 'qdAgendaLoud'
  endif
  if s =~# '^\%(PENDING\|WAITING\|BLOCKED\|HOLD\|SOMEDAY\|DONE\|CANCEL\|DROP\)'
    return 'qdAgendaLow'
  endif
  return 'qdAgendaMid'
enddef
