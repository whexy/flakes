# Flakes

This repo contains multiple flake templates that I used in multiple projects to
quickly bootstrap a nix-managed system.

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
