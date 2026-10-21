vim9script
# vim-quarkdown: buffer-local settings and commands for Quarkdown files.

if exists("b:did_quarkdown_ftplugin")
  finish
endif
b:did_quarkdown_ftplugin = 1

setl commentstring=<!--%s-->
setl comments=s:<!--,m:\ \ \ \ ,e:-->
setl matchpairs+={:}

command -buffer QuarkdownToc call quarkdown#Toc()
command -buffer -bang -nargs=* QuarkdownCompile call quarkdown#Compile(<bang>0, [<f-args>])
command -buffer QuarkdownOpen call quarkdown#Open()
command -buffer -nargs=* QuarkdownPreview call quarkdown#Preview([<f-args>])
command -buffer QuarkdownStop call quarkdown#Stop()
