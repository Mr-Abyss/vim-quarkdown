# Vim-quarkdown: Unofficial vim extension for quarkdown

## Design Philosophy

For vim users who want a bit of quarkdown convenience.

## Requirements

- Vim 9.0+ (vim9script). Works in plain terminal Vim; no Neovim, no `+python`
  needed — everything is pure vim9script.
- The [quarkdown](https://quarkdown.com) CLI on your `$PATH` (only for
  compilation; syntax highlighting and the TOC work without it). On native
  Windows, if `quarkdown` is not found, set the full path in
  `g:quarkdown_compiler`.

## Installation

Use your favorite plugin manager, e.g. with vim-plug:

```vim
Plug 'Mr-Abyss/vim-quarkdown'
```

## Usage

Open any `*.qd` file. The filetype `quarkdown` is detected automatically.

### Syntax highlighting

Markdown highlighting (from Vim's runtime) plus Quarkdown constructs:

- Function/variable calls `.name` and chained calls `::`
- Call arguments `{…}` with proper nesting, named arguments `name:{…}`, numbers
- Decorative headings `#!`, `##!`, …
- Math blocks `$$$ … $$$` and inline `$ … $`
- Line-continuation backslashes

Function syntax is intentionally *not* highlighted inside fenced/inline code
and math blocks.

### In-file table of contents

```
:QuarkdownToc
```

Opens a vertical location-list window with all headings of the current buffer,
indented by level (`~ ` marks decorative headings). Press `<CR>` on an entry to
jump to it, `q` to close.

### Compiling

```
:QuarkdownCompile          " compile in the background (async job)
:QuarkdownCompile!         " compile synchronously
:QuarkdownCompile --pdf    " extra CLI arguments are passed through
```

Compiles the current buffer with `quarkdown c <file> --strict` (the buffer is
saved first if modified). The output always lands beside the document, in
`quarkdown-output/<document-name>/index.html`, regardless of vim's working
directory. On success the output path is echoed; on failure the error output
(with Java stack traces filtered out) is placed in the quickfix list and the
quickfix window is opened.

```
:QuarkdownOpen             " open the last compiled document in your browser
:QuarkdownStop             " kill a running compile job and/or preview server
```

Options:

| Variable                     | Default        | Meaning                                              |
|------------------------------|----------------|------------------------------------------------------|
| `g:quarkdown_compiler`       | `'quarkdown'`  | Compiler command or full path                        |
| `g:quarkdown_compile_opts`   | `[]`           | Extra arguments appended to every compilation        |
| `g:quarkdown_compile_strict` | `1`            | Pass `--strict` so errors surface in the quickfix    |
| `g:quarkdown_compile_timeout`| `0` (disabled) | Seconds passed as `--timeout`; the CLI default of 30s is too short for large documents. `-1` omits the flag |

### Live preview

```
:QuarkdownPreview           " compile + start the preview webserver (-p)
:QuarkdownPreview -w        " ...and recompile on every change (live preview)
:QuarkdownPreview --server-port 9090
```

The CLI starts a local webserver and opens the document in your browser; the
server dies with the vim session, or run `:QuarkdownStop` to stop it early
(on Windows the whole process tree is terminated, so no JVM is orphaned).

Mappings are provided as `<Plug>(quarkdown-toc)`, `<Plug>(quarkdown-compile)`,
`<Plug>(quarkdown-compile-sync)`, `<Plug>(quarkdown-open)` and
`<Plug>(quarkdown-preview)`; map them yourself, e.g.

```vim
map <localleader>qt <Plug>(quarkdown-toc)
map <localleader>qc <Plug>(quarkdown-compile)
map <localleader>qp <Plug>(quarkdown-preview)
```

### Windows notes

On Windows quarkdown ships only `.cmd`/`.bat`/sh wrapper scripts (no `.exe`),
which vim's async `job_start()` cannot execute directly. The plugin routes
the command through `cmd.exe /c` automatically on native Windows Vim and
executes the sh wrapper directly on MSYS/Git-Bash Vim — both are tested.

## Tests

From the repository root:

```sh
vim -es -Nu NONE -U NONE --not-a-term -S test/run.vim; echo "exit=$?"
```

Compilation tests are skipped automatically when the `quarkdown` CLI is not
executable. Details land in `test/last-result.txt`.

## Roadmap

### Phase 1

[x] simple syntax highlighting

[x] In-file Toc

[x] compiling

### Phase 2: Minor Advances

[] mirror most of quarkdown-VScode's features

[] advanced syntax highlighting

[] vimtex-style advanced motions

[] vimtex-style advanced mappings

### Phase 3: Major Revisions

[] advanced previewing (akin to many vim-markdown plugins, sadly many of them seem under-maintained)

### What Will Not Be Implemented (for now)

These functionalities can be outsourced to other, more professional plugins.

[x] linting and syntax checking
 * [ale](https://github.com/w0rp/ale)
 * [neomake](https://github.com/neomake/neomake)
 * [syntastic](https://github.com/vim-syntastic/syntastic)

[x] Snippets and templates

 * [UltiSnips](https://github.com/SirVer/ultisnips)
 * [neosnippet](https://github.com/Shougo/neosnippet.vim)

[x] Tag navigation

 * [vim-gutentags](https://github.com/ludovicchabant/vim-gutentags)

## Acknowledgements

[vim-markdown](https://github.com/preservim/vim-markdown) and [vimtex](https://github.com/lervag/vimtex) for inspiration of what features are welcome.
[quarkdown](https://github.com/iamgio/quarkdown) itself, of course! And the official [LSP](https://github.com/iamgio/quarkdown/tree/main/quarkdown-lsp).

