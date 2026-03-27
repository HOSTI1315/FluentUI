--[[
	SkrilyaHub — пример хаба с нативным автосохранением
	Executor-only: loadstring + HttpGet

	Порядок:
		1. Загрузка FluentPlus (Fluent + InterfaceManager)
		2. Загрузка SkrilyaSaveManager
		3. Создание Window / Tabs / Elements
		4. SaveManager:Init(Fluent) — папки + хуки + авто-загрузка конфига
		5. BuildConfigSection — UI для ручного управления (опционально)
]]

local REPO = "https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main"

local Fluent, _, InterfaceManager = loadstring(game:HttpGet(
	REPO .. "/FluentPlus/Beta.lua", true
))()

local SaveManager = loadstring(game:HttpGet(
	REPO .. "/Addons/SkrilyaSaveManager.lua", true
))()

-- ── Window ──

local Window = Fluent:CreateWindow({
	Title    = "SkrilyaHub",
	SubTitle = "v1.0",
	Search   = true,
	TabWidth = 160,
	Size     = UDim2.fromOffset(580, 460),
	Acrylic  = true,
	Theme    = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

-- ── Tabs ──

local Tabs = {
	Main     = Window:AddTab({ Title = "Main",     Icon = "home" }),
	Combat   = Window:AddTab({ Title = "Combat",   Icon = "swords" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

-- ── Main tab ──

do
	local section = Tabs.Main:AddSection("General", "zap")

	section:AddToggle("ESP", {
		Title = "ESP",
		Default = false,
		Callback = function(v)
			-- логика ESP
		end,
	})

	section:AddSlider("FOV", {
		Title   = "FOV Radius",
		Default = 120,
		Min     = 30,
		Max     = 800,
		Rounding = 0,
		Callback = function(v)
			-- обновить FOV-circle
		end,
	})

	section:AddDropdown("ESPMode", {
		Title   = "ESP Mode",
		Values  = { "Box", "Corner", "Highlight" },
		Default = 1,
	})
end

-- ── Combat tab ──

do
	local section = Tabs.Combat:AddSection("Aimbot", "crosshair")

	section:AddToggle("Aimbot", {
		Title = "Aimbot",
		Default = false,
	})

	section:AddSlider("Smoothness", {
		Title    = "Smoothness",
		Default  = 5,
		Min      = 1,
		Max      = 20,
		Rounding = 1,
	})

	section:AddDropdown("AimPart", {
		Title   = "Aim Part",
		Values  = { "Head", "HumanoidRootPart", "Torso" },
		Default = 1,
	})
end

-- ── Settings tab: InterfaceManager + SaveManager ──

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("SkrilyaHub")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- Init: создаёт SkrilyaHub/<GameName>/settings/, ставит хуки,
-- загружает active_config (или создаёт default при первом запуске)
SaveManager:Init(Fluent)

-- UI для ручного создания / загрузки / удаления конфигов
SaveManager:BuildConfigSection(Tabs.Settings)

-- ── Готово ──

Window:SelectTab(1)

Fluent:Notify({
	Title    = "SkrilyaHub",
	Content  = "Hub loaded",
	SubContent = "Game: " .. (SaveManager.GameName or "?"),
	Duration = 5,
})
