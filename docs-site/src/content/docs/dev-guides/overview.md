---
title: Overview
description: Guides for developing Loom Warehouse itself — building, testing, worktrees.
---

These guides are for the people who maintain Loom Warehouse. They cover how the repo is built, tested, and worked on day to day.

- **[Testing strategy](../testing/)**: the three test tiers (dev loop, local gate, CI), the `just` recipes that run each one, and how long each takes.
- **[Worktrees and builds](../worktrees/)**: why each worktree gets its own `target/`, how a git hook builds a new worktree in the background, and what that costs.
