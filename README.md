# Guts - A bevy editor from within Emacs.

## Features

- Entity and Resource inspector [x].
- RON standard manipulation library [].
- Bevy display (if possible) [].
- Entity filtering (via components) [x] 
  - Include filters [x]
  - Exclude filters [x]
- Hierarchy manipulation []
- Component deletion [x]
- Component insertion []
- Component editing [x]
- Resource editing [x]

## TODO
- Implement improved rendering
Each section should have ownership of the section that it has, and 
when it becomes dirty, only that part of the section is re-rendered.
Preferably a scheduler should run every couple of seconds to re-render
all of the dirty sections. This requires storing the start and end of a
given section and meta data about it so that it can be easily reconstructed.

This should be easy to do, but a solid abstraction needs to be made.

Perhaps an integrated package called `guts-section` which adds additional
metadata on sections and bookkeeping for each section and a scheduler
which tracks dirty states on each section.

