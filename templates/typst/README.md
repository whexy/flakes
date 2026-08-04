# Typst Project

A minimal Typst project with a reproducible Nix development environment, PDF
build, formatting and pre-commit checks, and project-local Neovim settings.

## Getting started

Enter the development shell (or allow it with direnv):

```sh
nix develop
```

Compile or continuously rebuild the document:

```sh
typst compile src/main.typ main.pdf
typst watch src/main.typ main.pdf
```

Build the reproducible PDF package or run all checks:

```sh
nix build
nix flake check
```

The Neovim configuration in `.nvim.lua` pins Tinymist to `src/main.typ`, uses
treefmt for project files, configures Typst Preview, and adds DBLP citation
search. Neovim must be configured to trust and load local project files.
