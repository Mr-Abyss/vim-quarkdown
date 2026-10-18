vim9script
# vim-quarkdown: table of contents and compilation.
# Requires Vim 9.0+ (vim9script).

# State of the last/running compilation.
var state: dict<any> = {
  job: null_job,
  running: false,
  code: -1,
  out: [],
  err: [],
  src: '',
}

def Compiler(): string
  return get(g:, 'quarkdown_compiler', 'quarkdown')
enddef

def BuildCmd(src: string, extra: list<string>): list<string>
  var cmd: list<string> = [Compiler(), 'c', src]
  if get(g:, 'quarkdown_compile_strict', 1)
    cmd += ['--strict']
  endif
  cmd += copy(extra)
  cmd += copy(get(g:, 'quarkdown_compile_opts', []))
  return cmd
enddef

def ShellQuote(s: string): string
  if has('win32') && !has('unix')
    return '"' .. substitute(s, '"', '""', 'g') .. '"'
  endif
  return "'" .. substitute(s, "'", "'\\''", 'g') .. "'"
enddef

# Drop Java stack-trace lines ('at com.quarkdown...') and blanks from the
# compiler output, keeping the actual error messages.
def FilterErrors(lines: list<string>): list<string>
  return copy(lines)->filter((_, l: string): bool => l !~ '^\s*at ' && l !~ '^\s*$')
enddef

def Finish(code: number, lines: list<string>): dict<any>
  var errs: list<string> = empty(lines) ? state.err : lines
  errs = FilterErrors(errs)
  state.running = false
  state.code = code
  if code != 0
    var items: list<dict<any>> = []
    for l in errs
      add(items, {filename: state.src, lnum: 0, text: l})
    endfor
    setqflist([], ' ', {
      title: $'quarkdown: {fnamemodify(state.src, ":t")} failed (exit {code})',
      items: items,
    })
    copen
    echo $'Quarkdown: compilation FAILED (exit {code}), see quickfix'
  else
    echo 'Quarkdown: compiled successfully'
  endif
  return {ok: code == 0, code: code}
enddef

# Collect ATX headings of a buffer.
# Returns a list of {level, deco, text, lnum} entries. Decorative headings
# (`#!`, `##!`, …) carry deco = true.
export def CollectHeadings(buf: number): list<dict<any>>
  var result: list<dict<any>> = []
  var lnum = 0
  for line in getbufline(buf, 1, '$')
    lnum += 1
    var m = matchlist(line, '^\s*\(#\{1,6}\)\(!\?\)\s\+\(.\{-}\)\s*#\{-}\s*$')
    if empty(m)
      continue
    endif
    add(result, {
      level: strlen(m[1]),
      deco: m[2] ==# '!',
      text: m[3],
      lnum: lnum,
    })
  endfor
  return result
enddef

# Open a vertical location-list window with the headings of the current
# buffer. Press <CR> on an entry to jump to it.
export def Toc()
  var entries = CollectHeadings(bufnr())
  if empty(entries)
    echo 'Quarkdown: no headings found in this buffer'
    return
  endif
  var items: list<dict<any>> = map(entries, (_, e: dict<any>): dict<any> => ({
    bufnr: bufnr(),
    lnum: e.lnum,
    text: repeat('  ', e.level - 1) .. (e.deco ? '~ ' : '') .. e.text,
  }))
  setloclist(0, [], ' ', {title: 'Quarkdown TOC', items: items})
  exe 'vertical lopen 35'
enddef

# Compile the current buffer with the quarkdown CLI.
#   sync:  true = blocking; false = background job
#   extra: extra CLI arguments, e.g. ['-o', 'build'] or ['--pdf']
# Returns {ok, code}; async also sets started = true on successful launch.
export def Compile(sync: bool, extra: list<string>): dict<any>
  if state.running
    echoerr 'Quarkdown: a compilation is already in progress'
    return {ok: false, code: -1}
  endif

  var src = expand('%:p')
  if src ==# ''
    echoerr 'Quarkdown: current buffer has no file name'
    return {ok: false, code: -1}
  endif
  if &modified
    silent update
  endif

  var cmd = BuildCmd(src, extra)
  if !executable(cmd[0])
    echoerr $'Quarkdown: compiler ''{cmd[0]}'' not executable (set g:quarkdown_compiler)'
    return {ok: false, code: -1}
  endif

  state.src = src

  if sync
    var quoted = join(map(copy(cmd), (_, v: string): string => ShellQuote(v)), ' ')
    var out = system(quoted .. ' 2>&1')
    return Finish(v:shell_error, split(out, '\n'))
  endif

  state.out = []
  state.err = []
  state.code = -1
  state.running = true
  state.job = job_start(cmd, {
    cwd: fnamemodify(src, ':h'),
    out_cb: (ch: channel, msg: string) => add(state.out, msg),
    err_cb: (ch: channel, msg: string) => add(state.err, msg),
    exit_cb: (job: job, code: number) => Finish(code, []),
  })
  if job_status(state.job) !=# 'run'
    state.running = false
    echoerr 'Quarkdown: failed to start the compiler job'
    return {ok: false, code: -1}
  endif
  echo $'Quarkdown: compiling {fnamemodify(src, ":t")} in background...'
  return {ok: true, code: -1, started: true}
enddef

# Whether a background compilation is still running.
export def Running(): bool
  return state.running
enddef

# Result of the most recent finished compilation ({ok, code}).
export def LastResult(): dict<any>
  return {ok: state.code == 0, code: state.code}
enddef
