" Vim syntax file
" Language:	Quarkdown (.qd)
" Maintainer:	vim-quarkdown <https://github.com/Mr-Abyss/vim-quarkdown>
" Last Change:	2026-10-18
"
" Quarkdown is a Markdown superset: start from the runtime Markdown syntax,
" then layer Quarkdown-specific constructs on top.

if exists("b:current_syntax")
  finish
endif

if !exists("g:main_syntax")
  let g:main_syntax = "quarkdown"
endif

runtime! syntax/markdown.vim
unlet! b:current_syntax

syn sync minlines=100

" Highlight groups that must never contain Quarkdown function syntax:
"   markdownCode / markdownCodeBlock: inline and fenced code
"   qdMathBlock / qdMathInline:       TeX math, left untouched

" TeX math block:  $$$ ... $$$
syn region qdMathBlock matchgroup=qdMathDelim start=/^\s*\$\$\$/ end=/^\s*\$\$\$/ keepend

" Inline math: $ ... $ with whitespace (or line edge) around both delimiters.
syn region qdMathInline matchgroup=qdMathDelim
      \ start=/\(^\|\s\)\@<=\$\S\@=/ end=/\S\@<=\$\ze\(\s\|$\)/ oneline
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock,qdMathBlock

" Decorative heading: #! ... ######!  (excluded from numbering and TOC)
syn region qdDecoHeading start=/^\s*\zs#\{1,6}!/ end=/$/ oneline
      \ contains=@markdownInline
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock

" Function call arguments {…}; self-nesting for nested calls like
" .sum {.pow {3} {2}} {2}
syn region qdBraces matchgroup=qdBraceDelim start=/{/ end=/}/
      \ contains=qdBraces,qdFuncName,qdChain,qdNamedArg,qdNumber
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock,qdMathBlock,qdMathInline

" Function/variable call: .name — not when the dot is escaped as \.
syn match qdFuncName /\\\@<!\.[A-Za-z_][A-Za-z0-9_]*[?!]\=/
      \ contains=@NoSpell
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock,qdMathBlock,qdMathInline

" Chain operator:  .pow {3} {2}::subtract {1}
syn match qdChain /::/
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock,qdMathBlock,qdMathInline

" Named argument:  by:{3}  (name only, inside braces)
syn match qdNamedArg /\k\+\ze:{/ containedin=qdBraces

" Numbers inside arguments
syn match qdNumber /\d\+\%(\.\d\+\)\=/ containedin=qdBraces

" Line continuation backslash at end of line
syn match qdLineCont /\\\ze\s*$/
      \ containedin=ALLBUT,markdownCode,markdownCodeBlock,qdMathBlock,qdMathInline

hi def link qdFuncName	Function
hi def link qdChain	Operator
hi def link qdBraceDelim	Delimiter
hi def link qdNamedArg	Label
hi def link qdNumber	Number
hi def link qdMathDelim	Special
hi def link qdMathBlock	String
hi def link qdMathInline	String
hi def link qdDecoHeading	Title
hi def link qdLineCont	SpecialKey

let b:current_syntax = "quarkdown"

if g:main_syntax ==# 'quarkdown'
  unlet g:main_syntax
endif
