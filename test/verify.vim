vim9script
var log = 'D:/PARA/1.Project/vim-quarkdown/test/probe-out.txt'
var out1: list<string> = []
var out2: list<string> = []
var d1 = false
var d2 = false
writefile(['PROBE: testing env propagation'], log)
# 1: via job env: option
job_start(['cmd.exe', '/c', 'echo', 'OPT=[%JAVA_TOOL_OPTIONS%]'], {
  env: {JAVA_TOOL_OPTIONS: '-Dfile.encoding=UTF-8'},
  out_cb: (ch: channel, msg: string) => add(out1, msg),
  exit_cb: (j: job, code: number) => d1 = true,
})
# 2: via global setenv
setenv('JAVA_TOOL_OPTIONS', '-Dfile.encoding=UTF-8')
job_start(['cmd.exe', '/c', 'echo', 'OPT=[%JAVA_TOOL_OPTIONS%]'], {
  out_cb: (ch: channel, msg: string) => add(out2, msg),
  exit_cb: (j: job, code: number) => d2 = true,
})
var w = 0
while (!d1 || !d2) && w < 15
  sleep 500m
  w += 1
endwhile
writefile(['env-option saw: ' .. join(out1, ' | ')], log, 'a')
writefile(['setenv saw:     ' .. join(out2, ' | ')], log, 'a')
setenv('JAVA_TOOL_OPTIONS', v:null)
qa!
