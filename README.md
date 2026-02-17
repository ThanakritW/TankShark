# TankShark

A 2D top-down multiplayer battle royale game built with **Godot 4.6** and **GDScript**. Players control shark-tank hybrids, fight enemies, level up, choose classes, and compete to be the last one standing in a shrinking arena.

---

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript
- **Networking:** WebSocket (`WebSocketMultiplayerPeer`)
- **Physics:** Jolt Physics

---

## How to Play

| Action | Key(s) |
|--------|--------|
| Move | W / A / S / D or Arrow Keys |
| Aim | Mouse |
| Shoot | Space or Left Mouse Button (hold for auto-fire) |
| Sneak | Shift (50% speed) |
| Throw Bomb | Tab (15s cooldown) |
| Stat Upgrade | 1–5 (when upgrade points available) |
| Class Select | 1–3 (at level 5) |

---

## Game Flow

1. **Lobby** — Players connect to a server. The UI shows "X/3 players connected..."
2. **Game Start** — When 3 players join, the server locks connections and starts the match.
3. **Connection Rejection** — Late joiners receive a "Room full" message and are disconnected.
4. **Gameplay** — Players move, shoot, throw bombs, destroy barrels, collect XP orbs, level up, and upgrade stats.
5. **Shrinking Zone** — A red danger zone shrinks toward the map center every 5 seconds. Players outside take 2 HP/sec damage, forcing encounters.
6. **Win Condition** — When only 1 player remains alive, the server declares them the winner.
7. **Reset** — 8 seconds after the game ends, the server disconnects everyone and resets for a new match.

---

## Core Game Mechanics

### Movement & Combat
- Smooth acceleration/friction physics with 8-directional movement
- Mouse controls 360° gun rotation
- Bullets travel in gun direction with a 3-second lifetime
- Shift to sneak (halved speed, doubled friction)

### Bombs
- Thrown as a projectile in the aim direction at 600 px/s
- Sticks to any non-bullet object on contact (walls, barrels, players)
- Detonates 4 seconds after being thrown
- 250px explosion radius, 10 damage per target
- Destroys walls and one-shots barrels (3 HP)

### Destructible Barrels
- 3 HP each, placed in clusters around the map (11 spawner locations, 3–6 barrels each)
- Drop 1–4 experience orbs (1–5 XP each) on destruction

### Naval Mines
- 30 randomly placed across the map
- Triggered by player contact (2 damage) or bullet collision
- Avoids spawning near player starts and houses

### Shrinking Zone (Battle Royale)
- Starts at 5,000px radius centered on the map
- Shrinks by 150px every 5 seconds, down to a minimum of 100px
- Deals 2 HP/sec to players outside the safe zone
- Visualized as a transparent red overlay outside the circle

---

## Progression System

### Experience & Leveling
- Kill barrels and collect XP orbs to gain experience
- Killing a player makes them drop 20% of their total earned XP as orbs
- XP threshold increases each level (×1.1 scaling)
- Each level grants: +1 upgrade point, +2 max HP (heal 20% of new max)

### Stat Upgrades (5 stats, max level 5 each)

| Stat | Effect per Level | Max Bonus |
|------|-----------------|-----------|
| Attack | +0.5× damage multiplier | ×3.5 at max |
| Bullet Speed | +0.2× projectile speed | ×2.0 at max |
| Fire Rate | ×0.90 shoot interval | ~×0.59 at max |
| Bomb Cooldown | −1.0s cooldown | 10s at max |
| Player Speed | +30 px/s move speed | 550 px/s at max |

### Class Evolution (Level 5)

At level 5, players choose one of three class upgrades:

| Class | Fire Rate | Guns | Special |
|-------|-----------|------|---------|
| Twin | 0.2s | 2 (stacked vertically) | High fire rate |
| Flank | 0.5s | 2 (front + rear) | Attacks behind you |
| Sniper | 1.2s | 1 | 3× damage, 2× bullet speed, zoomed camera |

---

## Network Architecture

### Client-Server Model
- One dedicated server, multiple clients connect via WebSocket
- **Server-authoritative** — the server controls all game state: health, damage, XP, zone shrinking, win conditions. Clients cannot cheat because they don't decide outcomes.

### RPC (Remote Procedure Call)
All communication uses Godot's built-in `@rpc` annotations:
- **`"any_peer"`** — any client can call (e.g., requesting to shoot)
- **`"authority"`** — only the server can call (e.g., syncing health, announcing winner)
- **`"call_local"`** — also executes on the caller, not just the remote
- **`"reliable"`** — guaranteed delivery (TCP-like), used for important events

**Flow:** Client presses a key → sends RPC to server → server validates & processes → server broadcasts result to all clients via RPC

### Deterministic Map Generation
- Server generates a random `map_seed` and sends it to all clients
- All clients use the same seed to generate identical maps (walls, mines, barrels)
- No network sync needed for static map objects

### Late-Join Sync
When a new client connects:
1. Server sends all existing player positions
2. Server sends list of destroyed barrels/mines
3. Server sends current zone radius
4. New player is spawned on all clients simultaneously

---

## Project Structure

```
TankShark/
├── project.godot              # Project config, autoloads, input map
├── scenes/
│   ├── lobby.tscn             # Multiplayer connection screen
│   ├── world.tscn             # Main game scene (players, HUD, zone, game over)
│   ├── map.tscn               # Procedural map with boundaries
│   ├── player.tscn            # Player character (shark + guns + HUD)
│   ├── bullet.tscn            # Projectile with ShapeCast2D hit detection
│   ├── barrel.tscn            # Destructible crate with health bar
│   ├── barrel_spawner.tscn    # Spawns 3–6 barrels in a cluster
│   ├── exp_orb.tscn           # Collectible XP pickup
│   ├── player_bomb.tscn       # Throwable explosive with idle/explode animations
│   ├── navel_mine.tscn        # Static proximity mine
│   ├── house.tscn             # Static structure with walls and light occluders
│   └── wall.tscn              # Random wall segment with plank texture
├── scripts/
│   ├── network_manager.gd     # Autoload: WebSocket setup, lobby, game state
│   ├── lobby.gd               # Connection UI, waiting status, room full handling
│   ├── world.gd               # Player spawning, zone, win condition, object sync
│   ├── player.gd              # Movement, shooting, health, XP, leveling, classes
│   ├── bullet.gd              # Projectile movement and collision
│   ├── barrel.gd              # Destructible object, drops XP orbs
│   ├── barrel_spawner.gd      # Seeded barrel placement
│   ├── exp_orb.gd             # XP pickup on player contact
│   ├── player_bomb.gd         # Thrown bomb: movement, sticking, AOE explosion
│   ├── navel_mine.gd          # Proximity/bullet-triggered mine
│   ├── map.gd                 # Procedural wall/mine/barrel generation
│   └── background.gd          # Scrolling parallax background
└── assets/
    ├── shark.png               # Player sprite
    ├── tank.png                # Gun sprite
    ├── bullet.png              # Projectile sprite
    ├── barrel.png              # Barrel sprite
    ├── exp.png                 # XP orb sprite sheet
    ├── navel_mine.png          # Mine sprite sheet
    ├── background.jpg          # Tiled background
    ├── plank_texture.jpg       # Wall texture
    └── lightCone.jpg           # Gun spotlight texture
```

---

## Key Design Patterns

1. **Server-Authoritative** — All critical decisions (damage, XP, deaths) are validated server-side
2. **Client-Side Prediction** — Position and velocity are synced with unreliable RPCs for smooth movement
3. **RPC Broadcasting** — Dynamic events (barrel death, bomb explosion) are broadcast from server to all clients
4. **Deterministic Seeding** — Map generation is identical across clients using a shared seed
5. **Node Naming Convention** — Player nodes are named by their `peer_id` for multiplayer authority identification
6. **Deferred Calls** — `call_deferred()` is used to schedule node removal after the current frame settles

---

## Collision Layers

| Layer | Contents |
|-------|----------|
| 1 | Walls, environment, static bodies |
| 2 | Players (CharacterBody2D) |
| 3 | Bullets, orbs, bombs |

Players do not collide with each other (mask excludes layer 2).

---

## Lighting System

- **CanvasModulate** darkens the entire map (RGB: 0.15, 0.12, 0.20)
- Each player has a **PointLight2D** with a radial gradient — only visible to that player's client
- Guns have **PointLight2D** spotlight cones for aimed lighting
- Houses use **LightOccluder2D** nodes to cast shadows

---

## Running the Game

1. Open the project in **Godot 4.6**
2. Run the project — it starts at the **Lobby** scene
3. One player clicks **Host** to create a server
4. Other players enter the host's IP address and click **Join**
5. The game starts automatically when 3 players are connected (or the host can click Start)

For a dedicated server, export as Linux binary and run with the `--headless` flag.
