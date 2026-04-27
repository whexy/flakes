# Flakes

This repository contains a handful collection of my widely used flakes. You can
treat it as a starting point to launch a new project or a convenient way to
quickly start a opinion-ed environment.

Flake is short for "nix flake", a format which the package manager `nix` uses.
It's like a "Dockerfile" that declare all the things you required in a system.
But unlike Docker or any other containers which starts a new "environment",
`nix` runs in the same environment that your shell runs. So you can still use
your favorite tools installed on your machine. Consider `nix` as `conda` but
for everything beyond Python packages.

Another reason I want to use nix to manage templates is because it locks the
packages in a good way, so we won't end up with debates "this works on my local
environment but not yours".

Most flakes are not trivial. (If they are trivial, I won't include them here,
you can just write them as-you-go.) For example, `jupyter` flake exposes a
Jupyter Lab service where the GPU acceleration is baked in to dependencies. So
you don't need to spend hours hunting the correct match of "CUDA version +
Python version" libraries to install. Flake `typst` contains a carefully
considered writing environment for every paper and report I wrote. It has
been tuned for months to integrate plugins, fonts, LSPs, and building tools
together in a good declarative way.

## Usage

```sh
nix flake init -t github:whexy/flakes#<template-name>
```

For example, to apply the Jupyter notebook setup, run

```sh 
nix flake init -t github:whexy/flakes#jupyter
```

## Menu

### Service

- TODO

### Development

- Typst sertup (`#typst`)
- Jupyter notebook setup (`#jupyter`)
