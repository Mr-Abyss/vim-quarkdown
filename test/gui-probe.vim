vim9script
writefile(['GUI PROBE START pid=' .. getpid()], 'D:/PARA/1.Project/vim-quarkdown/test/viewpdf-debug.log', 'a')
execute 'edit' fnameescape('D:/PARA/2.Area/claude_for_life/p.文物/上博藏青白釉注子温碗.qd')
try
  quarkdown#Compile(true, ['--pdf'])
  writefile(['GUI compile returned'], 'D:/PARA/1.Project/vim-quarkdown/test/viewpdf-debug.log', 'a')
catch
  writefile(['GUI compile CAUGHT: ' .. v:exception], 'D:/PARA/1.Project/vim-quarkdown/test/viewpdf-debug.log', 'a')
endtry
sleep 3s
qa!
