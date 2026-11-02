# PVZ Lit Slice (Godot 4.3)

Playable vertical slice aiming at [BV1tLgQ6nEbR](https://www.bilibili.com/video/BV1tLgQ6nEbR/) lighting quality — **realtime** soft DirectionalLight2D shadows, plantern PointLight2D lamps, silhouette occluders, normals, HDR bloom — with sun / plant / shoot / zombie bite.

**Original placeholder art only. No PopCap / EA assets.**

## Requirements

Godot **4.3** (standard build). Example Linux binary:

```bash
# optional local path used in this environment
/workspace/tools/Godot_v4.3-stable_linux.x86_64
```

## Run

```bash
godot --path /workspace/pvz-lit
# or:
/workspace/tools/Godot_v4.3-stable_linux.x86_64 --path /workspace/pvz-lit
```

If Vulkan present fails, force OpenGL:

```bash
godot --path /workspace/pvz-lit --rendering-driver opengl3
```

Controls: **LMB** plant (50) / collect sun · **D** softer shadows · **L** toggle lamps.

## Capture demo frames

```bash
PVZ_CAPTURE=1 /workspace/tools/Godot_v4.3-stable_linux.x86_64 \
  --path /workspace/pvz-lit --rendering-driver opengl3 -- --capture
```

Writes PNGs under the Project media store.

## Lighting stack

- `DirectionalLight2D` PCF13 soft key light (orbiting dusk angle)
- Plantern `PointLight2D` with local soft shadows
- `OccluderUtil` alpha-silhouette hulls for plants / zombies / lamps
- `CanvasTexture` normals on lawn tiles + entities
- `viewport/hdr_2d` + `Environment` glow/bloom
