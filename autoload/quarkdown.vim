vim9script
# vim-quarkdown: table of contents, compilation, and preview.
# Requires Vim 9.0+ (vim9script).

# State of the last/running compilation and preview session.
var state: dict<any> = {
  job: null_job,          # compile job
  running: false,         # compile in flight
  code: -1,               # last compile exit code
  out: [],                # compile stdout lines
  err: [],                # compile stderr lines
  src: '',                # last compiled source (full path)
  lastOut: '',            # output document dir parsed from 'Success @'
  previewJob: null_job,   # preview webserver job
  previewPort: '',        # port the preview webserver listens on
}

def Compiler(): string
  return get(g:, 'quarkdown_compiler', 'quarkdown')
enddef

# Assemble the compile command line.
#   --strict by default (g:quarkdown_compile_strict = 0 to disable)
#   --timeout from g:quarkdown_compile_timeout (default 0 = disabled;
#     the CLI default of 30s is too short for large documents; -1 omits
#     the flag and restores the CLI default)
export def BuildCmd(src: string, extra: list<string>): list<string>
  var cmd: list<string> = [Compiler(), 'c', src]
  if get(g:, 'quarkdown_compile_strict', 1)
    cmd += ['--strict']
  endif
  var timeout = get(g:, 'quarkdown_compile_timeout', 0)
  if timeout >= 0
    cmd += ['--timeout', string(timeout)]
  endif
  cmd += copy(extra)
  cmd += copy(get(g:, 'quarkdown_compile_opts', []))
  return cmd
enddef

# Native Windows vim cannot CreateProcess a .cmd/.bat/sh wrapper, which is
# all quarkdown ships there; route through cmd.exe, which resolves PATHEXT.
# msys/Unix vim execs the shebang wrapper directly.
# NOTE: write the platform test as a single has(), never
# `has('win32') && !has('unix')` — that compound form is mis-constant-folded
# to true by the vim9 :def compiler on some builds (observed on msys vim
# 9.1.785), which would wrap msys argv in cmd.exe and hang the job.
# Also: keep the wrapper as plain `/c` — a `/c /d` prefix makes cmd.exe
# treat `/d` as the command to run and fail instantly.
def SpawnCmd(cmd: list<string>): list<string>
  if !has('unix')
    return ['cmd.exe', '/c'] + cmd
  endif
  return cmd
enddef

def ShellQuote(s: string): string
  # Same single-has() rule as SpawnCmd: compound has() conditions get
  # mis-folded by the vim9 compiler on some builds.
  if !has('unix')
    return '"' .. substitute(s, '"', '""', 'g') .. '"'
  endif
  return "'" .. substitute(s, "'", "'\\''", 'g') .. "'"
enddef

def StripAnsi(s: string): string
  return substitute(s, "\e\\[[0-9;]*m", '', 'g')
enddef

def CleanSys(s: string): string
  return trim(substitute(s, '[\r\n]', '', 'g'))
enddef

# The CLI prints native Windows paths (C:\...). msys vim cannot stat
# those, so convert via cygpath when available; otherwise just
# normalize backslashes.
def ToVimPath(p: string): string
  if has('unix') && p =~? '^\a:[/\\]' && executable('cygpath')
    var u = CleanSys(system('cygpath -u ' .. shellescape(p)))
    if v:shell_error == 0 && u !=# ''
      return u
    endif
  endif
  return substitute(p, '\', '/', 'g')
enddef

# Drop Java stack-trace lines ('at com.quarkdown...') and blanks from the
# compiler output, keeping the actual error messages.
def FilterErrors(lines: list<string>): list<string>
  return copy(lines)->filter((_, l: string): bool => l !~ '^\s*at ' && l !~ '^\s*$')
enddef

# Kill a job and (on Windows, native or msys) its whole process tree;
# killing the wrapper (cmd.exe / sh script) alone would orphan the JVM.
def KillJob(j: job)
  var pid = job_info(j).process
  if executable('taskkill') && pid > 0
    if has('unix')
      # msys vim: .process is the msys pid; taskkill wants the Windows pid.
      # \_^ (not ^) matches line starts inside the multi-line ps output.
      # Must run BEFORE job_stop(): killing the wrapper first makes the
      # ps row (and thus the mapping) disappear, orphaning the JVM.
      var winpid = matchstr(system('ps -W'), $'\v\_^\s*{pid}\s+\d+\s+\S+\s+\zs\d+')
      if winpid !=# ''
        pid = str2nr(winpid)
      endif
      # '//PID' spelling: msys converts '/PID' to a filesystem path.
      silent system($'taskkill //PID {pid} //T //F')
    else
      silent system($'taskkill /PID {pid} /T /F')
    endif
  endif
  job_stop(j, 'kill')
enddef

def Finish(code: number, lines: list<string>): dict<any>
  var src_lines: list<string> = empty(lines) ? state.out : lines
  var errs: list<string> = empty(lines) ? state.err : lines
  errs = FilterErrors(errs)
  state.running = false
  state.code = code
  state.lastOut = ''
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
    for l in src_lines
      var path = matchstr(StripAnsi(l), 'Success @ \zs.*\ze\s*$')
      if path !=# ''
        state.lastOut = ToVimPath(path)
        echo $'Quarkdown: compiled successfully -> {state.lastOut}'
        break
      endif
    endfor
    if state.lastOut ==# ''
      echo 'Quarkdown: compiled successfully'
    endif
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
  var dir = fnamemodify(src, ':h')

  if sync
    # system() inherits vim's cwd; chdir to the file's directory so the
    # output lands beside the document, exactly like the async path.
    var wd = getcwd()
    try
      chdir(dir)
      var quoted = join(map(copy(cmd), (_, v: string): string => ShellQuote(v)), ' ')
      var out = system(quoted .. ' 2>&1')
      return Finish(v:shell_error, split(out, '\n'))
    finally
      chdir(wd)
    endtry
  endif

  state.out = []
  state.err = []
  state.code = -1
  state.running = true
  state.job = job_start(SpawnCmd(cmd), {
    cwd: dir,
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

# Kill whatever process listens on a local port (Windows: netstat gives
# the real Windows PID, so no msys-pid mapping is needed). Used for the
# preview server, whose wrapper pid chain is unreliable to walk.
def KillByPort(port: string)
  if port !~ '^\d\+$' || !executable('taskkill') || !executable('netstat')
    return
  endif
  var out = system($'netstat -ano | grep ":{port}"')
  var pids: dict<number> = {}
  for line in split(out, '\n')
    var winpid = trim(split(line, '\s\+')[-1])
    if winpid =~ '^\d\+$' && str2nr(winpid) > 0
      pids[winpid] = 1
    endif
  endfor
  for winpid in keys(pids)
    if has('unix')
      # '//PID': msys converts a '/PID' argument into a filesystem path
      silent system($'taskkill //PID {winpid} //T //F')
    else
      silent system($'taskkill /PID {winpid} /T /F')
    endif
  endfor
enddef

def OnPreviewExit(j: job, code: number)
  state.previewJob = null_job
  state.previewPort = ''
  echo $'Quarkdown: preview server exited (code {code})'
enddef

# Start a live-preview webserver for the current buffer (quarkdown -p).
# The CLI starts the webserver and opens the document in the browser.
# The server job is tied to the vim session (not detached) and can be
# stopped with :QuarkdownStop. Pass-through args, e.g.:
#   :QuarkdownPreview -w                " watch + recompile (live preview)
#   :QuarkdownPreview --server-port 9090
export def Preview(extra: list<string>): dict<any>
  if job_status(state.previewJob) ==# 'run'
    echo 'Quarkdown: preview already running (:QuarkdownStop to stop it)'
    return {ok: true, code: -1, started: false}
  endif

  var src = expand('%:p')
  if src ==# ''
    echoerr 'Quarkdown: current buffer has no file name'
    return {ok: false, code: -1}
  endif
  if &modified
    silent update
  endif

  var cmd: list<string> = [Compiler(), 'c', src, '-p', '--timeout', '0']
  cmd += copy(extra)
  cmd += copy(get(g:, 'quarkdown_compile_opts', []))
  if !executable(cmd[0])
    echoerr $'Quarkdown: compiler ''{cmd[0]}'' not executable (set g:quarkdown_compiler)'
    return {ok: false, code: -1}
  endif

  # remember the port so Stop() can kill the server by port
  state.previewPort = '8089'
  var pi = index(cmd, '--server-port')
  if pi >= 0 && pi + 1 < len(cmd) && cmd[pi + 1] =~ '^\d\+$'
    state.previewPort = cmd[pi + 1]
  endif

  state.previewJob = job_start(SpawnCmd(cmd), {
    cwd: fnamemodify(src, ':h'),
    out_cb: (ch: channel, msg: string) => add(state.out, msg),
    err_cb: (ch: channel, msg: string) => add(state.err, msg),
    exit_cb: (j: job, code: number) => OnPreviewExit(j, code),
  })
  if job_status(state.previewJob) !=# 'run'
    state.previewJob = null_job
    echoerr 'Quarkdown: failed to start the preview job'
    return {ok: false, code: -1}
  endif
  echo 'Quarkdown: preview server starting (a browser tab should open; :QuarkdownStop stops it)'
  return {ok: true, code: -1, started: true}
enddef

# Kill the running compile job and/or preview server.
export def Stop()
  var what = ''
  if state.running && job_status(state.job) ==# 'run'
    KillJob(state.job)
    state.running = false
    what ..= 'compile '
  endif
  if job_status(state.previewJob) ==# 'run' || state.previewPort !=# ''
    KillJob(state.previewJob)
    KillByPort(state.previewPort)
    state.previewPort = ''
    what ..= 'preview '
  endif
  echo what ==# '' ? 'Quarkdown: nothing to stop' : $'Quarkdown: stopped {what}'
enddef

# Open the last compiled document (index.html) in the default browser.
export def Open()
  if state.lastOut ==# ''
    echoerr 'Quarkdown: nothing compiled yet in this session'
    return
  endif
  var idx = state.lastOut .. '/index.html'
  if !filereadable(idx)
    echoerr $'Quarkdown: {idx} not found'
    return
  endif
  if has('win32')
    silent execute '!explorer.exe ' .. shellescape(substitute(idx, '/', '\\', 'g'))
  elseif executable('cygpath')
    # msys vim on Windows: hand explorer a native path
    var w = CleanSys(system('cygpath -w ' .. shellescape(idx)))
    silent execute '!explorer.exe ' .. shellescape(w)
  elseif has('mac')
    silent execute '!open ' .. shellescape(idx)
  else
    silent execute '!xdg-open ' .. shellescape(idx)
  endif
enddef

# Whether a background compilation is still running.
export def Running(): bool
  return state.running
enddef

# Whether the preview server is running.
export def PreviewRunning(): bool
  return job_status(state.previewJob) ==# 'run'
enddef

# Result of the most recent finished compilation ({ok, code}).
export def LastResult(): dict<any>
  return {ok: state.code == 0, code: state.code}
enddef

# Output document directory of the last successful compile ('' if none).
export def LastOut(): string
  return state.lastOut
enddef
