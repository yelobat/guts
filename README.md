# Guts - A bevy editor from within Emacs.

Guts is a [magit](https://magit.vc/)-style interface to a running Bevy
app, built on top of the
[Bevy Remote Protocol](https://docs.rs/bevy/latest/bevy/remote/index.html)
via [brpel](https://github.com/yelobat/brpel).

Run `M-x guts` while your app (with `RemotePlugin` and
`RemoteHttpPlugin`) is running to open the entity browser.

## Features

- Entity and Resource inspector [x].
- Entity filtering (via components) [x]
  - Include filters [x]
  - Exclude filters [x]
- Hierarchy manipulation (reparenting via marks) [x]
- Entity spawning, renaming, and despawning [x]
- Component insertion (scaffolded from the registry schema) [x]
- Component deletion [x]
- Component editing (commit-style edit buffers) [x]
- Component field mutation [x]
- Interactive Transform manipulation (move/rotate/scale live) [x]
- Resource insertion, editing, and deletion [x]
- RON standard manipulation library []
- Bevy display (if possible) []

## Keybindings

Press `?` (or `m`) in any guts buffer for the dispatch menu.

### Entity view (`*guts-ecs-entities*`)

| Key   | Action                                              |
|-------|-----------------------------------------------------|
| `RET` | Browse the entity's components                      |
| `t`   | Transform menu: move/rotate/scale the entity live   |
| `+`   | Spawn a new entity (optionally named)               |
| `R`   | Rename the entity (inserts/updates `Name`)          |
| `i`   | Insert a component on the entity                    |
| `d`   | Mark for despawn                                    |
| `C`   | Mark as child                                       |
| `P`   | Mark as parent                                      |
| `u`   | Unmark                                              |
| `x`   | Execute marks (despawn / reparent)                  |
| `f`   | Component filter menu                               |
| `r`   | Switch to the resource view                         |
| `g`   | Refresh                                             |
| `?`   | Dispatch menu                                       |

Marking children without a parent detaches them from their current
parent on `x`.

### Component view (`*guts-ecs-components*`)

| Key   | Action                                              |
|-------|-----------------------------------------------------|
| `RET` | Edit the component value                            |
| `i`   | Insert a new component                              |
| `M`   | Mutate a single field (e.g. `translation.x`)        |
| `t`   | Transform menu for the entity                       |
| `d`   | Mark component for removal                          |
| `u`   | Unmark                                              |
| `x`   | Execute marks                                       |
| `e`   | Back to the entity view                             |
| `r`   | Switch to the resource view                         |
| `g`   | Refresh                                             |

### Resource view (`*guts-ecs-resources*`)

| Key   | Action                                              |
|-------|-----------------------------------------------------|
| `RET` | Edit the resource value                             |
| `i`   | Insert a resource                                   |
| `d`   | Mark resource for removal                           |
| `u`   | Unmark                                              |
| `x`   | Execute marks                                       |
| `e`   | Back to the entity view                             |
| `g`   | Refresh                                             |

### Transform menu

Opened with `t`. The menu stays open so an entity can be nudged
around the scene by tapping keys:

- `x`/`X`, `y`/`Y`, `z`/`Z` — translate along ±X/±Y/±Z by the step.
- `u`/`U`, `i`/`I`, `o`/`O` — rotate around ±X/±Y/±Z by the angle.
- `>`/`<` — scale up/down by the scale factor.
- `t`/`r`/`c` — set absolute translation / rotation (Euler degrees) / scale.
- `s`/`a`/`f` — adjust the step, angle, and scale factor.

If the entity has no `Transform`, guts offers to insert an identity
transform first.

### Editing values

Editing or inserting a value opens a `*guts-edit*` JSON buffer
(pre-filled with the current value, or defaults scaffolded from the
registry schema). Press `C-c C-c` to apply it to the running app, or
`C-c C-k` to cancel.
