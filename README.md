# FluentUI / FluentPlus

Roblox **executor** UI library (Luau): Fluent-style windows with FluentPlus extras—multi-column rows, horizontal button rows, optional key gate, status bar (FPS/ping), and a forked **SaveManager** with autosave.

> **Scope:** This runs in third-party executors (HTTP + optional `writefile`/`readfile`). It is **not** a Roblox Studio plugin.

**Repository layout**

| Path | Purpose |
|------|---------|
| [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua) | **Main build** — load this in production (monolithic library). |
| [`FluentPlus/Example.lua`](FluentPlus/Example.lua) | Full sample: window, toggles, SaveManager, InterfaceManager, columns, button rows. |
| [`Addons/SaveManager.lua`](Addons/SaveManager.lua) | Persistence UI + autosave (forked). |
| [`Addons/InterfaceManager.lua`](Addons/InterfaceManager.lua) | Theme / acrylic / menu keybind UI. |
| [`Fluent/`](Fluent/) | Modular upstream-style sources (Rojo); reference for contributors. |

Base Fluent patterns (tabs, sections, Lucide icons) align with upstream [Fluent documentation](https://docs.sirius.menu/fluent); FluentPlus-specific behavior is defined in `Beta.lua`.

---

## Requirements

- Executor with **`game:HttpGet`** (or equivalent) to fetch `Beta.lua`.
- For **SaveManager** / **InterfaceManager** file configs: **`writefile`**, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles` (executor file API).

---

## Installation

### Option A — One load (recommended)

`Beta.lua` returns **four values**: `Library`, `SaveManager`, `InterfaceManager`, `Mobile`.

```lua
local REPO = "https://raw.githubusercontent.com/HOSTI1315/FluentUI/main"

local Fluent, SaveManager, InterfaceManager, Mobile =
	loadstring(game:HttpGet(REPO .. "/FluentPlus/Beta.lua", true))()

-- Fluent = main UI library; use SaveManager / InterfaceManager below.
```

> Confirm the `return` line at the end of your checked-out `Beta.lua` if you fork the repo—**this README is accurate for the `main` branch as shipped.**

### Option B — Three separate HTTP loads

Use this only if you use an older split layout or non-bundled build:

```lua
local REPO = "https://raw.githubusercontent.com/HOSTI1315/FluentUI/main"

local Fluent = loadstring(game:HttpGet(REPO .. "/FluentPlus/Beta.lua", true))()
local SaveManager = loadstring(game:HttpGet(REPO .. "/Addons/SaveManager.lua", true))()
local InterfaceManager = loadstring(game:HttpGet(REPO .. "/Addons/InterfaceManager.lua", true))()
```

Avoid mixing **Option A** and **Option B** for the same session (double-initializing managers can cause confusing errors).

### Releases

If you publish GitHub **Releases** with `main.lua` (see [`.github/workflows/release-fluentplus.yml`](.github/workflows/release-fluentplus.yml)), consumers can use:

```lua
local Fluent = loadstring(game:HttpGet("https://github.com/HOSTI1315/FluentUI/releases/latest/download/main.lua", true))()
```

Adjust org/repo in the URL when you fork.

---

## Minimal script

```lua
local Fluent, SaveManager, InterfaceManager =
	loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/HOSTI1315/FluentUI/main/FluentPlus/Beta.lua",
		true
	))()

local Window = Fluent:CreateWindow({
	Title = "My Hub",
	Size = UDim2.fromOffset(580, 460),
	Theme = "Dark",
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local Section = Main:AddSection("Features", "zap")

Section:AddToggle("MyToggle", { Title = "Enable feature", Default = false })

local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("MyHub")
SaveManager:SetFolder("MyHub/my-game-id")
InterfaceManager:BuildInterfaceSection(Settings)
SaveManager:BuildConfigSection(Settings)

Window:SelectTab(1)

pcall(function()
	SaveManager:LoadAutoloadConfig()
end)
```

For **key system**, **status bar**, **columns (`AddRow`)**, and **`AddButtonRow`**, copy patterns from [`FluentPlus/Example.lua`](FluentPlus/Example.lua).

---

## Rules (do not violate)

1. **`CreateKeySystem` before `CreateWindow`** — The key modal blocks until success; the main window must not exist yet.
2. **One window per session** — A second `CreateWindow` call is rejected by the library.
3. **SaveManager** needs the executor file APIs listed above.
4. **Autosave** hooks are installed when you call `SaveManager:BuildConfigSection`. Disable with `SaveManager:SetAutosaveEnabled(false)` if needed.
5. **`Fluent.Options`** — Named controls (`AddToggle("Key", …)` etc.) must use **stable string keys** that match SaveManager save entries when you rely on configs.

---

## FluentPlus API highlights

Methods on the library object returned from `Beta.lua` (names may vary slightly; **`Beta.lua` is authoritative**):

| Method | Notes |
|--------|--------|
| `CreateKeySystem(config)` | Before `CreateWindow`. `Key` or `Keys`, optional `SaveKey`, `FolderName`, `Note`, `URL`, `URLText`. |
| `CreateWindow(config)` | Once per session. `Title`, `Size`, `Theme`, `Acrylic`, `TabWidth`, `Search`, `UserInfo`, … |
| `CreateStatusBar(config)` | After window. `FPS`, `Ping`, `Fields`, `Position`, `AnchorPoint`. Returns object with `:SetField`, `:SetVisible`, `:Destroy`. |
| `CreateMinimizer(config)` | Floating minimize control. |
| `Notify({ Title, Content, SubContent?, Duration? })` | Toasts. |
| `SetTheme(name)` | See theme names below. |
| `Options` | Table of all registered options after `AddToggle` / `AddInput` / … |

**Tab**

- `AddTab({ Title, Icon })`
- `AddSection(title, icon?)` — Lucide short name (no `lucide-` prefix) where applicable.
- `AddRow(n)` — **FluentPlus:** `n` clamped 1–4; returns columns with `AddSection` + all `Add*` elements.
- `AddSubTab(title, icon?)`
- `AddParagraph({ … })` — On tab container.

**Section / column**

- `AddToggle`, `AddSlider`, `AddDropdown`, `AddInput`, `AddKeybind`, `AddColorpicker`, `AddButton` — same idea as upstream Fluent.
- `AddButtonRow({ { Title, Callback }, … })` — **FluentPlus:** horizontal row of buttons.

---

## Themes

Built-in names include: **Dark**, **Darker**, **AMOLED**, **Light**, **Balloon**, **SoftCream**, **Aqua**, **Amethyst**, **Rose**, **Midnight**, **Forest**, **Sunset**, **Ocean**, **Emerald**, **Sapphire**, **Cloud**, **Grape**, **Bloody**, **Arctic**.

Authoritative list: `Themes.Names` (or equivalent) inside [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua).

---

## SaveManager files

Relative to `SaveManager:SetFolder(folder)`:

| Path | Purpose |
|------|---------|
| `folder/settings/*.json` | Named configs |
| `folder/settings/autoload.txt` | Name of config loaded by `LoadAutoloadConfig()` |
| `folder/settings/active_config.txt` | Target for autosave |

---

## Troubleshooting

| Issue | Likely cause |
|-------|----------------|
| Second window error | Only one `CreateWindow` per run. |
| Save/load does nothing | Executor missing `writefile` / `readfile`. |
| Key UI never shows | You called `CreateWindow` before `CreateKeySystem`. |
| Icons missing | Wrong icon string; use Lucide short names as in `Example.lua`. |

---

## Contributing

- Prefer **`FluentPlus/Example.lua`** as the contract for public API examples.
- When changing `Beta.lua` return values or load strategy, update this **README** and any release workflow.

---

## License

Add your license here (e.g. MIT) if the repo does not already include a `LICENSE` file. Upstream Fluent may have its own terms—verify compatibility when redistributing.
