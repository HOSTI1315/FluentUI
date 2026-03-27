# FluentPlus + SkrilyaHub

Roblox **executor** UI library (Luau): extended [Fluent](https://github.com/dawid-scripts/Fluent) with multi-column layout, horizontal button rows, optional key gate, status bar, and **SkrilyaSaveManager** -- native auto-save config system for SkrilyaHub.

---

## For AI assistants (read first)

This section is **grounding context**. Use it when generating, refactoring, or debugging hub scripts that target this repository.

### Core facts

| Item | Value |
|------|-------|
| Domain | Roblox client; Luau; third-party **executor** with HTTP + file APIs |
| Hub name | **SkrilyaHub** |
| Primary ship file | [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua) (monolithic, returns 4 values) |
| Config module | [`Addons/SkrilyaSaveManager.lua`](Addons/SkrilyaSaveManager.lua) -- native auto-save, auto-detect game, zero-friction |
| Legacy config (do NOT use for new scripts) | `Addons/SaveManager.lua` -- standard Fluent fork, requires manual config creation |
| Interface settings | [`Addons/InterfaceManager.lua`](Addons/InterfaceManager.lua) (theme, acrylic, keybind) |
| Reference implementation | [`SkrilyaHub.lua`](SkrilyaHub.lua) -- full example hub with SkrilyaSaveManager |
| Legacy example | [`FluentPlus/Example.lua`](FluentPlus/Example.lua) -- uses old SaveManager |
| `Beta.lua` return | `return Library, SaveManager, InterfaceManager, Mobile` -- the bundled SaveManager is the **old** one; for SkrilyaHub always load `SkrilyaSaveManager.lua` separately |
| GitHub repo | `https://github.com/HOSTI1315/FluentUI` |
| Raw base URL | `https://raw.githubusercontent.com/HOSTI1315/FluentUI/main` |

### Rules (violating these breaks the script)

1. **`CreateKeySystem` before `CreateWindow`** -- key modal blocks until success; window must not exist yet.
2. **One window per session** -- second `CreateWindow` call is rejected.
3. **SkrilyaSaveManager requires executor FS**: `writefile`, `readfile`, `isfile`, `isfolder`, `makefolder`, `listfiles`, `delfile`.
4. **`SaveManager:Init(Fluent)` after all UI elements** -- it wraps `SetValue` on every registered option and on options added later (via `__newindex` metatable on `Fluent.Options`).
5. **Stable string keys** -- `AddToggle("MyToggle", ...)`, `AddSlider("MySlider", ...)` etc. These keys are used as JSON field identifiers in config files. Changing them breaks existing saves.

### Loading pattern (use this in every new script)

```lua
local REPO = "https://raw.githubusercontent.com/HOSTI1315/FluentUI/main"

local Fluent, _, InterfaceManager = loadstring(game:HttpGet(
	REPO .. "/FluentPlus/Beta.lua", true
))()

local SaveManager = loadstring(game:HttpGet(
	REPO .. "/Addons/SkrilyaSaveManager.lua", true
))()
```

The second return value (`_`) is the **old** bundled SaveManager -- discard it. `SkrilyaSaveManager.lua` replaces it entirely.

### Minimal complete script skeleton

```lua
local REPO = "https://raw.githubusercontent.com/HOSTI1315/FluentUI/main"

local Fluent, _, InterfaceManager = loadstring(game:HttpGet(
	REPO .. "/FluentPlus/Beta.lua", true
))()

local SaveManager = loadstring(game:HttpGet(
	REPO .. "/Addons/SkrilyaSaveManager.lua", true
))()

-- (Optional) Key system -- must be BEFORE CreateWindow
-- Fluent:CreateKeySystem({ Title = "SkrilyaHub", Key = "mykey", SaveKey = true, FolderName = "SkrilyaHub" })

local Window = Fluent:CreateWindow({
	Title    = "SkrilyaHub",
	SubTitle = "v1.0",
	Size     = UDim2.fromOffset(580, 460),
	Theme    = "Dark",
	Acrylic  = true,
	Search   = true,
	TabWidth = 160,
})

-- (Optional) Status bar
-- Fluent:CreateStatusBar({ FPS = true, Ping = true })

local Tabs = {
	Main     = Window:AddTab({ Title = "Main",     Icon = "home" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

-- Add elements with STABLE string keys
local Section = Tabs.Main:AddSection("Features", "zap")
Section:AddToggle("ESP", { Title = "ESP", Default = false })
Section:AddSlider("FOV", { Title = "FOV", Default = 120, Min = 30, Max = 800, Rounding = 0 })
Section:AddDropdown("ESPMode", { Title = "Mode", Values = { "Box", "Corner" }, Default = 1 })

-- InterfaceManager: theme / acrylic / keybind UI
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("SkrilyaHub")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- SkrilyaSaveManager: one call does everything
--   1. Creates SkrilyaHub/<GameName>/settings/
--   2. Wraps SetValue on all options for autosave
--   3. Loads active_config.txt or creates "default" config
SaveManager:Init(Fluent)

-- (Optional) Manual config UI: create / load / delete / overwrite
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
```

### Execution order (critical)

```
1. loadstring Beta.lua          -> Fluent, InterfaceManager
2. loadstring SkrilyaSaveManager.lua -> SaveManager
3. (optional) CreateKeySystem   -> blocks until key valid
4. CreateWindow                 -> one per session
5. AddTab / AddSection / Add*   -> register all UI elements
6. InterfaceManager:SetLibrary + SetFolder + BuildInterfaceSection
7. SaveManager:Init(Fluent)     -> folders + hooks + auto-load config
8. SaveManager:BuildConfigSection(tab)  -> optional manual config UI
9. Window:SelectTab(1)
```

---

## SkrilyaSaveManager -- API reference

File: [`Addons/SkrilyaSaveManager.lua`](Addons/SkrilyaSaveManager.lua)

Replaces the standard Fluent `SaveManager`. Designed for SkrilyaHub: auto-detects game name, creates folder tree on inject, creates a default config on first run, auto-saves on every option change.

### Disk structure

```
SkrilyaHub/                              <-- HUB_ROOT (always "SkrilyaHub")
  options.json                           <-- InterfaceManager (theme, keybind)
  <GameName>/                            <-- auto-detected via MarketplaceService
    settings/
      default.json                       <-- auto-created on first inject
      active_config.txt                  <-- name of current config
      <user_config>.json                 <-- user-created configs
```

Game name is resolved as: `MarketplaceService:GetProductInfo(game.PlaceId).Name` -> sanitized (strip special chars, max 64 chars) -> fallback to `game.Name` -> fallback to `tostring(game.PlaceId)`.

### Methods

| Method | When to call | Description |
|--------|-------------|-------------|
| `Init(library)` | After all UI elements created | **Main entry point.** Calls SetLibrary, IgnoreThemeSettings, BuildFolderTree, installs autosave hooks, loads active config or creates "default". |
| `BuildConfigSection(tab)` | After Init | Adds UI section: input for config name, dropdown for config list, buttons for create/load/overwrite/delete/refresh. |
| `Save(name?)` | Anytime | Serializes all options to JSON. If `name` is nil, saves to active config or "default". |
| `Load(name?)` | Anytime | Reads JSON, applies values via `SetValue`. Suppresses autosave during load. If `name` is nil, loads active config. |
| `Delete(name)` | Anytime | Removes config file from disk. |
| `GetActiveConfig()` | Anytime | Returns name from cache or `active_config.txt`. |
| `SetActiveConfig(name)` | Anytime | Writes name to `active_config.txt`. |
| `SetLibrary(library)` | Before Init or standalone | Links `Fluent.Options` to SaveManager. |
| `SetAutosaveEnabled(bool)` | Anytime | Enable/disable autosave (default: true). |
| `SetIgnoreIndexes(list)` | Before Init or anytime | Skip specific option keys from save/load. |
| `IgnoreThemeSettings()` | Called automatically by Init | Ignores InterfaceTheme, AcrylicToggle, TransparentToggle, MenuKeybind. |
| `BuildFolderTree()` | Called automatically by Init | Creates `SkrilyaHub/<GameName>/settings/` with isfolder/makefolder checks. |
| `RefreshConfigList()` | Used by BuildConfigSection | Returns array of config names from settings folder. |
| `GameName` | After Init | String: detected game name. |
| `Folder` | After Init | String: `"SkrilyaHub/<GameName>"`. |

### Autosave mechanism

1. `Init()` calls `_installHooks()` which wraps `SetValue` (and `SetValueRGB` for Colorpicker) on every option in `Fluent.Options`.
2. A `__newindex` metatable is set on `Fluent.Options` so options registered after Init are also wrapped.
3. Every `SetValue` call triggers `_scheduleAutosave()` -- a debounced (0.35s) save to the active config file.
4. During `Load()`, `_suppressSave` is set to `true` to prevent the load from triggering cascading saves.
5. Token-based debounce: rapid slider movements only trigger one save after the user stops.

### Supported element types (Parser)

| Type | Saved fields | Restore method |
|------|-------------|----------------|
| Toggle | `value` (boolean) | `SetValue(bool)` |
| Slider | `value` (string of number) | `SetValue(number)` |
| Dropdown | `value`, `multi` | `SetValue(value)` |
| Colorpicker | `value` (hex), `transparency` | `SetValueRGB(Color3, transparency)` |
| Keybind | `key`, `mode` | `SetValue(key, mode)` |
| Input | `text` (string) | `SetValue(string)` |

---

## FluentPlus -- API reference

Methods on the `Library` / `Fluent` object returned by `Beta.lua`.

### Library-level

| Method | When | Notes |
|--------|------|-------|
| `CreateKeySystem(config)` | Before CreateWindow | Blocking modal. Fields: `Title`, `Subtitle`, `Key` or `Keys`, `SaveKey`, `FolderName`, `Note`, `URL`, `URLText`. Returns boolean. |
| `CreateWindow(config)` | Once per session | `Title`, `SubTitle`, `Size`, `Theme`, `Acrylic`, `TabWidth`, `Search`, `MinimizeKey`, `UserInfo`, `UserInfoTitle`, `UserInfoSubtitle`, `UserInfoSubtitleColor`, `UserInfoTop`, `Image`, `BackgroundImage`, `BackgroundTransparency`, `BackgroundImageTransparency`, `DropdownsOutsideWindow`. |
| `CreateStatusBar(config)` | After window | `FPS` (bool), `Ping` (bool), `Fields = { { Name = "..." } }`, `Position`, `AnchorPoint`. Returns `:SetField(name, value)`, `:SetVisible(bool)`, `:Destroy()`. |
| `CreateMinimizer(config)` | After window | `Icon`, `Size`, `Position`, `Acrylic`, `Corner`, `Transparency`, `Draggable`, `Visible`. |
| `Notify({ Title, Content, SubContent?, Duration? })` | Anytime | Toast notification. |
| `SetTheme(name)` | Anytime | Apply a theme by name. |
| `Options` | Read anytime | `Fluent.Options["MyToggle"]` -- table of all registered controls by string key. |

### Tab

| Method | Description |
|--------|-------------|
| `Window:AddTab({ Title, Icon })` | Icon = Lucide short name (e.g. `"home"`, `"settings"`, `"swords"` -- no `lucide-` prefix). |
| `Tab:AddSection(title, icon?)` | Vertical section inside a tab. |
| `Tab:AddRow(n)` | FluentPlus: `n` clamped 1-4. Returns array of column objects; each has `AddSection` and all `Add*` methods. |
| `Tab:AddSubTab(title, icon?)` | Horizontal sub-tabs inside a tab. |
| `Tab:AddParagraph({ Icon?, Title, Content })` | Static paragraph on tab. |

### Section / Column

| Method | Key arguments |
|--------|---------------|
| `AddToggle(idx, { Title, Description?, Default?, Callback? })` | `Default`: boolean |
| `AddSlider(idx, { Title, Description?, Default, Min, Max, Rounding, Callback? })` | All numeric fields required |
| `AddDropdown(idx, { Title, Description?, Values, Default?, Multi?, AllowNull?, Callback? })` | `Values`: array of strings; `Default`: index or string |
| `AddInput(idx, { Title, Description?, Default?, Placeholder?, Numeric?, Finished?, MaxLength?, Callback? })` | |
| `AddKeybind(idx, { Title, Description?, Default, Mode?, Callback?, ChangedCallback? })` | `Mode`: "Toggle" / "Hold" / "Always" |
| `AddColorpicker(idx, { Title, Description?, Default, Transparency?, Callback? })` | `Default`: Color3 |
| `AddButton({ Title, Description?, Callback })` | No `idx` -- buttons are not saved. |
| `AddButtonRow({ { Title, Callback }, ... })` | FluentPlus: horizontal row of 2+ buttons. |

Every `Add*` method with `idx` registers the control in `Fluent.Options[idx]`. The idx string must be stable across sessions for config persistence.

### Element return objects

All `Add*(idx, config)` calls return an object with:

| Method | Description |
|--------|-------------|
| `:SetValue(value)` | Programmatically change value (triggers Callback + Changed + autosave). |
| `:OnChanged(func)` | Register secondary listener; called immediately with current value. |
| `:SetTitle(text)` | Update display title. |
| `:SetDesc(text)` | Update description. |
| `:Destroy()` | Remove from UI and `Fluent.Options`. |
| `.Value` | Current value (read). |

### InterfaceManager

| Method | Purpose |
|--------|---------|
| `SetLibrary(Fluent)` | Required. |
| `SetFolder(path)` | Where `options.json` lives. For SkrilyaHub use `"SkrilyaHub"`. |
| `BuildInterfaceSection(tab)` | Adds theme dropdown, acrylic toggle, transparency, minimize keybind. |

InterfaceManager persists to `<folder>/options.json` (separate from SkrilyaSaveManager configs).

---

## Themes

Dark, Darker, AMOLED, Light, Balloon, SoftCream, Aqua, Amethyst, Rose, Midnight, Forest, Sunset, Ocean, Emerald, Sapphire, Cloud, Grape, Bloody, Arctic.

Authoritative list: `Themes.Names` inside `Beta.lua`.

---

## Repository layout

| Path | Role |
|------|------|
| [`FluentPlus/Beta.lua`](FluentPlus/Beta.lua) | Monolithic library: window, tabs, elements, StatusBar, KeySystem, AddRow, AddButtonRow, bundled old managers. |
| [`Addons/SkrilyaSaveManager.lua`](Addons/SkrilyaSaveManager.lua) | **SkrilyaHub native config system** -- auto-detect game, auto-create folders, auto-save on every change. |
| [`Addons/InterfaceManager.lua`](Addons/InterfaceManager.lua) | Theme / acrylic / keybind persistence. |
| [`Addons/SaveManager.lua`](Addons/SaveManager.lua) | Legacy Fluent-compatible SaveManager (do not use for new SkrilyaHub scripts). |
| [`SkrilyaHub.lua`](SkrilyaHub.lua) | Full example hub using SkrilyaSaveManager. |
| [`FluentPlus/Example.lua`](FluentPlus/Example.lua) | Legacy example using old SaveManager. |
| [`Fluent/`](Fluent/) | Upstream modular sources (Rojo); reference only. |

---

## Executor requirements

| API | Required by |
|-----|-------------|
| `game:HttpGet(url, true)` | Loading Beta.lua and addons |
| `writefile(path, content)` | SkrilyaSaveManager, InterfaceManager |
| `readfile(path)` | SkrilyaSaveManager, InterfaceManager |
| `isfile(path)` | SkrilyaSaveManager, InterfaceManager |
| `isfolder(path)` | SkrilyaSaveManager |
| `makefolder(path)` | SkrilyaSaveManager |
| `listfiles(path)` | SkrilyaSaveManager (config list) |
| `delfile(path)` | SkrilyaSaveManager (delete config) |

---

## Differences: SkrilyaSaveManager vs standard SaveManager

| Feature | Standard SaveManager | SkrilyaSaveManager |
|---------|---------------------|-------------------|
| Folder setup | Manual: `SetFolder("path")` | Automatic: `SkrilyaHub/<GameName>/settings/` |
| Game detection | None (hardcoded path) | `MarketplaceService:GetProductInfo` with sanitization and fallback |
| First-run config | User must manually create | Auto-creates "default" config |
| Auto-load on inject | Requires `autoload.txt` + manual `LoadAutoloadConfig()` | Automatic via `active_config.txt` in `Init()` |
| Autosave trigger | Requires `BuildConfigSection` to install hooks | `Init()` installs hooks immediately |
| Entry point | Multiple calls: SetLibrary, SetFolder, IgnoreThemeSettings, BuildConfigSection, LoadAutoloadConfig | Single call: `Init(Fluent)` |
| Save without name | Error | Defaults to active config or "default" |
| Delete config | Not supported | `Delete(name)` |
| Debounce delay | 0.28s | 0.35s |
