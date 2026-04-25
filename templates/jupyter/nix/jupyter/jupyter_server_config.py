import os

# ── Language server ──────────────────────────────────────────────────
# Disable auto-detection so that basedpyright from ~/.nix-profile is
# never picked up.  Instead we explicitly register pylsp, launching it
# through the same Nix Python that has torch, numpy, etc. installed.
# The interpreter path is injected via JUPYTER_PYLSP_PYTHON in the
# devshell so it always matches the current environment.
_pylsp_python = os.environ.get("JUPYTER_PYLSP_PYTHON", "python3")

c.LanguageServerManager.autodetect = False  # noqa: F821

c.LanguageServerManager.language_servers = {  # noqa: F821
    "pylsp": {
        "argv": [_pylsp_python, "-m", "pylsp"],
        "languages": ["python"],
        "mime_types": ["text/python", "text/x-python", "text/x-ipython"],
        "display_name": "python-lsp-server (pylsp)",
        "version": 2,
    },
}
