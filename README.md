# FluentPlus

Roblox executor UI library (Luau): extended [Fluent](https://github.com/dawid-scripts/Fluent) with multi-column layout, horizontal button rows, optional key gate, status bar (FPS/Ping), and a forked SaveManager with autosave. Official Fluent docs (base API): [Fluent documentation](https://forgenet.gitbook.io/fluent-documentation).

---

## For AI assistants (read first)

Use this section as **grounding** when generating or refactoring hub scripts for this repository.

### Facts

| Item | Value |
|------|--------|
| Domain | Roblox client; Luau; third-party **executor** with HTTP + file APIs |
| Primary ship file | [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua) (monolithic library) |
| HTTP addons (same URL pattern as upstream Fluent) | [`Addons/SaveManager.lua`](Addons/SaveManager.lua), [`Addons/InterfaceManager.lua`](Addons/InterfaceManager.lua) |
| Reference implementation | [`FluentPlus/Example.lua`](FluentPlus/Example.lua) |
| Release URL pattern | GitHub Release asset `main.lua` = copy of `Beta.lua` (workflow: [`.github/workflows/release-fluentplus.yml`](.github/workflows/release-fluentplus.yml)) |
| `Beta.lua` return | `return Library, SaveManager, InterfaceManager, Mobile` — you may assign four return values from one `loadstring` call |

### Rules (do not violate)

1. **`CreateKeySystem` before `CreateWindow`** — Key UI blocks until success; window must not exist yet.
2. **One window per session** — Second `CreateWindow` is rejected (library behavior).
3. **SaveManager** needs executor FS: `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`.
4. **Autosave** — Installed automatically at end of `SaveManager:BuildConfigSection` (no extra enable call). Disable with `SaveManager:SetAutosaveEnabled(false)`.
5. **Options table** — `Fluent.Options` holds named controls; indexes must match SaveManager save keys when using configs.

### Suggested script skeleton

```lua
local REPO = "https://raw.githubusercontent.com/OWNER/REPO/main"
local Fluent = loadstring(game:HttpGet(REPO .. "/FluentPlus/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet(REPO .. "/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet(REPO .. "/Addons/InterfaceManager.lua"))()

-- Optional, before window:
-- Fluent:CreateKeySystem({ Title = "...", Key = "...", SaveKey = true, FolderName = "HubName" })

local Window = Fluent:CreateWindow({ Title = "...", Size = UDim2.fromOffset(580, 460), Theme = "Dark" })
-- Optional: Fluent:CreateStatusBar({ FPS = true, Ping = true })

local Tab = Window:AddTab({ Title = "Main", Icon = "home" })
local Section = Tab:AddSection("Features", "zap") -- icon: Lucide name without lucide- prefix

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("GlobalFolder")
SaveManager:SetFolder("GlobalFolder/game-id")
InterfaceManager:BuildInterfaceSection(SettingsTab)
SaveManager:BuildConfigSection(SettingsTab)
SaveManager:LoadAutoloadConfig()
```

---

## Quick start (three HTTP loads)

Replace `YOUR_ORG` / `YOUR_REPO` / branch `main` as needed.

```lua
local Fluent = loadstring(game:HttpGet("https://github.com/YOUR_ORG/YOUR_REPO/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/Addons/InterfaceManager.lua"))()
```

**Without Releases** (raw `Beta.lua`):

```lua
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/FluentPlus/Beta.lua"))()
```

**Single loadstring (four returns)** — `Beta.lua` embeds SaveManager/InterfaceManager; you can skip separate addon URLs if you destructure returns (verify behavior matches your fork):

```lua
local Fluent, SaveManager, InterfaceManager, Mobile = loadstring(game:HttpGet(".../Beta.lua"))()
```

---

## Repository map

| Path | Role |
|------|------|
| [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua) | Shipped library: window, tabs, elements, `CreateStatusBar`, `CreateKeySystem`, `AddRow`, `AddButtonRow`, bundled managers |
| [`FluentPlus/Example.lua`](FluentPlus/Example.lua) | Full example: key system, status bar, columns, button row, SaveManager, InterfaceManager |
| [`Addons/SaveManager.lua`](Addons/SaveManager.lua) | Drop-in fork: upstream-compatible API + autosave + `active_config.txt` / `autoload.txt` |
| [`Addons/InterfaceManager.lua`](Addons/InterfaceManager.lua) | Same API as upstream InterfaceManager |
| [`Fluent/`](Fluent/) | Upstream-style modular sources (Rojo); reference only for most distributors |
| [`.github/workflows/release-fluentplus.yml`](.github/workflows/release-fluentplus.yml) | On **published** Release: uploads `main.lua` from `FluentPlus/Beta.lua` |

---

## API reference — FluentPlus additions (`Library` / `Fluent`)

Methods on the object returned by `loadstring(...)()` (the main table).

| Method | When to call | Notes |
|--------|----------------|-------|
| `CreateKeySystem(config)` | Before `CreateWindow` | Blocking modal. `Key` or `Keys`, optional `SaveKey`, `FolderName`, `Note`, `URL`, `URLText`. Returns boolean. |
| `CreateStatusBar(config)` | After GUI exists; typically after `CreateWindow` | `FPS`, `Ping` (booleans), `Fields = { { Name = "Label" } }`, `Position`, `AnchorPoint`. Returns object with `:SetField(name, value)`, `:SetVisible(bool)`, `:Destroy()`. |
| `CreateWindow(config)` | Once | Same core options as Fluent: `Title`, `Size`, `Theme`, `Acrylic`, `TabWidth`, `Search`, `UserInfo`, etc. |
| `CreateMinimizer(config)` | After window | Floating toggle button |
| `Notify({ Title, Content, SubContent?, Duration? })` | Anytime | |
| `SetTheme(name)` | Anytime | Theme name from library list |
| `Options` | Global options registry | `Fluent.Options.MyToggle` after `AddToggle("MyToggle", ...)` |

### Tab

| Method | Description |
|--------|-------------|
| `AddTab({ Title, Icon })` | On `Window` |
| `AddSection(title, icon?)` | Vertical section; `icon` = Lucide short name |
| `AddRow(columnCount)` | **FluentPlus.** `columnCount` clamped 1–4. Returns array `Cols`; each `Cols[i]` has `AddSection` and all `Add*` from `Elements`. |
| `AddSubTab(title, icon?)` | Horizontal sub-tabs; further `AddSection` targets active sub-tab |
| `AddParagraph({ ... })` | On tab directly (no section) |

### Section (and column objects from `AddRow`)

| Method | Description |
|--------|-------------|
| `AddToggle`, `AddSlider`, `AddDropdown`, `AddInput`, `AddKeybind`, `AddColorpicker`, `AddButton` | Same as upstream Fluent; require stable string index where SaveManager applies |
| `AddButtonRow({ { Title, Callback }, ... })` | **FluentPlus.** 2+ buttons in one horizontal row |

### Persistence files (SaveManager fork)

Relative to `SaveManager:SetFolder(folder)`:

| File | Purpose |
|------|--------|
| `folder/settings/*.json` | Named configs |
| `folder/settings/autoload.txt` | Config name loaded by `LoadAutoloadConfig()` |
| `folder/settings/active_config.txt` | Target name for **autosave** (also set on Create / Load / Overwrite / Set autoload) |

| SaveManager API | Purpose |
|-----------------|--------|
| `SetLibrary(Fluent)` | Required |
| `SetFolder(path)` | Workspace folder for JSON |
| `IgnoreThemeSettings()` | Ignore theme-related option keys |
| `SetIgnoreIndexes({ "idx", ... })` | Skip options in save |
| `BuildConfigSection(tab)` | UI for save/load + **installs autosave hooks** |
| `LoadAutoloadConfig()` | Load `autoload.txt` config if present |
| `SetAutosaveEnabled(false)` | Turn off autosave |
| `AutoLoadOnBuild = true` | Before `BuildConfigSection`: auto-call `LoadAutoloadConfig` at end of section build |

### InterfaceManager

| Method | Purpose |
|--------|--------|
| `SetLibrary(Fluent)` | Required |
| `SetFolder(path)` | Where `options.json` lives |
| `BuildInterfaceSection(tab)` | Theme / acrylic / transparency / menu keybind UI |

---

## Themes (names)

Dark, Darker, AMOLED, Light, Balloon, SoftCream, Aqua, Amethyst, Rose, Midnight, Forest, Sunset, Ocean, Emerald, Sapphire, Cloud, Grape, Bloody, Arctic (see `Beta.lua` `Themes.Names` for authoritative list).

---

## Upstream vs FluentPlus (summary)

- **Same**: Tab/section/element patterns, Lucide icons by short name, SaveManager UI flow, InterfaceManager.
- **Added**: `Tab:AddRow`, `Section:AddButtonRow`, `CreateStatusBar`, `CreateKeySystem`, autosaving fork in `Addons/SaveManager.lua`, extended themes, FluentPlus-specific window/search/subtab behavior in `Beta.lua`.

---

## More docs

- In-repo feature overview: [`FluentPlus/README.md`](FluentPlus/README.md) (screenshot + marketing bullets).
- External base API: [Fluent documentation](https://forgenet.gitbook.io/fluent-documentation).
