# tmux-spoony

![tmux-spoony demo](./assets/tmuxSpoony.gif)

Small tmux copy-mode helpers for grabbing useful terminal text without replacing tmux copy mode.

Spoony adds one-key selectors for URLs, paths, shell commands, and whole lines. You still navigate with normal tmux copy-mode keys.

## Usage

Enter copy mode:

```text
prefix [
```

Move to a target line with normal tmux copy-mode navigation, then press:

```text
u  select URL on the cursor line
U  cycle to the next URL on the cursor line
p  select path on the cursor line
P  cycle to the next path on the cursor line
m  select command after the prompt
M  after pressing the lowercase variant to select command output block until the next prompt
x  select the whole line
o  open the selected text
y  yank the selected text
```

The command block selector starts at the command after the prompt, then keeps selecting downward until it finds the next prompt. If the command is still running and there is no next prompt, it selects through the last non-empty output row. That means interrupted commands include the `^C` line because it is part of how the command block ended.

Examples:

```text
running on http://localhost:3000/practice

  Move to that line, press `u` to select the URL, then press `o` to open it.
```

```text
docs available at http://localhost:3000/docs and http://localhost:3000/api

  Move to that line, press `u` to select the nearest URL, then press `U` to cycle to the next URL on that same line.
```

```text
saved assets/tmuxSpoony.gif and logs/server-output.txt

  Move to that line, press `p` to select the nearest path, then press `P` to cycle to the next path on that same line.
```

```text
dev@host [ ~/project/api ] $ npm run start
> start
> node server.js

running on http://localhost:3000/practice
^C
dev@host [ ~/project/api ] $

  Move to the command line, press `m` to select only `npm run start`, then press `M` to select the command and its output through `^C`, stopping before the next prompt.
  * works best if you press `m` (lowercase) before `M` (uppercase)
```

## Install

### TPM

Add Spoony to your `~/.tmux.conf` plugin list:

```tmux
set -g @plugin 'parwest/tmux-spoony'
```

Make sure the plugin line appears before TPM is initialized:

```tmux
run '~/.tmux/plugins/tpm/tpm'
```

Reload tmux config:

```sh
tmux source-file ~/.tmux.conf
```

Install the plugin with TPM:

```text
prefix + I
```

Or run TPM's installer directly:

```sh
~/.tmux/plugins/tpm/bin/install_plugins
```

Reload tmux once more after install:

```sh
tmux source-file ~/.tmux.conf
```

### Local Checkout

For local testing without TPM, run the plugin file directly:

```sh
tmux run-shell '/path/to/tmux-spoony/tmux-spoony.tmux'
```

To load a local checkout from `~/.tmux.conf`:

```tmux
run-shell '/path/to/tmux-spoony/tmux-spoony.tmux'
```

## Key Bindings

Spoony works without configuration. To customize the copy-mode keys, add options to your `~/.tmux.conf` before Spoony is loaded. If you use TPM, put them after `set -g @plugin 'parwest/tmux-spoony'` and before `run '~/.tmux/plugins/tpm/tpm'`. If you use a local checkout, put them before the Spoony `run-shell` line.

```tmux
set -g @spoony-url-key 'u'
set -g @spoony-url-cycle-key 'U'
set -g @spoony-path-key 'p'
set -g @spoony-path-cycle-key 'P'
set -g @spoony-command-key 'm'
set -g @spoony-command-block-key 'M'
set -g @spoony-line-key 'x'
set -g @spoony-open-key 'o'
```

If `@spoony-url-cycle-key`, `@spoony-path-cycle-key`, or `@spoony-command-block-key` is unset and the base selector key is a single lowercase letter, Spoony derives the related key by uppercasing it. For example, `u` derives `U`, `p` derives `P`, and `m` derives `M`.

For example, this moves the default URL and path selectors to uppercase keys and moves their cycle keys to control keys:

```tmux
set -g @spoony-url-key 'U'
set -g @spoony-url-cycle-key 'C-u'
set -g @spoony-path-key 'P'
set -g @spoony-path-cycle-key 'C-p'
set -g @spoony-command-key 'M'
set -g @spoony-command-block-key 'B'
set -g @spoony-line-key 'X'
```

Any key can be disabled with `off`:

```tmux
set -g @spoony-open-key 'off'
set -g @spoony-url-cycle-key 'off'
```

## Prompt Matching

The command selector uses this default prompt regex:

```tmux
set -g @spoony-command-prompt-regex '^.+[$#>] +'
```

It matches common prompts ending in `$ `, `# `, or `> `, and avoids mistaking lines like npm's `> start` output for a shell prompt. If your prompt is unusual, set a more specific regex before loading Spoony.

## Requirements

- tmux with `copy-mode-vi` key tables
- Bash
- macOS `open` if you use Spoony's default `o` opener

Development/testing system:

- macOS
- tmux `3.6a`
- GNU Bash `5.3.9`
- `copy-mode-vi`
