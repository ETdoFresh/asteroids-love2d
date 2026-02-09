# Asteroids

A classic Asteroids arcade game built with the [LÖVE 2D](https://love2d.org/) framework.

![Asteroids Screenshot](screenshot.png)
<!-- Replace screenshot.png with an actual screenshot of the game -->

## How to Run

The game requires the **LÖVE 2D** framework (version 11.4+).

### Install LÖVE 2D

- **Windows** — Download the installer from [love2d.org](https://love2d.org/)
- **macOS** — `brew install love`
- **Linux (Debian/Ubuntu)** — `sudo apt install love`
- **Linux (Arch)** — `sudo pacman -S love`

### Run the Game

```sh
love .
```

## Controls

### Keyboard

| Action     | Keys                    |
|------------|-------------------------|
| Thrust     | `W` / `Up Arrow`        |
| Rotate     | `A` `D` / `Left` `Right` |
| Shoot      | `Space`                 |
| Hyperspace | `Shift`                 |
| Pause      | `Escape`                |
| Select     | `Enter`                 |

### Gamepad

| Action     | Buttons                       |
|------------|-------------------------------|
| Thrust     | D-Pad Up                      |
| Rotate     | D-Pad Left / Right            |
| Shoot      | A / RB / RT                   |
| Hyperspace | X / LB / LT                  |
| Pause      | Start / B                     |
| Select     | Y                             |

## Features

- **Ship movement** — Thrust-based acceleration with friction and screen wrapping
- **Asteroids** — Three sizes (large, medium, small) that split on destruction
- **Scoring** — 20 / 50 / 100 points for large / medium / small asteroids
- **Lives** — Start with 3; earn an extra life every 10,000 points
- **Level progression** — Each level adds more asteroids
- **Hyperspace jump** — Teleport to a random location with a 3-second cooldown
- **Particle effects** — Explosions, thrust flames, and hyperspace bursts
- **Gamepad support** — Full controller support with anti-crosstalk protection
- **Pause menu** — Resume, restart, or return to the main menu
- **High score tracking** — Persists across sessions
