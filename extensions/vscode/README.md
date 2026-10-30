# Dev Island — Terminal Router

Local macOS companion for Dev Island. Each VS Code window registers its own existing terminals' shell PIDs, then focuses the requested window and terminal. It never creates a replacement terminal or sends text/commands to the shell. No account, telemetry, internet service, screen recording or Accessibility permission.

Install the bundled VSIX in VS Code: Extensions → … → Install from VSIX. If a window does not connect after installation, run Developer: Reload Window when convenient. Existing local terminals are enumerated on activation. Command Palette: Dev Island: Show Terminal Connection Status.

Requires desktop VS Code 1.90+, macOS and local terminals. Remote/SSH/dev-container terminals and tmux pane selection are outside this release. Session names and project paths are not used to guess terminal identity. Missing/closed/ambiguous targets fail explicitly.

The local endpoint uses a private 0700 directory, 0600 files/socket, a per-window random token, bounded JSON and timeouts. Registry records expire after 45 seconds without heartbeat. Public Terminal.processId and Terminal.show(false) APIs select the instance; workbench.action.focusWindow is capability-checked before use. It is present in the validated VS Code 1.143.1 build; an unsupported editor reports a failure.
