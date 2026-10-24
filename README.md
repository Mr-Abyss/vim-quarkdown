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
- For completion, documentation and diagnostics: quarkdown **v1.9.0+**
  (v2.x recommended), which ships the language server
  (`quarkdown language-server`). No LSP client is presupposed — see
  [LSP integration](#lsp-integration-ale-vim-lsp-coc).

## Installation

Use your favorite plugin manager, e.g. with vim-plug:

```vim
Plug 'Mr-Abyss/vim-quarkdown'
```

## Usage

Open any `*.qd` file. The filetype `quarkdown` is detected automatically.

The full manual lives inside Vim: `:h vim-quarkdown` (after a manual
install, run `:helptags ALL` once if the tag is not found; plugin
managers generate it automatically).

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

### Folding and heading motions

Quarkdown buffers fold by heading: each `#`…`######` heading (decorative `#!`
ones included) starts a fold of its level, nested by heading level; the
preamble above the first heading stays unfolded. Folds start open — `zM`
closes all, `za` toggles the one under the cursor. Set
`g:quarkdown_folding = 0` to keep your own `'foldmethod'`.

`[[` and `]]` jump to the previous / next heading, in normal and visual mode
(the selection extends) and as operator targets (`d]]` deletes up to the next
heading; the heading line survives). Silent, no wrap at the buffer edges.

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
(on Windows the listener is killed by its port, so no JVM is orphaned).

### Default mappings

Quarkdown buffers ship a handful of default mappings (`g:quarkdown_mappings = 0`
disables them all):

| Keys                | Action                                 |
|---------------------|----------------------------------------|
| `<LocalLeader>qt`   | table of contents                      |
| `<LocalLeader>qcc`  | compile (async)                        |
| `<LocalLeader>qcs`  | compile synchronously                  |
| `<LocalLeader>qcp`  | compile to PDF                         |
| `<LocalLeader>qo`   | open the last output in the browser    |
| `<LocalLeader>qp`   | start the preview server               |
| `<LocalLeader>qw`   | preview with live recompile on changes |
| `<LocalLeader>qs`   | stop compile job / preview server      |
| `<LocalLeader>qd`   | docs for the word under the cursor     |
| `]]` / `[[`         | next / previous heading                |

Everything also exists as a global `<Plug>(quarkdown-…)` mapping for custom
keys: toc, compile, compile-sync, compile-pdf, open, preview, preview-watch,
stop, doc, next-heading, prev-heading.

### Completions

What you get depends on whether an LSP client is attached (see next section):

- **With a client** (coc, ale or vim-lsp): completions come from the live
  language server — stdlib *and* user-defined function names, parameter
  names, and type-aware parameter *values* (e.g. inside `.row {…}` it
  suggests valid `alignment` values). `&omnifunc` is pointed at the client
  (coc drives its own popup).
- **Without any client**: an offline omnifunc built from a bundled stdlib
  catalogue (`data/stdlib.json`, 164 functions with signatures and docs)
  completes function names after `.` / `::` and parameter names inside a
  call (`C-x C-o`). Already-supplied named parameters are skipped. On top,
  a completion popup opens automatically right after you type `.` or `{`
  before a call (`g:quarkdown_complete_auto = 0` disables it; it is never
  installed when an LSP client is active).

Offline limitations (use an LSP client for these): enum *value* completion,
completions for user-defined functions, `data/stdlib.json` must be
regenerated with `scripts/gen-stdlib-data.js` when quarkdown adds functions.

### Documentation

```
:QuarkdownDoc             " docs for the function name under the cursor
:QuarkdownDoc container   " docs for a specific function
```

Opens a scrollable popup (`j`/`k`/`d`/`u`, `q` to close) with the
signature, parameters and rendered documentation from the bundled catalogue
— works fully offline. For live hover over *user-defined* functions, use
your LSP client's own hover (coc: `K`, ale: `:ALEHover`, vim-lsp:
`:LspHover`).

### LSP integration (ale, vim-lsp, coc)

Diagnostics — and the richer completions/hover described above — are
provided by quarkdown's language server (`quarkdown language-server`).
This plugin registers that server with whichever supported client it finds
on your runtimepath, so you do not configure anything:

| Client  | How it is wired up                                                        |
|---------|---------------------------------------------------------------------------|
| [coc.nvim](https://github.com/neoclide/coc.nvim) | A `languageserver.quarkdown` entry is injected into `g:coc_user_config` at startup (session-only, never written to `coc-settings.json`). Alternatively install the [coc-quarkdown](https://github.com/bladeacer/coc-quarkdown) extension and set `g:quarkdown_lsp_clients` to exclude `'coc'`. |
| [ale](https://github.com/dense-analysis/ale) | An LSP linter is defined via `ale#linter#Define` (diagnostics in the loclist, `:ALEHover`, completion via `ale#completion#OmniFunc`). |
| [vim-lsp](https://github.com/prabirshrestha/vim-lsp) | The server is registered via `lsp#register_server` (`:LspHover`, completion via `lsp#complete`). |

What the server diagnoses (as of quarkdown v2.6.4): invalid parameter
*values* (against the documented allowed values), *unresolved* parameter
names, and *duplicate* parameter names in one call. It does **not**
diagnose unknown function names, wrong argument counts or unbalanced
braces — a full `:QuarkdownCompile` (which runs `--strict` and fills the
quickfix on failure) remains the authoritative check.

coc note: the injected entry lives only in `g:coc_user_config` for the
session. A plain `let g:coc_user_config = {...}` later in your vimrc
(sourced after `plug#end()`) replaces that dict and removes the entry —
the plugin re-injects it (restarting coc, if already running) the next
time a `.qd` file is opened, so no vimrc changes are required. To avoid
that one-time restart you can instead set your dict before `plug#end()`
or write it as `let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {...})`.

Options:

| Variable                     | Default        | Meaning                                              |
|------------------------------|----------------|------------------------------------------------------|
| `g:quarkdown_lsp`            | `1`            | Enable the LSP integration entirely                  |
| `g:quarkdown_lsp_clients`    | `'auto'`       | Which clients to register: `'auto'` picks the first available of coc, ale, vim-lsp; or a list like `['ale', 'vim-lsp']` to force specific ones (all listed are registered) |
| `g:quarkdown_complete_auto`  | `1`            | Offline auto-popup after `.` / `{` (no client only)  |

`g:quarkdown_compiler` is shared with compilation and also names the
language-server binary.

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

Compilation and LSP tests are skipped automatically when the `quarkdown`
CLI is not executable. The LSP suite speaks real LSP to
`quarkdown language-server` over a vim channel (framing via vim's `lsp`
channel mode) and checks capabilities plus diagnostics; client registration
is tested against fake ale / vim-lsp / coc autoload stubs under
`test/fake-rtp/`. Details land in `test/last-result.txt`.

## Regenerating the stdlib catalogue

`data/stdlib.json` (used by offline completion and `:QuarkdownDoc`) is
generated by querying the language server, not by hand:

```sh
node scripts/gen-stdlib-data.js      # requires quarkdown >= 1.9.0 on PATH
```

Re-run it after upgrading quarkdown to pick up new/changed stdlib functions.

## Roadmap

### Phase 1

- [x] simple syntax highlighting

- [x] In-file Toc

- [x] compiling

### Phase 2: Minor Advances

- [x] mirror most of quarkdown-VScode's features (completions, documentation,
    diagnostics, PDF export; browser-based preview via `:QuarkdownPreview`)

- [x] heading-based folding

- [x] `[[`/`]]` heading motions

- [ ] function-call text objects (`if`/`af`, vimtex-style)

### Phase 3: Major Revisions

- [ ] forward/inverse search: jump from the cursor position to the matching
   spot in the browser preview, and from the preview back to the source
   (depends on what the preview page's JavaScript exposes)

- [ ] multi-file support: main-file detection, `[text](other.qd)` hops,
   word count

### What Will Not Be Implemented (for now)

- [ ] In-editor rendered live preview. Vim is pure text; the closest 
      available today is `:QuarkdownPreview -w`, which recompiles on
      change in a browser tab.

- [ ] Semantic-token based highlighting of function calls (the server provides
    semantic tokens; none of ale/vim-lsp consumes them, and coc users can
    get them via coc-quarkdown). The regex syntax in this plugin covers the
    common cases.

- [ ] Advanced syntax highlighting — the regex layer covers the common cases
    and there is no concrete need yet (see also the semantic-token note
    above).

- [ ] Conceal of function syntax / emphasis markers — likely nice, but it
    needs research and is not planned for now.

- [x] Snippets and templates

This can be handled by a handful of more specialized plugins, including but limited to:
 * [UltiSnips](https://github.com/SirVer/ultisnips)
 * [neosnippet](https://github.com/Shougo/neosnippet.vim)

- [x] Tag navigation

Similarly, check out
 * [vim-gutentags](https://github.com/ludovicchabant/vim-gutentags)

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

## Acknowledgements

[vim-markdown](https://github.com/preservim/vim-markdown) and [vimtex](https://github.com/lervag/vimtex) for inspiration of 
what features I should implement. Another source is the
official [VS code extension](https://marketplace.visualstudio.com/items?itemName=quarkdown.quarkdown-vscode).

[Quarkdown](https://github.com/iamgio/quarkdown) itself, of course! And the official [LSP](https://github.com/iamgio/quarkdown/tree/main/quarkdown-lsp).

