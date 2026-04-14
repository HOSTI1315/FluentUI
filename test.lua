--[[
	SkrilyaLib v1.1 — Universal UI Library for Roblox
	Visual overhaul: depth, gradients, varied radii, premium feel
]]

-- // 1. CLEANUP & INIT
if getgenv and getgenv()._SkrilyaUI then
	pcall(function() getgenv()._SkrilyaUI:Destroy() end)
end
if getgenv then getgenv()._SkrilyaRunning = true end

local SkrilyaLib = {}
SkrilyaLib.Flags = {}
SkrilyaLib.Options = {}
SkrilyaLib._version = "1.1.0"

-- // 2. SERVICES & CONSTANTS
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local function safeService(n)
	local ok, svc = pcall(function()
		return (typeof(cloneref) == "function" and cloneref or function(x) return x end)(game:GetService(n))
	end)
	return ok and svc or nil
end

local MarketplaceService = safeService("MarketplaceService")
local StatsService = safeService("Stats")

-- Internal state
local _themed = {}
local _connections = {}
local _threads = {}
local _currentTheme = "Dark"
local _rootFolder = "SkrilyaHub"
local _gameName = "Unknown"
local _autoSave = false
local _autoSaveTask = nil
local _isLoadingConfig = false
local _activeConfig = nil
local _windowRef = nil
local _unloadCallbacks = {}
local _notifContainer = nil
local _screenGui = nil

pcall(function()
	if MarketplaceService then
		_gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name or "Unknown"
	end
end)

-- // 2b. ASSETS & FONTS (Inter font + image-based controls like MacLib)
local InterFont = "rbxassetid://12187365364"
local Assets = {
	toggleBackground = "rbxassetid://18772190202",
	togglerHead = "rbxassetid://18772309008",
	sliderbar = "rbxassetid://18772615246",
	sliderhead = "rbxassetid://18772834246",
	dropdown = "rbxassetid://18865373378",
	searchIcon = "rbxassetid://86737463322606",
}

-- Deferred callback wrapper (prevents lag on heavy callbacks)
local function _sd(fn)
	return function(...)
		local a = {...}
		task.defer(function() fn(unpack(a)) end)
	end
end

-- Font helpers (Inter with weight variants)
local function FontRegular()
	return Font.new(InterFont, Enum.FontWeight.Regular)
end
local function FontMedium()
	return Font.new(InterFont, Enum.FontWeight.Medium)
end
local function FontSemibold()
	return Font.new(InterFont, Enum.FontWeight.SemiBold)
end
local function FontBold()
	return Font.new(InterFont, Enum.FontWeight.Bold)
end

-- // 3. THEMES (enhanced with more granular tokens)
local Themes = {
	Dark = {
		Background = Color3.fromRGB(18, 18, 24),
		SecondaryBackground = Color3.fromRGB(24, 24, 32),
		TertiaryBackground = Color3.fromRGB(32, 32, 42),
		QuaternaryBackground = Color3.fromRGB(38, 38, 50),
		Accent = Color3.fromRGB(98, 112, 255),
		AccentDark = Color3.fromRGB(72, 82, 200),
		AccentGlow = Color3.fromRGB(120, 132, 255),
		TextPrimary = Color3.fromRGB(245, 245, 250),
		TextSecondary = Color3.fromRGB(160, 162, 178),
		TextDimmed = Color3.fromRGB(88, 90, 108),
		Divider = Color3.fromRGB(42, 42, 56),
		Success = Color3.fromRGB(72, 220, 120),
		Warning = Color3.fromRGB(245, 210, 72),
		Error = Color3.fromRGB(230, 60, 65),
		Border = Color3.fromRGB(50, 50, 68),
		BorderLight = Color3.fromRGB(58, 58, 78),
		ToggleOff = Color3.fromRGB(52, 52, 66),
		ToggleOffBorder = Color3.fromRGB(62, 62, 78),
		SliderBg = Color3.fromRGB(42, 42, 56),
		ShadowColor = Color3.fromRGB(0, 0, 0),
		HoverOverlay = Color3.fromRGB(255, 255, 255),
		Font = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
		FontBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),
		FontSemibold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
	},
	Light = {
		Background = Color3.fromRGB(245, 245, 250),
		SecondaryBackground = Color3.fromRGB(252, 252, 255),
		TertiaryBackground = Color3.fromRGB(235, 235, 242),
		QuaternaryBackground = Color3.fromRGB(225, 225, 235),
		Accent = Color3.fromRGB(88, 101, 242),
		AccentDark = Color3.fromRGB(68, 80, 210),
		AccentGlow = Color3.fromRGB(120, 132, 255),
		TextPrimary = Color3.fromRGB(16, 16, 28),
		TextSecondary = Color3.fromRGB(80, 82, 100),
		TextDimmed = Color3.fromRGB(140, 142, 160),
		Divider = Color3.fromRGB(215, 215, 228),
		Success = Color3.fromRGB(52, 190, 95),
		Warning = Color3.fromRGB(215, 180, 50),
		Error = Color3.fromRGB(210, 45, 48),
		Border = Color3.fromRGB(205, 205, 220),
		BorderLight = Color3.fromRGB(215, 215, 230),
		ToggleOff = Color3.fromRGB(185, 185, 198),
		ToggleOffBorder = Color3.fromRGB(175, 175, 188),
		SliderBg = Color3.fromRGB(200, 200, 215),
		ShadowColor = Color3.fromRGB(0, 0, 0),
		HoverOverlay = Color3.fromRGB(0, 0, 0),
		Font = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
		FontBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold),
		FontSemibold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium),
	},
}

local function theme()
	return Themes[_currentTheme] or Themes.Dark
end

-- // 4. UTILITY FUNCTIONS
local function Tween(inst, info, props)
	local ok = pcall(function()
		TweenService:Create(inst, info, props):Play()
	end)
	if not ok then
		pcall(function()
			for k, v in pairs(props) do inst[k] = v end
		end)
	end
end

local TI_SNAP = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_MED = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_SLOW = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function GetGui()
	local gui = Instance.new("ScreenGui")
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	local ok = pcall(function()
		if typeof(gethui) == "function" then
			gui.Parent = gethui()
		else
			gui.Parent = game:GetService("CoreGui")
		end
	end)
	if not ok then
		pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
	end
	return gui
end

local function CreateCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function CreatePadding(parent, t, b, l, r)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or 0)
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or 0)
	p.Parent = parent
	return p
end

local function CreateStroke(parent, color, thickness, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or theme().Border
	s.Thickness = thickness or 1
	s.Transparency = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function CreateList(parent, padding, direction, hAlign)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 4)
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

-- Creates a subtle inner top gradient to simulate depth/light
local function CreateInnerGlow(parent, color, direction)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color or Color3.new(1, 1, 1), color or Color3.new(1, 1, 1))
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(0.08, 0.97),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Rotation = direction or 90
	g.Parent = parent
	return g
end

-- Creates a soft shadow behind a frame (uses layered frames)
local function CreateShadow(parent, radius, spread, transparency)
	spread = spread or 8
	transparency = transparency or 0.7
	local shadow = Instance.new("Frame")
	shadow.Name = "_Shadow"
	shadow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
	shadow.Position = UDim2.fromOffset(-spread, -spread + 2)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = transparency
	shadow.BorderSizePixel = 0
	shadow.ZIndex = parent.ZIndex - 1
	CreateCorner(shadow, (radius or 12) + 4)
	shadow.Parent = parent.Parent
	-- Second softer layer
	local shadow2 = Instance.new("Frame")
	shadow2.Name = "_Shadow2"
	shadow2.Size = UDim2.new(1, spread * 4, 1, spread * 4)
	shadow2.Position = UDim2.fromOffset(-spread * 2, -spread * 2 + 4)
	shadow2.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow2.BackgroundTransparency = transparency + 0.15
	shadow2.BorderSizePixel = 0
	shadow2.ZIndex = parent.ZIndex - 2
	CreateCorner(shadow2, (radius or 12) + 8)
	shadow2.Parent = parent.Parent
	return shadow
end

local function MakeDraggable(handle, frame)
	local dragging, dragStart, startPos = false, nil, nil
	local conn1, conn2
	conn1 = handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	conn2 = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	table.insert(_connections, conn1)
	table.insert(_connections, conn2)
end

local function RippleEffect(button, position)
	pcall(function()
		local ripple = Instance.new("Frame")
		ripple.Size = UDim2.fromOffset(0, 0)
		ripple.Position = UDim2.fromOffset(
			position.X - button.AbsolutePosition.X,
			position.Y - button.AbsolutePosition.Y
		)
		ripple.AnchorPoint = Vector2.new(0.5, 0.5)
		ripple.BackgroundColor3 = Color3.new(1, 1, 1)
		ripple.BackgroundTransparency = 0.8
		ripple.BorderSizePixel = 0
		CreateCorner(ripple, 999)
		ripple.Parent = button
		local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
		Tween(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1
		})
		task.delay(0.5, function() pcall(function() ripple:Destroy() end) end)
	end)
end

-- Accent gradient helper: creates a subtle gradient on accent-colored elements
local function ApplyAccentGradient(parent)
	local t = theme()
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 225)),
	})
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- // 5. THEME MANAGER
local function registerThemed(inst, prop, key)
	table.insert(_themed, {inst = inst, prop = prop, key = key})
end

local function applyThemeAll()
	local t = theme()
	for _, entry in ipairs(_themed) do
		pcall(function()
			if entry.inst and entry.inst.Parent then
				entry.inst[entry.prop] = t[entry.key]
			end
		end)
	end
end

function SkrilyaLib:SetTheme(name)
	if Themes[name] then
		_currentTheme = name
		applyThemeAll()
	end
end

function SkrilyaLib:AddTheme(name, data)
	Themes[name] = data
end

-- // 6. NOTIFICATION SYSTEM
local _notificationsEnabled = true

function SkrilyaLib:SetNotificationsEnabled(v)
	_notificationsEnabled = v
end

function SkrilyaLib:GetNotificationsEnabled()
	return _notificationsEnabled
end

function SkrilyaLib:Notify(config)
	if not _notifContainer or not _notificationsEnabled then return end
	local t = theme()
	local typeColors = {
		Success = t.Success,
		Warning = t.Warning,
		Error = t.Error,
		Info = t.Accent,
	}
	local color = typeColors[config.Type] or t.Accent
	local duration = config.Duration or 5

	-- Outer wrapper for shadow
	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 0)
	notif.AutomaticSize = Enum.AutomaticSize.Y
	notif.BackgroundColor3 = t.SecondaryBackground
	notif.BorderSizePixel = 0
	notif.Position = UDim2.new(1, 20, 0, 0)
	notif.ClipsDescendants = true
	CreateCorner(notif, 10)
	CreateStroke(notif, t.Border, 1, 0.3)
	registerThemed(notif, "BackgroundColor3", "SecondaryBackground")

	-- Colored accent strip on left
	local accentStrip = Instance.new("Frame")
	accentStrip.Name = "AccentStrip"
	accentStrip.Size = UDim2.new(0, 3, 1, 0)
	accentStrip.BackgroundColor3 = color
	accentStrip.BorderSizePixel = 0
	accentStrip.Parent = notif

	-- Content area
	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -3, 0, 0)
	contentFrame.Position = UDim2.fromOffset(3, 0)
	contentFrame.AutomaticSize = Enum.AutomaticSize.Y
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = notif
	CreatePadding(contentFrame, 10, 10, 12, 12)
	CreateList(contentFrame, 4)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 18)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = config.Title or "Notification"
	titleLbl.TextColor3 = t.TextPrimary
	titleLbl.FontFace = t.FontBold
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.LayoutOrder = 1
	titleLbl.Parent = contentFrame
	registerThemed(titleLbl, "TextColor3", "TextPrimary")

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, 0, 0, 0)
	descLbl.AutomaticSize = Enum.AutomaticSize.Y
	descLbl.BackgroundTransparency = 1
	descLbl.Text = config.Description or ""
	descLbl.TextColor3 = t.TextSecondary
	descLbl.FontFace = t.Font
	descLbl.TextSize = 12
	descLbl.TextWrapped = true
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.LayoutOrder = 2
	descLbl.Parent = contentFrame
	registerThemed(descLbl, "TextColor3", "TextSecondary")

	-- Progress bar at bottom
	local progBar = Instance.new("Frame")
	progBar.Size = UDim2.new(1, 0, 0, 2)
	progBar.BackgroundColor3 = color
	progBar.BackgroundTransparency = 0.5
	progBar.BorderSizePixel = 0
	progBar.Position = UDim2.new(0, 0, 1, -2)
	progBar.Parent = notif

	notif.Parent = _notifContainer
	Tween(notif, TI_MED, {Position = UDim2.new(0, 0, 0, 0)})

	-- Animate progress bar
	task.spawn(function()
		pcall(function()
			Tween(progBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(0, 0, 0, 2)
			})
		end)
	end)

	local alive = true
	local dismissThread

	local function dismiss()
		if not alive then return end
		alive = false
		pcall(function()
			Tween(notif, TI_MED, {Position = UDim2.new(1, 20, 0, 0)})
			task.wait(0.35)
			notif:Destroy()
		end)
	end

	local function resetTimer(dur)
		if dismissThread then pcall(function() task.cancel(dismissThread) end) end
		dismissThread = task.delay(dur, dismiss)
	end

	resetTimer(duration)

	return {
		UpdateTitle = function(_, text)
			if alive then pcall(function() titleLbl.Text = text end) end
		end,
		UpdateDescription = function(_, text)
			if alive then pcall(function() descLbl.Text = text end) end
		end,
		SetDuration = function(_, dur)
			if alive then resetTimer(dur) end
		end,
		Close = function()
			dismiss()
		end,
	}
end

-- // 7. CONFIG MANAGER
local function ensureFolder(path)
	local parts = string.split(path, "/")
	local current = ""
	for _, part in ipairs(parts) do
		current = current == "" and part or (current .. "/" .. part)
		pcall(function()
			if not isfolder(current) then makefolder(current) end
		end)
	end
end

local function configPath(name)
	return _rootFolder .. "/" .. _gameName .. "/settings/" .. name .. ".json"
end

local function activeConfigPath()
	return _rootFolder .. "/" .. _gameName .. "/settings/active_config.txt"
end

local ClassParser = {
	Toggle = {
		save = function(flag, value) return {type = "Toggle", value = value} end,
		load = function(data) return data.value == true end,
	},
	Slider = {
		save = function(flag, value) return {type = "Slider", value = value} end,
		load = function(data) return tonumber(data.value) end,
	},
	Dropdown = {
		save = function(flag, value) return {type = "Dropdown", value = value} end,
		load = function(data) return data.value end,
	},
	Input = {
		save = function(flag, value) return {type = "Input", value = value} end,
		load = function(data) return tostring(data.value or "") end,
	},
	Keybind = {
		save = function(flag, value)
			return {type = "Keybind", value = value and value.Name or "Unknown"}
		end,
		load = function(data)
			local ok, key = pcall(function() return Enum.KeyCode[data.value] end)
			return ok and key or nil
		end,
	},
	Colorpicker = {
		save = function(flag, value)
			return {type = "Colorpicker", value = {R = math.floor(value.R * 255), G = math.floor(value.G * 255), B = math.floor(value.B * 255)}}
		end,
		load = function(data)
			local v = data.value
			return Color3.fromRGB(v.R or 255, v.G or 255, v.B or 255)
		end,
	},
}

function SkrilyaLib:SetFolder(folder)
	_rootFolder = folder
end

function SkrilyaLib:SaveConfig(name)
	local path = configPath(name)
	ensureFolder(_rootFolder .. "/" .. _gameName .. "/settings")
	local data = {}
	for flag, value in pairs(SkrilyaLib.Flags) do
		local opt = SkrilyaLib.Options[flag]
		if opt and opt._type and ClassParser[opt._type] then
			data[flag] = ClassParser[opt._type].save(flag, value)
		end
	end
	pcall(function()
		writefile(path, HttpService:JSONEncode(data))
	end)
end

function SkrilyaLib:LoadConfig(name)
	local path = configPath(name)
	local ok, content = pcall(function() return readfile(path) end)
	if not ok or not content then return false end
	local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok2 or not data then return false end
	_isLoadingConfig = true
	for flag, entry in pairs(data) do
		local opt = SkrilyaLib.Options[flag]
		if opt and entry.type and ClassParser[entry.type] then
			local value = ClassParser[entry.type].load(entry)
			if value ~= nil then
				pcall(function() opt:SetValue(value) end)
			end
		end
	end
	_isLoadingConfig = false
	_activeConfig = name
	return true
end

function SkrilyaLib:DeleteConfig(name)
	pcall(function() delfile(configPath(name)) end)
end

function SkrilyaLib:GetConfigList()
	local list = {}
	pcall(function()
		local folder = _rootFolder .. "/" .. _gameName .. "/settings"
		if isfolder(folder) then
			for _, file in ipairs(listfiles(folder)) do
				local name = file:match("([^/\\]+)%.json$")
				if name then table.insert(list, name) end
			end
		end
	end)
	return list
end

function SkrilyaLib:LoadAutoLoadConfig()
	pcall(function()
		local path = activeConfigPath()
		if isfile(path) then
			local name = readfile(path)
			if name and name ~= "" then
				SkrilyaLib:LoadConfig(name)
			end
		end
	end)
end

function SkrilyaLib:SetAutoLoad(name)
	ensureFolder(_rootFolder .. "/" .. _gameName .. "/settings")
	pcall(function() writefile(activeConfigPath(), name) end)
end

function SkrilyaLib:SetAutoSave(enabled)
	_autoSave = enabled
end

local function triggerAutoSave()
	if not _autoSave or _isLoadingConfig or not _activeConfig then return end
	if _autoSaveTask then pcall(function() task.cancel(_autoSaveTask) end) end
	_autoSaveTask = task.delay(0.4, function()
		SkrilyaLib:SaveConfig(_activeConfig)
		_autoSaveTask = nil
	end)
end

local function registerFlag(flag, value, obj)
	if not flag then return end
	SkrilyaLib.Flags[flag] = value
	SkrilyaLib.Options[flag] = obj
end

local function updateFlag(flag, value)
	if not flag then return end
	SkrilyaLib.Flags[flag] = value
	triggerAutoSave()
end

-- // 8. KEY SYSTEM
function SkrilyaLib:CreateKeySystem(config)
	local keys = config.Keys or {}
	local saveKey = config.SaveKey
	local fileName = config.FileName or "SkrilyaHub_Key.txt"

	if saveKey then
		local ok, saved = pcall(function() return readfile(_rootFolder .. "/" .. fileName) end)
		if ok and saved then
			for _, k in ipairs(keys) do
				if saved == k then
					if config.Callback then pcall(config.Callback, true) end
					return true
				end
			end
		end
	end

	local t = theme()
	local gui = GetGui()
	gui.Name = "SkrilyaKeySystem"
	gui.DisplayOrder = 999

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(380, 260)
	box.Position = UDim2.new(0.5, -190, 0.5, -130)
	box.BackgroundColor3 = t.Background
	box.BorderSizePixel = 0
	CreateCorner(box, 14)
	CreateStroke(box, t.Border, 1, 0.2)
	box.Parent = gui

	-- Subtle top glow
	local topGlow = Instance.new("Frame")
	topGlow.Size = UDim2.new(1, 0, 0, 60)
	topGlow.BackgroundColor3 = t.Accent
	topGlow.BackgroundTransparency = 0.92
	topGlow.BorderSizePixel = 0
	CreateCorner(topGlow, 14)
	topGlow.Parent = box

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 26)
	titleLbl.Position = UDim2.fromOffset(0, 32)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = config.Title or "Key System"
	titleLbl.TextColor3 = t.TextPrimary
	titleLbl.FontFace = t.FontBold
	titleLbl.TextSize = 18
	titleLbl.Parent = box

	if config.Note then
		local note = Instance.new("TextLabel")
		note.Size = UDim2.new(1, 0, 0, 16)
		note.Position = UDim2.fromOffset(0, 62)
		note.BackgroundTransparency = 1
		note.Text = config.Note
		note.TextColor3 = t.TextDimmed
		note.FontFace = t.Font
		note.TextSize = 12
		note.Parent = box
	end

	local inputBg = Instance.new("Frame")
	inputBg.Size = UDim2.new(0.78, 0, 0, 40)
	inputBg.Position = UDim2.new(0.11, 0, 0, 98)
	inputBg.BackgroundColor3 = t.TertiaryBackground
	inputBg.BorderSizePixel = 0
	CreateCorner(inputBg, 10)
	CreateStroke(inputBg, t.Border, 1, 0.3)
	inputBg.Parent = box

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -20, 1, 0)
	inputBox.Position = UDim2.fromOffset(10, 0)
	inputBox.BackgroundTransparency = 1
	inputBox.Text = ""
	inputBox.PlaceholderText = "KEY-XXXX-XXXX-XXXX"
	inputBox.PlaceholderColor3 = t.TextDimmed
	inputBox.TextColor3 = t.TextPrimary
	inputBox.FontFace = t.Font
	inputBox.TextSize = 14
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = inputBg

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, 0, 0, 16)
	statusLbl.Position = UDim2.fromOffset(0, 148)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = ""
	statusLbl.TextColor3 = t.Error
	statusLbl.FontFace = t.Font
	statusLbl.TextSize = 12
	statusLbl.Parent = box

	local verifyBtn = Instance.new("TextButton")
	verifyBtn.Size = UDim2.new(0.78, 0, 0, 40)
	verifyBtn.Position = UDim2.new(0.11, 0, 0, 174)
	verifyBtn.BackgroundColor3 = t.Accent
	verifyBtn.Text = "Проверить"
	verifyBtn.TextColor3 = t.TextPrimary
	verifyBtn.FontFace = t.FontBold
	verifyBtn.TextSize = 14
	verifyBtn.BorderSizePixel = 0
	CreateCorner(verifyBtn, 10)
	ApplyAccentGradient(verifyBtn)
	verifyBtn.Parent = box
	verifyBtn.ClipsDescendants = true

	local resolved = false
	verifyBtn.MouseButton1Click:Connect(function()
		if resolved then return end
		RippleEffect(verifyBtn, Vector2.new(Mouse.X, Mouse.Y))
		local entered = inputBox.Text
		local valid = false
		for _, k in ipairs(keys) do
			if entered == k then valid = true; break end
		end
		if valid then
			resolved = true
			statusLbl.Text = "✓ Ключ принят"
			statusLbl.TextColor3 = t.Success
			if saveKey then
				ensureFolder(_rootFolder)
				pcall(function() writefile(_rootFolder .. "/" .. fileName, entered) end)
			end
			task.wait(0.5)
			gui:Destroy()
			if config.Callback then pcall(config.Callback, true) end
		else
			statusLbl.Text = "✕ Неверный ключ"
			statusLbl.TextColor3 = t.Error
			-- Shake animation
			local orig = box.Position
			for i = 1, 3 do
				Tween(box, TI_SNAP, {Position = orig + UDim2.fromOffset(6, 0)})
				task.wait(0.04)
				Tween(box, TI_SNAP, {Position = orig + UDim2.fromOffset(-6, 0)})
				task.wait(0.04)
			end
			Tween(box, TI_SNAP, {Position = orig})
		end
	end)

	while not resolved do task.wait(0.1) end
	return true
end

-- // 9-20. WINDOW
function SkrilyaLib:Window(config)
	local t = theme()
	local Window = {}
	Window._tabs = {}
	Window._tabSections = {}
	Window._activeTab = nil
	Window._minimized = false
	Window._minimizerBtn = nil
	Window._statusBar = nil
	Window._loadingScreen = nil

	config = config or {}
	local winTitle = config.Title or "SkrilyaHub"
	local winSubtitle = config.Subtitle or ""
	local winSize = config.Size or UDim2.fromOffset(700, 510)
	local winTheme = config.Theme or "Dark"
	local minimizeKey = config.MinimizeKey or Enum.KeyCode.LeftControl
	local keyExpiration = config.KeyExpiration
	local notifyOnError = config.NotifyOnCallbackError or false

	if winTheme and Themes[winTheme] then
		_currentTheme = winTheme
		t = theme()
	end

	local gui = GetGui()
	gui.Name = "SkrilyaLibUI"
	_screenGui = gui
	if getgenv then getgenv()._SkrilyaUI = gui end

	-- Notification container
	_notifContainer = Instance.new("Frame")
	_notifContainer.Name = "NotifContainer"
	_notifContainer.Size = UDim2.fromOffset(300, 400)
	_notifContainer.Position = UDim2.new(1, -310, 0, 12)
	_notifContainer.BackgroundTransparency = 1
	_notifContainer.Parent = gui
	CreateList(_notifContainer, 8)

	-- ══════════════════════════════
	-- MAIN FRAME with shadow
	-- ══════════════════════════════
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = winSize
	mainFrame.Position = UDim2.new(0.5, -winSize.X.Offset / 2, 0.5, -winSize.Y.Offset / 2)
	mainFrame.BackgroundColor3 = t.Background
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	CreateCorner(mainFrame, 12)
	CreateStroke(mainFrame, t.Border, 1, 0.15)
	mainFrame.Parent = gui
	registerThemed(mainFrame, "BackgroundColor3", "Background")

	-- Drop shadow layers
	CreateShadow(mainFrame, 12, 10, 0.65)

	Window._mainFrame = mainFrame
	Window._gui = gui

	-- ══════════════════════════════
	-- TOPBAR — with subtle gradient
	-- ══════════════════════════════
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 46)
	topbar.BackgroundColor3 = t.SecondaryBackground
	topbar.BorderSizePixel = 0
	topbar.Parent = mainFrame
	registerThemed(topbar, "BackgroundColor3", "SecondaryBackground")

	-- Subtle gradient on topbar for depth
	local topGrad = Instance.new("UIGradient")
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 230, 235)),
	})
	topGrad.Rotation = 90
	topGrad.Parent = topbar

	MakeDraggable(topbar, mainFrame)

	-- Window control buttons — MacLib style (8px dots, left of title)
	local controlContainer = Instance.new("Frame")
	controlContainer.Size = UDim2.fromOffset(36, 10)
	controlContainer.Position = UDim2.new(0, 14, 0.5, -5)
	controlContainer.BackgroundTransparency = 1
	controlContainer.Parent = topbar

	local controlLayout = Instance.new("UIListLayout")
	controlLayout.FillDirection = Enum.FillDirection.Horizontal
	controlLayout.Padding = UDim.new(0, 5)
	controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlLayout.Parent = controlContainer

	-- Close (red)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(8, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(250, 93, 86)
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.BorderSizePixel = 0
	closeBtn.LayoutOrder = 1
	CreateCorner(closeBtn, 999)
	closeBtn.Parent = controlContainer

	-- Minimize (yellow)
	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.fromOffset(8, 8)
	minBtn.BackgroundColor3 = Color3.fromRGB(252, 190, 57)
	minBtn.Text = ""
	minBtn.AutoButtonColor = false
	minBtn.BorderSizePixel = 0
	minBtn.LayoutOrder = 2
	CreateCorner(minBtn, 999)
	minBtn.Parent = controlContainer

	-- Maximize (green, disabled)
	local maxBtn = Instance.new("Frame")
	maxBtn.Size = UDim2.fromOffset(8, 8)
	maxBtn.BackgroundColor3 = Color3.fromRGB(119, 174, 94)
	maxBtn.BorderSizePixel = 0
	maxBtn.LayoutOrder = 3
	CreateCorner(maxBtn, 999)
	maxBtn.Parent = controlContainer

	closeBtn.MouseButton1Click:Connect(_sd(function() Window:Unload() end))
	minBtn.MouseButton1Click:Connect(_sd(function()
		Window._minimized = true
		mainFrame.Visible = false
		if Window._minimizerBtn then Window._minimizerBtn.Visible = true end
	end))

	-- Title moved right to make room for dots
	local accentDot = Instance.new("Frame")
	accentDot.Size = UDim2.fromOffset(6, 6)
	accentDot.Position = UDim2.new(0, 60, 0.5, -3)
	accentDot.BackgroundColor3 = t.Accent
	accentDot.BorderSizePixel = 0
	CreateCorner(accentDot, 3)
	accentDot.Parent = topbar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 140, 1, 0)
	titleLabel.Position = UDim2.fromOffset(72, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = winTitle
	titleLabel.TextColor3 = t.TextPrimary
	titleLabel.FontFace = t.FontBold
	titleLabel.TextSize = 15
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	registerThemed(titleLabel, "TextColor3", "TextPrimary")

	if winSubtitle ~= "" then
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(0, 60, 1, 0)
		subLabel.Position = UDim2.fromOffset(72 + titleLabel.Size.X.Offset + 4, 1)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = winSubtitle
		subLabel.TextColor3 = t.TextDimmed
		subLabel.FontFace = t.Font
		subLabel.TextSize = 11
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Parent = topbar
		registerThemed(subLabel, "TextColor3", "TextDimmed")
	end

	-- ══════════════════════════════
	-- KEY EXPIRATION — in sidebar bottom (MacLib-style UserInfo)
	-- ══════════════════════════════
	local keyLabel
	local keyDot

	-- UserInfo section at bottom of sidebar
	local userInfo = Instance.new("Frame")
	userInfo.Name = "UserInfo"
	userInfo.AnchorPoint = Vector2.new(0, 1)
	userInfo.Size = UDim2.new(sidebarScale, 0, 0, 56)
	userInfo.Position = UDim2.new(0, 0, 1, 0)
	userInfo.BackgroundColor3 = t.SecondaryBackground
	userInfo.BackgroundTransparency = 0
	userInfo.BorderSizePixel = 0
	userInfo.Parent = body
	registerThemed(userInfo, "BackgroundColor3", "SecondaryBackground")

	-- Content: hub name + key timer stacked (no divider — bg difference is enough)
	local userInfoContent = Instance.new("Frame")
	userInfoContent.Size = UDim2.new(1, 0, 1, 0)
	userInfoContent.BackgroundTransparency = 1
	userInfoContent.Parent = userInfo
	CreatePadding(userInfoContent, 8, 10, 12, 12)
	CreateList(userInfoContent, 3)

	local hubNameLabel = Instance.new("TextLabel")
	hubNameLabel.Size = UDim2.new(1, 0, 0, 16)
	hubNameLabel.BackgroundTransparency = 1
	hubNameLabel.Text = winTitle
	hubNameLabel.TextColor3 = t.TextPrimary
	hubNameLabel.TextTransparency = 0.2
	hubNameLabel.FontFace = FontSemibold()
	hubNameLabel.TextSize = 13
	hubNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	hubNameLabel.LayoutOrder = 1
	hubNameLabel.Parent = userInfoContent

	if keyExpiration then
		-- Key timer row: dot + text
		local keyRow = Instance.new("Frame")
		keyRow.Size = UDim2.new(1, 0, 0, 14)
		keyRow.BackgroundTransparency = 1
		keyRow.LayoutOrder = 2
		keyRow.Parent = userInfoContent

		keyDot = Instance.new("Frame")
		keyDot.Name = "KeyDot"
		keyDot.Size = UDim2.fromOffset(6, 6)
		keyDot.Position = UDim2.fromOffset(0, 4)
		keyDot.BackgroundColor3 = t.Success
		keyDot.BorderSizePixel = 0
		CreateCorner(keyDot, 3)
		keyDot.Parent = keyRow

		keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyExpiration"
		keyLabel.Size = UDim2.new(1, -12, 0, 14)
		keyLabel.Position = UDim2.fromOffset(10, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = ""
		keyLabel.TextColor3 = t.TextDimmed
		keyLabel.FontFace = FontRegular()
		keyLabel.TextSize = 11
		keyLabel.TextXAlignment = Enum.TextXAlignment.Left
		keyLabel.Parent = keyRow

		local function updateKeyTimer()
			pcall(function()
				local y, mo, d, h, mi, s = keyExpiration:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
				if not y then return end
				local expTime = os.time({year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s)})
				local now = os.time()
				local diff = expTime - now
				if diff <= 0 then
					keyLabel.Text = "Key: Expired"
					keyDot.BackgroundColor3 = t.Error
					Tween(keyDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.6})
				elseif diff < 86400 then
					keyLabel.Text = string.format("Key: %dч %dм", math.floor(diff / 3600), math.floor((diff % 3600) / 60))
					keyDot.BackgroundColor3 = t.Error
				elseif diff < 604800 then
					keyLabel.Text = string.format("Key: %dд %dч", math.floor(diff / 86400), math.floor((diff % 86400) / 3600))
					keyDot.BackgroundColor3 = t.Warning
				else
					keyLabel.Text = string.format("Key: %dд %dч", math.floor(diff / 86400), math.floor((diff % 86400) / 3600))
					keyDot.BackgroundColor3 = t.Success
				end
			end)
		end
		updateKeyTimer()
		local keyThread = task.spawn(function()
			while getgenv and getgenv()._SkrilyaRunning do
				updateKeyTimer()
				task.wait(60)
			end
		end)
		table.insert(_threads, keyThread)
	end

	function Window:SetKeyTimer(expStr)
		keyExpiration = expStr
	end

	-- Shrink sidebar to leave room for UserInfo
	sidebar.Size = UDim2.new(sidebarScale, 0, 1, -56)

	-- Topbar divider — subtle gradient line
	local topDiv = Instance.new("Frame")
	topDiv.Size = UDim2.new(1, 0, 0, 1)
	topDiv.Position = UDim2.fromOffset(0, 46)
	topDiv.BackgroundColor3 = t.Divider
	topDiv.BackgroundTransparency = 0.3
	topDiv.BorderSizePixel = 0
	topDiv.Parent = mainFrame
	registerThemed(topDiv, "BackgroundColor3", "Divider")

	-- ══════════════════════════════
	-- BODY CONTAINER
	-- ══════════════════════════════
	local body = Instance.new("Frame")
	body.Name = "BodyContainer"
	body.Size = UDim2.new(1, 0, 1, -47)
	body.Position = UDim2.fromOffset(0, 47)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = mainFrame

	-- ══════════════════════════════
	-- SIDEBAR — refined with hover states
	-- ══════════════════════════════
	local sidebarScale = 0.22 -- ~22% of window width (MacLib uses 0.325)
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(sidebarScale, 0, 1, 0)
	sidebar.BackgroundColor3 = t.SecondaryBackground
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 2
	sidebar.ScrollBarImageColor3 = t.Accent
	sidebar.ScrollBarImageTransparency = 0.6
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.Parent = body
	CreateList(sidebar, 2)
	CreatePadding(sidebar, 10, 10, 8, 8)
	registerThemed(sidebar, "BackgroundColor3", "SecondaryBackground")

	Window._sidebar = sidebar
	Window._sidebarOrderCounter = 0

	-- Sidebar divider
	local sideDiv = Instance.new("Frame")
	sideDiv.Size = UDim2.new(0, 1, 1, 0)
	sideDiv.AnchorPoint = Vector2.new(1, 0)
	sideDiv.Position = UDim2.new(sidebarScale, 0, 0, 0)
	sideDiv.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sideDiv.BackgroundTransparency = 0.9
	sideDiv.BorderSizePixel = 0
	sideDiv.Parent = body

	-- Content area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.AnchorPoint = Vector2.new(1, 0)
	contentArea.Size = UDim2.new(1 - sidebarScale, -1, 1, 0)
	contentArea.Position = UDim2.new(1, 0, 0, 0)
	contentArea.BackgroundTransparency = 1
	contentArea.BorderSizePixel = 0
	contentArea.Parent = body
	Window._contentArea = contentArea

	-- // 9a. WINDOW SCALE
	function Window:SetScale(scale)
		pcall(function()
			if not gui:FindFirstChildOfClass("UIScale") then
				local uiScale = Instance.new("UIScale")
				uiScale.Parent = gui
			end
			gui:FindFirstChildOfClass("UIScale").Scale = math.clamp(scale or 1, 0.5, 2)
		end)
	end

	function Window:GetScale()
		local s = gui:FindFirstChildOfClass("UIScale")
		return s and s.Scale or 1
	end

	-- // 9b. GLOBAL SETTINGS
	function Window:GlobalSetting(cfg)
		cfg = cfg or {}
		if cfg.AcrylicBlur ~= nil then
			pcall(function()
				local blur = game:GetService("Lighting"):FindFirstChild("SkrilyaBlur")
				if cfg.AcrylicBlur then
					if not blur then
						blur = Instance.new("BlurEffect")
						blur.Name = "SkrilyaBlur"
						blur.Size = 10
						blur.Parent = game:GetService("Lighting")
					end
				else
					if blur then blur:Destroy() end
				end
			end)
			Window._blurEnabled = cfg.AcrylicBlur
		end
		if cfg.Notifications ~= nil then
			SkrilyaLib:SetNotificationsEnabled(cfg.Notifications)
			Window._notificationsEnabled = cfg.Notifications
		end
	end

	function Window:GetAcrylicBlurState() return Window._blurEnabled or false end
	function Window:SetAcrylicBlurState(v) Window:GlobalSetting({AcrylicBlur = v}) end
	function Window:GetNotificationsState() return _notificationsEnabled end
	function Window:SetNotificationsState(v)
		SkrilyaLib:SetNotificationsEnabled(v)
		Window._notificationsEnabled = v
	end

	-- ══════════════════════════════
	-- // 10. STATUS BAR
	-- ══════════════════════════════
	function Window:CreateStatusBar(cfg)
		cfg = cfg or {}
		local sb = Instance.new("Frame")
		sb.Name = "StatusBar"
		sb.Size = UDim2.new(1, 0, 0, 22)
		sb.Position = UDim2.new(0, 0, 1, -22)
		sb.BackgroundColor3 = t.SecondaryBackground
		sb.BorderSizePixel = 0
		sb.Parent = mainFrame
		registerThemed(sb, "BackgroundColor3", "SecondaryBackground")

		-- Top border line
		local sbDiv = Instance.new("Frame")
		sbDiv.Size = UDim2.new(1, 0, 0, 1)
		sbDiv.BackgroundColor3 = t.Divider
		sbDiv.BackgroundTransparency = 0.4
		sbDiv.BorderSizePixel = 0
		sbDiv.Parent = sb
		registerThemed(sbDiv, "BackgroundColor3", "Divider")

		local layout = CreateList(sb, 16, Enum.FillDirection.Horizontal)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		CreatePadding(sb, 0, 0, 14, 14)

		body.Size = UDim2.new(1, 0, 1, -69)

		local fields = {}

		local function addField(text, color, ord)
			-- Status dot before text
			local container = Instance.new("Frame")
			container.Size = UDim2.fromOffset(0, 18)
			container.AutomaticSize = Enum.AutomaticSize.X
			container.BackgroundTransparency = 1
			container.LayoutOrder = ord or 0
			container.Parent = sb

			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(4, 4)
			dot.Position = UDim2.fromOffset(0, 7)
			dot.BackgroundColor3 = color or t.TextDimmed
			dot.BorderSizePixel = 0
			CreateCorner(dot, 2)
			dot.Parent = container

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromOffset(0, 18)
			lbl.Position = UDim2.fromOffset(8, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.X
			lbl.BackgroundTransparency = 1
			lbl.Text = text
			lbl.TextColor3 = t.TextDimmed
			lbl.FontFace = t.Font
			lbl.TextSize = 10
			lbl.Parent = container
			return lbl
		end

		local fpsLabel, pingLabel, gameLabel

		if cfg.FPS then fpsLabel = addField("FPS: --", t.Success, 1) end
		if cfg.Ping then pingLabel = addField("Ping: --", t.Warning, 2) end
		if cfg.GameName then
			gameLabel = addField(_gameName, t.TextDimmed, 3)
			registerThemed(gameLabel, "TextColor3", "TextDimmed")
		end

		local fpsCount, lastFpsTime = 0, tick()
		if cfg.FPS then
			local fpsConn = RunService.RenderStepped:Connect(function()
				fpsCount = fpsCount + 1
				if tick() - lastFpsTime >= 1 then
					pcall(function() fpsLabel.Text = "FPS: " .. fpsCount end)
					fpsCount = 0
					lastFpsTime = tick()
				end
			end)
			table.insert(_connections, fpsConn)
		end

		if cfg.Ping then
			local pingThread = task.spawn(function()
				while getgenv and getgenv()._SkrilyaRunning do
					pcall(function()
						local ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
						pingLabel.Text = "Ping: " .. ping .. "ms"
					end)
					task.wait(1)
				end
			end)
			table.insert(_threads, pingThread)
		end

		Window._statusBar = sb
		return {
			AddField = function(_, name, getValueFn)
				local lbl = addField(name, t.TextDimmed, #fields + 4)
				table.insert(fields, {label = lbl, fn = getValueFn})
				local thread = task.spawn(function()
					while getgenv and getgenv()._SkrilyaRunning do
						pcall(function() lbl.Text = getValueFn() end)
						task.wait(1)
					end
				end)
				table.insert(_threads, thread)
			end,
		}
	end

	-- ══════════════════════════════
	-- // 11. TAB SECTIONS
	-- ══════════════════════════════
	function Window:CreateTabSection(name)
		Window._sidebarOrderCounter = Window._sidebarOrderCounter + 1

		-- Section divider line (skip for first)
		if Window._sidebarOrderCounter > 1 then
			local divLine = Instance.new("Frame")
			divLine.Size = UDim2.new(1, -8, 0, 1)
			divLine.Position = UDim2.fromOffset(4, 0)
			divLine.BackgroundColor3 = t.Divider
			divLine.BackgroundTransparency = 0.5
			divLine.BorderSizePixel = 0
			divLine.LayoutOrder = Window._sidebarOrderCounter * 100 - 1
			divLine.Parent = sidebar
		end

		local hdr = Instance.new("TextLabel")
		hdr.Size = UDim2.new(1, 0, 0, 26)
		hdr.BackgroundTransparency = 1
		hdr.Text = string.upper(name)
		hdr.TextColor3 = t.TextDimmed
		hdr.FontFace = t.FontBold
		hdr.TextSize = 9
		hdr.TextXAlignment = Enum.TextXAlignment.Left
		hdr.LayoutOrder = Window._sidebarOrderCounter * 100
		hdr.Parent = sidebar
		registerThemed(hdr, "TextColor3", "TextDimmed")

		-- Letter spacing simulation via padding
		CreatePadding(hdr, 8, 0, 4, 0)

		local section = {_orderBase = Window._sidebarOrderCounter * 100}

		function section:CreateTab(cfg)
			return Window:_createTab(cfg, section._orderBase)
		end

		table.insert(Window._tabSections, section)
		return section
	end

	-- ══════════════════════════════
	-- // 12. TAB — with refined sidebar button
	-- ══════════════════════════════
	local tabCounter = 0

	function Window:_createTab(cfg, orderBase)
		tabCounter = tabCounter + 1
		local tabOrder = (orderBase or 0) + tabCounter
		local tabName = cfg.Name or "Tab"
		local Tab = {_sections = {}}

		-- Sidebar button — with left indicator and hover
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tabName
		tabBtn.Size = UDim2.new(1, 0, 0, 32)
		tabBtn.BackgroundColor3 = t.TertiaryBackground
		tabBtn.BackgroundTransparency = 1
		tabBtn.Text = ""
		tabBtn.BorderSizePixel = 0
		tabBtn.LayoutOrder = tabOrder
		CreateCorner(tabBtn, 8)
		tabBtn.Parent = sidebar

		-- Tab name label (offset for indicator)
		local tabLbl = Instance.new("TextLabel")
		tabLbl.Size = UDim2.new(1, -16, 1, 0)
		tabLbl.Position = UDim2.fromOffset(12, 0)
		tabLbl.BackgroundTransparency = 1
		tabLbl.Text = tabName
		tabLbl.TextColor3 = t.TextSecondary
		tabLbl.FontFace = t.Font
		tabLbl.TextSize = 13
		tabLbl.TextXAlignment = Enum.TextXAlignment.Left
		tabLbl.Parent = tabBtn
		registerThemed(tabLbl, "TextColor3", "TextSecondary")

		-- Left accent indicator (hidden by default)
		local indicator = Instance.new("Frame")
		indicator.Name = "ActiveIndicator"
		indicator.Size = UDim2.new(0, 3, 0.5, 0)
		indicator.Position = UDim2.new(0, 1, 0.25, 0)
		indicator.BackgroundColor3 = t.Accent
		indicator.BackgroundTransparency = 1
		indicator.BorderSizePixel = 0
		CreateCorner(indicator, 2)
		indicator.Parent = tabBtn

		-- Hover effect
		tabBtn.MouseEnter:Connect(function()
			if Window._activeTab ~= Tab then
				Tween(tabBtn, TI_FAST, {BackgroundTransparency = 0.7})
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if Window._activeTab ~= Tab then
				Tween(tabBtn, TI_FAST, {BackgroundTransparency = 1})
			end
		end)

		-- Content frame
		local contentFrame = Instance.new("ScrollingFrame")
		contentFrame.Name = "TabContent_" .. tabName
		contentFrame.Size = UDim2.new(1, 0, 1, 0)
		contentFrame.BackgroundTransparency = 1
		contentFrame.BorderSizePixel = 0
		contentFrame.ScrollBarThickness = 3
		contentFrame.ScrollBarImageColor3 = t.Accent
		contentFrame.ScrollBarImageTransparency = 0.5
		contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		contentFrame.Visible = false
		contentFrame.Parent = contentArea
		CreatePadding(contentFrame, 12, 12, 14, 14)
		CreateList(contentFrame, 10) -- Stack paragraph + columns vertically

		-- Two column container
		local colsFrame = Instance.new("Frame")
		colsFrame.Name = "Columns"
		colsFrame.Size = UDim2.new(1, 0, 0, 0)
		colsFrame.AutomaticSize = Enum.AutomaticSize.Y
		colsFrame.BackgroundTransparency = 1
		colsFrame.LayoutOrder = 1
		colsFrame.Parent = contentFrame

		local leftCol = Instance.new("Frame")
		leftCol.Name = "Left"
		leftCol.Size = UDim2.new(0.5, -6, 0, 0)
		leftCol.AutomaticSize = Enum.AutomaticSize.Y
		leftCol.BackgroundTransparency = 1
		leftCol.Parent = colsFrame
		CreateList(leftCol, 8)

		local rightCol = Instance.new("Frame")
		rightCol.Name = "Right"
		rightCol.Size = UDim2.new(0.5, -6, 0, 0)
		rightCol.Position = UDim2.new(0.5, 6, 0, 0)
		rightCol.AutomaticSize = Enum.AutomaticSize.Y
		rightCol.BackgroundTransparency = 1
		rightCol.Parent = colsFrame
		CreateList(rightCol, 8)

		local centerCol = Instance.new("Frame")
		centerCol.Name = "Center"
		centerCol.Size = UDim2.new(1, 0, 0, 0)
		centerCol.AutomaticSize = Enum.AutomaticSize.Y
		centerCol.BackgroundTransparency = 1
		centerCol.Visible = false
		centerCol.LayoutOrder = 2
		centerCol.Parent = contentFrame
		CreateList(centerCol, 8)

		Tab._btn = tabBtn
		Tab._content = contentFrame
		Tab._leftCol = leftCol
		Tab._rightCol = rightCol
		Tab._centerCol = centerCol
		Tab._indicator = indicator
		Tab._tabLbl = tabLbl

		-- Tab switching logic
		local function selectThis()
			for _, tab in ipairs(Window._tabs) do
				local isActive = (tab == Tab)
				tab._content.Visible = isActive

				if isActive then
					Tween(tab._btn, TI_FAST, {BackgroundTransparency = 0.5})
					Tween(tab._tabLbl, TI_FAST, {TextColor3 = t.TextPrimary})
					tab._tabLbl.FontFace = t.FontBold
					Tween(tab._indicator, TI_MED, {BackgroundTransparency = 0})
				else
					Tween(tab._btn, TI_FAST, {BackgroundTransparency = 1})
					Tween(tab._tabLbl, TI_FAST, {TextColor3 = t.TextSecondary})
					tab._tabLbl.FontFace = t.Font
					Tween(tab._indicator, TI_FAST, {BackgroundTransparency = 1})
				end
			end
			Window._activeTab = Tab
		end

		tabBtn.MouseButton1Click:Connect(selectThis)

		-- Tab-level paragraph
		function Tab:AddParagraph(cfg)
			local pf = Instance.new("Frame")
			pf.Size = UDim2.new(1, 0, 0, 0)
			pf.AutomaticSize = Enum.AutomaticSize.Y
			pf.BackgroundColor3 = t.TertiaryBackground
			pf.BorderSizePixel = 0
			pf.LayoutOrder = -1000
			CreateCorner(pf, 8)
			CreatePadding(pf, 10, 10, 12, 12)
			CreateList(pf, 4)
			pf.Parent = contentFrame
			registerThemed(pf, "BackgroundColor3", "TertiaryBackground")

			if cfg.Icon then
				local icon = Instance.new("ImageLabel")
				icon.Size = UDim2.fromOffset(18, 18)
				icon.BackgroundTransparency = 1
				icon.Image = cfg.Icon
				icon.ImageColor3 = t.Accent
				icon.LayoutOrder = 0
				icon.Parent = pf
			end

			local ph = Instance.new("TextLabel")
			ph.Size = UDim2.new(1, 0, 0, 20)
			ph.BackgroundTransparency = 1
			ph.Text = cfg.Title or cfg.Header or ""
			ph.TextColor3 = t.TextPrimary
			ph.FontFace = t.FontBold
			ph.TextSize = 14
			ph.TextXAlignment = Enum.TextXAlignment.Left
			ph.LayoutOrder = 1
			ph.Parent = pf
			registerThemed(ph, "TextColor3", "TextPrimary")

			local pb = Instance.new("TextLabel")
			pb.Size = UDim2.new(1, 0, 0, 0)
			pb.AutomaticSize = Enum.AutomaticSize.Y
			pb.BackgroundTransparency = 1
			pb.Text = cfg.Content or cfg.Body or ""
			pb.TextColor3 = t.TextSecondary
			pb.FontFace = t.Font
			pb.TextSize = 12
			pb.TextWrapped = true
			pb.TextXAlignment = Enum.TextXAlignment.Left
			pb.LayoutOrder = 2
			pb.Parent = pf
			registerThemed(pb, "TextColor3", "TextSecondary")

			local obj = {Instance = pf}
			function obj:SetTitle(text) ph.Text = text end
			function obj:SetDesc(text) pb.Text = text end
			function obj:SetHeader(text) ph.Text = text end
			function obj:SetBody(text) pb.Text = text end
			return obj
		end

		-- ══════════════════════════════
		-- // 13. SECTION — with accent underline header
		-- ══════════════════════════════
		local sectionOrder = 0

		function Tab:CreateSection(cfg)
			sectionOrder = sectionOrder + 1
			local sectionName = cfg.Name or "Section"
			local side = cfg.Side or "Left"
			local parent
			if side == "Center" then
				centerCol.Visible = true
				parent = centerCol
			elseif side == "Right" then
				parent = rightCol
			else
				parent = leftCol
			end

			local sec = Instance.new("Frame")
			sec.Name = "Sec_" .. sectionName
			sec.Size = UDim2.new(1, 0, 0, 0)
			sec.AutomaticSize = Enum.AutomaticSize.Y
			sec.BackgroundColor3 = t.SecondaryBackground
			sec.BorderSizePixel = 0
			sec.LayoutOrder = sectionOrder
			CreateCorner(sec, 10)
			-- NO UIStroke — rely on bg color difference for depth
			CreatePadding(sec, 10, 10, 12, 12)
			CreateList(sec, 8)
			sec.Parent = parent
			registerThemed(sec, "BackgroundColor3", "SecondaryBackground")

			if sectionName ~= "" then
				-- Section header with small accent underline
				local secHdrContainer = Instance.new("Frame")
				secHdrContainer.Size = UDim2.new(1, 0, 0, 28)
				secHdrContainer.BackgroundTransparency = 1
				secHdrContainer.LayoutOrder = 0
				secHdrContainer.Parent = sec

				local secHdr = Instance.new("TextLabel")
				secHdr.Size = UDim2.new(1, 0, 0, 18)
				secHdr.BackgroundTransparency = 1
				secHdr.Text = sectionName
				secHdr.TextColor3 = t.TextPrimary
				secHdr.FontFace = t.FontBold
				secHdr.TextSize = 13
				secHdr.TextXAlignment = Enum.TextXAlignment.Left
				secHdr.Parent = secHdrContainer
				registerThemed(secHdr, "TextColor3", "TextPrimary")

				-- Small accent line under header
				local secLine = Instance.new("Frame")
				secLine.Size = UDim2.fromOffset(24, 2)
				secLine.Position = UDim2.fromOffset(0, 22)
				secLine.BackgroundColor3 = t.Accent
				secLine.BackgroundTransparency = 0.3
				secLine.BorderSizePixel = 0
				CreateCorner(secLine, 1)
				secLine.Parent = secHdrContainer
			end

			local Section = {}
			local elemOrder = 0

			-- Common element wrapper
			local function wrapElement(obj, elementType, flag)
				obj._type = elementType
				obj._locked = false
				obj._visible = true
				obj._lockOverlay = nil
				obj._changedCallbacks = {}

				if flag then registerFlag(flag, obj.Value, obj) end

				function obj:OnChanged(fn)
					table.insert(obj._changedCallbacks, fn)
				end

				function obj:Lock(reason)
					obj._locked = true
					if not obj._lockOverlay and obj.Instance then
						local ov = Instance.new("Frame")
						ov.Size = UDim2.new(1, 0, 1, 0)
						ov.BackgroundColor3 = Color3.new(0, 0, 0)
						ov.BackgroundTransparency = 0.55
						ov.ZIndex = 10
						ov.BorderSizePixel = 0
						CreateCorner(ov, 8)
						ov.Parent = obj.Instance
						obj._lockOverlay = ov
						if reason then
							local tip = Instance.new("TextLabel")
							tip.Size = UDim2.new(1, 0, 1, 0)
							tip.BackgroundTransparency = 1
							tip.Text = "🔒 " .. reason
							tip.TextColor3 = theme().TextDimmed
							tip.FontFace = theme().Font
							tip.TextSize = 11
							tip.ZIndex = 11
							tip.Parent = ov
						end
					end
				end

				function obj:Unlock()
					obj._locked = false
					if obj._lockOverlay then
						obj._lockOverlay:Destroy()
						obj._lockOverlay = nil
					end
				end

				function obj:SetVisibility(visible)
					obj._visible = visible
					if obj.Instance then obj.Instance.Visible = visible end
				end

				function obj:Destroy()
					if flag then
						SkrilyaLib.Flags[flag] = nil
						SkrilyaLib.Options[flag] = nil
					end
					if obj.Instance then pcall(function() obj.Instance:Destroy() end) end
				end

				return obj
			end

			local function fireChanged(obj, value)
				for _, fn in ipairs(obj._changedCallbacks) do
					pcall(fn, value)
				end
			end

			local function safeCallback(fn, ...)
				if not fn then return end
				local args = {...}
				task.defer(function()
					local ok, err = pcall(fn, unpack(args))
					if not ok and notifyOnError then
						SkrilyaLib:Notify({Title = "Callback Error", Description = tostring(err), Type = "Error", Duration = 5})
					end
				end)
			end

			-- ══════════════════════════════
			-- // 14. ELEMENTS — visually refined
			-- ══════════════════════════════

			-- TOGGLE — AutomaticSize, AnchorPoint-centered, no card/stroke
			function Section:Toggle(cfg)
				elemOrder = elemOrder + 1
				local hasDesc = cfg.Description and cfg.Description ~= ""
				local obj = {Value = cfg.Default or false}

				local frame = Instance.new("Frame")
				frame.Name = "Tgl_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, 0)
				frame.AutomaticSize = Enum.AutomaticSize.Y
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.LayoutOrder = elemOrder
				frame.Parent = sec
				CreatePadding(frame, 4, 4, 0, 0)

				-- Text container (drives auto height)
				local textContainer = Instance.new("Frame")
				textContainer.Size = UDim2.new(1, -54, 0, 0)
				textContainer.AutomaticSize = Enum.AutomaticSize.Y
				textContainer.BackgroundTransparency = 1
				textContainer.Parent = frame
				CreateList(textContainer, 2)

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.LayoutOrder = 1
				lbl.Parent = textContainer
				registerThemed(lbl, "TextColor3", "TextPrimary")

				if hasDesc then
					local descLbl = Instance.new("TextLabel")
					descLbl.Size = UDim2.new(1, 0, 0, 14)
					descLbl.BackgroundTransparency = 1
					descLbl.Text = cfg.Description
					descLbl.TextColor3 = t.TextDimmed
					descLbl.FontFace = t.Font
					descLbl.TextSize = 11
					descLbl.TextXAlignment = Enum.TextXAlignment.Left
					descLbl.TextTruncate = Enum.TextTruncate.AtEnd
					descLbl.LayoutOrder = 2
					descLbl.Parent = textContainer
					registerThemed(descLbl, "TextColor3", "TextDimmed")
				end

				-- Toggle switch — image-based (MacLib assets)
				local switchBg = Instance.new("ImageLabel")
				switchBg.Size = UDim2.fromOffset(42, 22)
				switchBg.AnchorPoint = Vector2.new(1, 0.5)
				switchBg.Position = UDim2.new(1, 0, 0.5, 0)
				switchBg.BackgroundTransparency = 1
				switchBg.Image = Assets.toggleBackground
				switchBg.ImageColor3 = obj.Value and t.Accent or t.ToggleOff
				switchBg.Parent = frame

				local circle = Instance.new("ImageLabel")
				circle.Size = UDim2.fromOffset(18, 18)
				circle.Position = obj.Value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
				circle.BackgroundTransparency = 1
				circle.Image = Assets.togglerHead
				circle.ImageColor3 = Color3.new(1, 1, 1)
				circle.Parent = switchBg

				local clickBtn = Instance.new("TextButton")
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 5
				clickBtn.Parent = frame

				obj.Instance = frame

				local function updateVisual()
					Tween(switchBg, TI_MED, {ImageColor3 = obj.Value and t.Accent or t.ToggleOff})
					Tween(circle, TI_MED, {Position = obj.Value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)})
				end

				function obj:SetValue(v)
					obj.Value = v
					if cfg.Flag then updateFlag(cfg.Flag, v) end
					updateVisual()
					if not _isLoadingConfig then
						safeCallback(cfg.Callback, v)
					end
					fireChanged(obj, v)
				end

				-- Hover — subtle highlight only
				clickBtn.MouseEnter:Connect(function()
					Tween(frame, TI_FAST, {BackgroundTransparency = 0.85})
				end)
				clickBtn.MouseLeave:Connect(function()
					Tween(frame, TI_FAST, {BackgroundTransparency = 1})
				end)

				clickBtn.MouseButton1Click:Connect(function()
					if obj._locked then return end
					obj:SetValue(not obj.Value)
				end)

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Toggle", cfg.Flag)

				function obj:AddKeybind(kcfg) return Section:_addNestedKeybind(frame, kcfg) end
				function obj:AddColorpicker(ccfg) return Section:_addNestedColorpicker(frame, ccfg) end
				function obj:AddDropdown(dcfg) return Section:_addNestedDropdown(frame, dcfg) end

				return obj
			end

			-- SLIDER — AutomaticSize, AnchorPoint-centered
			function Section:Slider(cfg)
				elemOrder = elemOrder + 1
				local mn = cfg.Min or 0
				local mx = cfg.Max or 100
				local step = cfg.Step or 1
				local hasDesc = cfg.Description and cfg.Description ~= ""
				local obj = {Value = cfg.Default or mn}

				local frame = Instance.new("Frame")
				frame.Name = "Sld_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, 0)
				frame.AutomaticSize = Enum.AutomaticSize.Y
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.LayoutOrder = elemOrder
				frame.Parent = sec
				CreatePadding(frame, 4, 8, 0, 0)

				-- Top row: name + value
				local topRow = Instance.new("Frame")
				topRow.Size = UDim2.new(1, 0, 0, 16)
				topRow.BackgroundTransparency = 1
				topRow.Parent = frame

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -50, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = topRow
				registerThemed(lbl, "TextColor3", "TextPrimary")

				if hasDesc then
					local descLbl = Instance.new("TextLabel")
					descLbl.Size = UDim2.new(1, -50, 0, 12)
					descLbl.Position = UDim2.fromOffset(0, 18)
					descLbl.BackgroundTransparency = 1
					descLbl.Text = cfg.Description
					descLbl.TextColor3 = t.TextDimmed
					descLbl.FontFace = t.Font
					descLbl.TextSize = 10
					descLbl.TextXAlignment = Enum.TextXAlignment.Left
					descLbl.TextTruncate = Enum.TextTruncate.AtEnd
					descLbl.Parent = topRow
					registerThemed(descLbl, "TextColor3", "TextDimmed")
					topRow.Size = UDim2.new(1, 0, 0, 32)
				end

				local suffix = cfg.Suffix or ""

				local valLbl = Instance.new("TextLabel")
				valLbl.Size = UDim2.fromOffset(46, 16)
				valLbl.AnchorPoint = Vector2.new(1, 0)
				valLbl.Position = UDim2.new(1, 0, 0, 0)
				valLbl.BackgroundTransparency = 1
				valLbl.Text = tostring(obj.Value) .. suffix
				valLbl.TextColor3 = t.Accent
				valLbl.FontFace = t.FontBold
				valLbl.TextSize = 12
				valLbl.TextXAlignment = Enum.TextXAlignment.Right
				valLbl.Parent = topRow

				-- Track — 4px height, positioned below text
				local trackContainer = Instance.new("Frame")
				trackContainer.Size = UDim2.new(1, 0, 0, 14)
				trackContainer.Position = UDim2.new(0, 0, 0, topRow.Size.Y.Offset + 4)
				trackContainer.BackgroundTransparency = 1
				trackContainer.Parent = frame

				local track = Instance.new("ImageLabel")
				track.Size = UDim2.new(1, 0, 0, 6)
				track.AnchorPoint = Vector2.new(0, 0.5)
				track.Position = UDim2.new(0, 0, 0.5, 0)
				track.BackgroundTransparency = 1
				track.Image = Assets.sliderbar
				track.ImageColor3 = t.SliderBg
				track.ScaleType = Enum.ScaleType.Slice
				track.SliceCenter = Rect.new(6, 6, 6, 6)
				track.Parent = trackContainer

				local fill = Instance.new("ImageLabel")
				fill.Size = UDim2.new((obj.Value - mn) / math.max(mx - mn, 1), 0, 1, 0)
				fill.BackgroundTransparency = 1
				fill.Image = Assets.sliderbar
				fill.ImageColor3 = t.Accent
				fill.ScaleType = Enum.ScaleType.Slice
				fill.SliceCenter = Rect.new(6, 6, 6, 6)
				fill.Parent = track

				-- Thumb — image-based
				local thumb = Instance.new("ImageLabel")
				thumb.Size = UDim2.fromOffset(14, 14)
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Position = UDim2.new((obj.Value - mn) / math.max(mx - mn, 1), 0, 0.5, 0)
				thumb.BackgroundTransparency = 1
				thumb.Image = Assets.sliderhead
				thumb.ImageColor3 = Color3.new(1, 1, 1)
				thumb.ZIndex = 3
				thumb.Parent = track

				obj.Instance = frame

				local function updateVisual()
					local pct = math.clamp((obj.Value - mn) / math.max(mx - mn, 1), 0, 1)
					fill.Size = UDim2.new(pct, 0, 1, 0)
					thumb.Position = UDim2.new(pct, 0, 0.5, 0)
					valLbl.Text = tostring(obj.Value) .. suffix
				end

				local function roundToStep(v)
					return math.clamp(math.floor((v - mn) / step + 0.5) * step + mn, mn, mx)
				end

				function obj:SetValue(v)
					obj.Value = roundToStep(v)
					if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
					updateVisual()
					if not _isLoadingConfig then safeCallback(cfg.Callback, obj.Value) end
					fireChanged(obj, obj.Value)
				end

				local sliding = false
				local sliderBtn = Instance.new("TextButton")
				sliderBtn.Size = UDim2.new(1, 0, 1, 20)
				sliderBtn.Position = UDim2.fromOffset(0, -10)
				sliderBtn.BackgroundTransparency = 1
				sliderBtn.Text = ""
				sliderBtn.ZIndex = 5
				sliderBtn.Parent = track

				local function onSlide(inputX)
					local pct = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					local raw = mn + pct * (mx - mn)
					obj:SetValue(raw)
				end

				sliderBtn.MouseButton1Down:Connect(function()
					if obj._locked then return end
					sliding = true
					-- Enlarge thumb while sliding
					Tween(thumb, TI_FAST, {Size = UDim2.fromOffset(14, 14)})
					onSlide(Mouse.X)
				end)

				local slideConn = UserInputService.InputChanged:Connect(function(input)
					if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
						onSlide(input.Position.X)
					end
				end)
				table.insert(_connections, slideConn)

				local slideEnd = UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and sliding then
						sliding = false
						-- Return thumb to normal
						Tween(thumb, TI_FAST, {Size = UDim2.fromOffset(12, 12)})
					end
				end)
				table.insert(_connections, slideEnd)

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Slider", cfg.Flag)
				return obj
			end

			-- DROPDOWN — AutomaticSize, clean
			function Section:Dropdown(cfg)
				elemOrder = elemOrder + 1
				local multi = cfg.Multi or false
				local allowNull = cfg.AllowNull or false
				local hasSearch = cfg.Search or false
				local hasDesc = cfg.Description and cfg.Description ~= ""
				local headerH = hasDesc and 40 or 28
				-- Multi-dropdown Value is ALWAYS a dict: {Name = true, Name2 = true}
				-- This avoids the MacLib bug where Value=array but Callback=dict
				local obj = {Value = cfg.Default or (multi and {} or nil)}

				local frame = Instance.new("Frame")
				frame.Name = "DD_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, headerH)
				frame.BackgroundColor3 = t.TertiaryBackground
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.ClipsDescendants = true
				frame.LayoutOrder = elemOrder
				CreateCorner(frame, 6)
				frame.Parent = sec

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(0.5, 0, 0, hasDesc and 20 or headerH)
				lbl.Position = UDim2.fromOffset(0, hasDesc and 6 or 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = frame
				registerThemed(lbl, "TextColor3", "TextPrimary")

				if hasDesc then
					local descLbl = Instance.new("TextLabel")
					descLbl.Size = UDim2.new(0.6, 0, 0, 14)
					descLbl.Position = UDim2.fromOffset(0, 28)
					descLbl.BackgroundTransparency = 1
					descLbl.Text = cfg.Description
					descLbl.TextColor3 = t.TextDimmed
					descLbl.FontFace = t.Font
					descLbl.TextSize = 10
					descLbl.TextXAlignment = Enum.TextXAlignment.Left
					descLbl.TextTruncate = Enum.TextTruncate.AtEnd
					descLbl.Parent = frame
					registerThemed(descLbl, "TextColor3", "TextDimmed")
				end

				-- Chevron + selected value
				local selLbl = Instance.new("TextLabel")
				selLbl.Size = UDim2.new(0.5, -16, 0, hasDesc and 20 or headerH)
				selLbl.Position = UDim2.new(0.5, 0, 0, hasDesc and 6 or 0)
				selLbl.BackgroundTransparency = 1
				selLbl.TextColor3 = t.TextSecondary
				selLbl.FontFace = t.Font
				selLbl.TextSize = 12
				selLbl.TextXAlignment = Enum.TextXAlignment.Right
				selLbl.Parent = frame
				registerThemed(selLbl, "TextColor3", "TextSecondary")

				local searchBox
				local searchOffset = 0
				if hasSearch then
					searchOffset = 30
					local searchBg = Instance.new("Frame")
					searchBg.Size = UDim2.new(1, -12, 0, 26)
					searchBg.Position = UDim2.new(0, 6, 0, headerH + 4)
					searchBg.BackgroundColor3 = t.Background
					searchBg.BorderSizePixel = 0
					CreateCorner(searchBg, 6)
					searchBg.Parent = frame
					registerThemed(searchBg, "BackgroundColor3", "Background")

					searchBox = Instance.new("TextBox")
					searchBox.Size = UDim2.new(1, -12, 1, 0)
					searchBox.Position = UDim2.fromOffset(6, 0)
					searchBox.BackgroundTransparency = 1
					searchBox.Text = ""
					searchBox.PlaceholderText = "Search..."
					searchBox.PlaceholderColor3 = t.TextDimmed
					searchBox.TextColor3 = t.TextPrimary
					searchBox.FontFace = t.Font
					searchBox.TextSize = 11
					searchBox.TextXAlignment = Enum.TextXAlignment.Left
					searchBox.ClearTextOnFocus = false
					searchBox.Parent = searchBg
				end

				local optionsContainer = Instance.new("Frame")
				optionsContainer.Size = UDim2.new(1, -12, 0, 0)
				optionsContainer.Position = UDim2.new(0, 6, 0, headerH + 4 + searchOffset)
				optionsContainer.AutomaticSize = Enum.AutomaticSize.Y
				optionsContainer.BackgroundTransparency = 1
				optionsContainer.Parent = frame
				CreateList(optionsContainer, 2)

				local isOpen = false
				local options = cfg.Options or {}
				local searchFilter = ""
				obj.Instance = frame

				local function getDisplayText()
					if multi then
						if type(obj.Value) == "table" then
							local names = {}
							for k, v in pairs(obj.Value) do
								if v == true then table.insert(names, tostring(k)) end
							end
							if #names > 0 then
								table.sort(names)
								return table.concat(names, ", ")
							end
						end
						return "None"
					else
						if obj.Value == nil and allowNull then
							return "None  ▾"
						end
						return tostring(obj.Value or "Select") .. "  ▾"
					end
				end

				local function getFilteredOptions()
					if searchFilter == "" then return options end
					local filtered = {}
					local lowerFilter = string.lower(searchFilter)
					for _, opt in ipairs(options) do
						if string.find(string.lower(tostring(opt)), lowerFilter, 1, true) then
							table.insert(filtered, opt)
						end
					end
					return filtered
				end

				local function calcOpenHeight()
					local filtered = getFilteredOptions()
					local count = #filtered + (allowNull and not multi and 1 or 0)
					return headerH + 6 + searchOffset + count * 30 + 8
				end

				local function buildOptions()
					for _, child in ipairs(optionsContainer:GetChildren()) do
						if child:IsA("GuiObject") then child:Destroy() end
					end

					local filtered = getFilteredOptions()
					local layoutIdx = 0

					if allowNull and not multi then
						layoutIdx = layoutIdx + 1
						local nullBtn = Instance.new("TextButton")
						nullBtn.Size = UDim2.new(1, 0, 0, 28)
						nullBtn.BackgroundColor3 = t.Background
						nullBtn.BackgroundTransparency = 0.3
						nullBtn.Text = "  None"
						nullBtn.TextColor3 = t.TextDimmed
						nullBtn.FontFace = t.Font
						nullBtn.TextSize = 12
						nullBtn.TextXAlignment = Enum.TextXAlignment.Left
						nullBtn.BorderSizePixel = 0
						nullBtn.LayoutOrder = layoutIdx
						CreateCorner(nullBtn, 6)
						nullBtn.Parent = optionsContainer
						nullBtn.MouseButton1Click:Connect(function()
							if obj._locked then return end
							obj.Value = nil
							selLbl.Text = getDisplayText()
							if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
							safeCallback(cfg.Callback, obj.Value)
							fireChanged(obj, obj.Value)
							isOpen = false
							Tween(frame, TI_MED, {Size = UDim2.new(1, 0, 0, headerH)})
							buildOptions()
						end)
					end

					for _, opt in ipairs(filtered) do
						layoutIdx = layoutIdx + 1
						local optBtn = Instance.new("TextButton")
						optBtn.Size = UDim2.new(1, 0, 0, 28)
						optBtn.BackgroundColor3 = t.Background
						optBtn.BackgroundTransparency = 0.3
						optBtn.Text = "  " .. tostring(opt)
						optBtn.TextColor3 = t.TextSecondary
						optBtn.FontFace = t.Font
						optBtn.TextSize = 12
						optBtn.TextXAlignment = Enum.TextXAlignment.Left
						optBtn.BorderSizePixel = 0
						optBtn.LayoutOrder = layoutIdx
						CreateCorner(optBtn, 6)
						optBtn.Parent = optionsContainer

						-- Hover
						optBtn.MouseEnter:Connect(function()
							if not (multi and type(obj.Value) == "table" and obj.Value[opt]) and obj.Value ~= opt then
								Tween(optBtn, TI_SNAP, {BackgroundTransparency = 0})
							end
						end)
						optBtn.MouseLeave:Connect(function()
							if not (multi and type(obj.Value) == "table" and obj.Value[opt]) and obj.Value ~= opt then
								Tween(optBtn, TI_SNAP, {BackgroundTransparency = 0.3})
							end
						end)

						if multi then
							local isSelected = type(obj.Value) == "table" and obj.Value[opt] == true
							if isSelected then
								optBtn.BackgroundColor3 = t.Accent
								optBtn.BackgroundTransparency = 0.3
								optBtn.TextColor3 = t.TextPrimary
							end
							optBtn.MouseButton1Click:Connect(function()
								if obj._locked then return end
								if type(obj.Value) ~= "table" then obj.Value = {} end
								if obj.Value[opt] then
									obj.Value[opt] = nil
									Tween(optBtn, TI_FAST, {BackgroundColor3 = t.Background, BackgroundTransparency = 0.3})
									optBtn.TextColor3 = t.TextSecondary
								else
									obj.Value[opt] = true
									Tween(optBtn, TI_FAST, {BackgroundColor3 = t.Accent, BackgroundTransparency = 0.3})
									optBtn.TextColor3 = t.TextPrimary
								end
								selLbl.Text = getDisplayText()
								if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
								safeCallback(cfg.Callback, obj.Value)
								fireChanged(obj, obj.Value)
							end)
						else
							if obj.Value == opt then
								optBtn.BackgroundColor3 = t.Accent
								optBtn.BackgroundTransparency = 0.3
								optBtn.TextColor3 = t.TextPrimary
							end
							optBtn.MouseButton1Click:Connect(function()
								if obj._locked then return end
								obj.Value = opt
								selLbl.Text = getDisplayText()
								if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
								safeCallback(cfg.Callback, obj.Value)
								fireChanged(obj, obj.Value)
								isOpen = false
								Tween(frame, TI_MED, {Size = UDim2.new(1, 0, 0, headerH)})
								buildOptions()
							end)
						end
					end
				end

				selLbl.Text = getDisplayText()
				buildOptions()

				if hasSearch and searchBox then
					searchBox:GetPropertyChangedSignal("Text"):Connect(function()
						searchFilter = searchBox.Text
						buildOptions()
						if isOpen then
							Tween(frame, TI_FAST, {Size = UDim2.new(1, 0, 0, calcOpenHeight())})
						end
					end)
				end

				local headerBtn = Instance.new("TextButton")
				headerBtn.Size = UDim2.new(1, 0, 0, headerH)
				headerBtn.BackgroundTransparency = 1
				headerBtn.Text = ""
				headerBtn.ZIndex = 5
				headerBtn.Parent = frame

				headerBtn.MouseButton1Click:Connect(function()
					if obj._locked then return end
					isOpen = not isOpen
					if isOpen then
						searchFilter = ""
						if searchBox then searchBox.Text = "" end
						buildOptions()
						Tween(frame, TI_FAST, {BackgroundTransparency = 0})
					else
						Tween(frame, TI_FAST, {BackgroundTransparency = 1})
					end
					Tween(frame, TI_MED, {Size = UDim2.new(1, 0, 0, isOpen and calcOpenHeight() or headerH)})
				end)

				function obj:SetValue(v)
					obj.Value = v
					selLbl.Text = getDisplayText()
					if cfg.Flag then updateFlag(cfg.Flag, v) end
					if not _isLoadingConfig then safeCallback(cfg.Callback, v) end
					fireChanged(obj, v)
					buildOptions()
				end

				function obj:SetOptions(newOpts)
					options = newOpts
					buildOptions()
					if isOpen then
						Tween(frame, TI_FAST, {Size = UDim2.new(1, 0, 0, calcOpenHeight())})
					end
				end

				function obj:InsertOptions(newOpts)
					for _, opt in ipairs(newOpts) do
						if not table.find(options, opt) then
							table.insert(options, opt)
						end
					end
					buildOptions()
					if isOpen then
						Tween(frame, TI_FAST, {Size = UDim2.new(1, 0, 0, calcOpenHeight())})
					end
				end

				function obj:ClearOptions()
					options = {}
					buildOptions()
					if isOpen then
						Tween(frame, TI_FAST, {Size = UDim2.new(1, 0, 0, calcOpenHeight())})
					end
				end

				if cfg.Special == 1 then
					local function refreshPlayers()
						local names = {}
						for _, p in ipairs(Players:GetPlayers()) do
							if p ~= LocalPlayer then table.insert(names, p.Name) end
						end
						options = names
						buildOptions()
					end
					refreshPlayers()
					local c1 = Players.PlayerAdded:Connect(refreshPlayers)
					local c2 = Players.PlayerRemoving:Connect(refreshPlayers)
					table.insert(_connections, c1)
					table.insert(_connections, c2)
				end

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Dropdown", cfg.Flag)
				return obj
			end

			-- BUTTON — with gradient and ripple
			function Section:Button(cfg)
				elemOrder = elemOrder + 1
				local hasDesc = cfg.Description and cfg.Description ~= ""

				if hasDesc then
					local frame = Instance.new("Frame")
					frame.Name = "Btn_" .. (cfg.Name or "")
					frame.Size = UDim2.new(1, 0, 0, 50)
					frame.BackgroundColor3 = t.Accent
					frame.BackgroundTransparency = 0.05
					frame.BorderSizePixel = 0
					frame.LayoutOrder = elemOrder
					frame.ClipsDescendants = true
					CreateCorner(frame, 8)
					ApplyAccentGradient(frame)
					frame.Parent = sec

					local nameLbl = Instance.new("TextLabel")
					nameLbl.Size = UDim2.new(1, -16, 0, 20)
					nameLbl.Position = UDim2.fromOffset(0, 8)
					nameLbl.BackgroundTransparency = 1
					nameLbl.Text = cfg.Name or "Button"
					nameLbl.TextColor3 = t.TextPrimary
					nameLbl.FontFace = t.FontBold
					nameLbl.TextSize = 13
					nameLbl.TextXAlignment = Enum.TextXAlignment.Left
					nameLbl.Parent = frame

					local descLbl = Instance.new("TextLabel")
					descLbl.Size = UDim2.new(1, -16, 0, 14)
					descLbl.Position = UDim2.fromOffset(0, 29)
					descLbl.BackgroundTransparency = 1
					descLbl.Text = cfg.Description
					descLbl.TextColor3 = t.TextPrimary
					descLbl.TextTransparency = 0.35
					descLbl.FontFace = t.Font
					descLbl.TextSize = 11
					descLbl.TextXAlignment = Enum.TextXAlignment.Left
					descLbl.TextTruncate = Enum.TextTruncate.AtEnd
					descLbl.Parent = frame

					local clickBtn = Instance.new("TextButton")
					clickBtn.Size = UDim2.new(1, 0, 1, 0)
					clickBtn.BackgroundTransparency = 1
					clickBtn.Text = ""
					clickBtn.ZIndex = 5
					clickBtn.Parent = frame

					clickBtn.MouseEnter:Connect(function() Tween(frame, TI_FAST, {BackgroundTransparency = 0}) end)
					clickBtn.MouseLeave:Connect(function() Tween(frame, TI_FAST, {BackgroundTransparency = 0.05}) end)
					clickBtn.MouseButton1Click:Connect(function()
						RippleEffect(frame, Vector2.new(Mouse.X, Mouse.Y))
						safeCallback(cfg.Callback)
					end)

					local obj = {Instance = frame, Value = nil}
					wrapElement(obj, "Button", nil)
					function obj:AddKeybind(kcfg) return Section:_addNestedKeybind(frame, kcfg) end
					return obj
				else
					local btn = Instance.new("TextButton")
					btn.Name = "Btn_" .. (cfg.Name or "")
					btn.Size = UDim2.new(1, 0, 0, 34)
					btn.BackgroundColor3 = t.Accent
					btn.BackgroundTransparency = 0.05
					btn.Text = cfg.Name or "Button"
					btn.TextColor3 = t.TextPrimary
					btn.FontFace = t.FontBold
					btn.TextSize = 13
					btn.BorderSizePixel = 0
					btn.LayoutOrder = elemOrder
					CreateCorner(btn, 8)
					ApplyAccentGradient(btn)
					btn.Parent = sec
					btn.ClipsDescendants = true

					btn.MouseEnter:Connect(function() Tween(btn, TI_FAST, {BackgroundTransparency = 0}) end)
					btn.MouseLeave:Connect(function() Tween(btn, TI_FAST, {BackgroundTransparency = 0.05}) end)
					btn.MouseButton1Click:Connect(function()
						RippleEffect(btn, Vector2.new(Mouse.X, Mouse.Y))
						safeCallback(cfg.Callback)
					end)

					local obj = {Instance = btn, Value = nil}
					wrapElement(obj, "Button", nil)
					function obj:AddKeybind(kcfg) return Section:_addNestedKeybind(btn, kcfg) end
					return obj
				end
			end

			-- INPUT — AutomaticSize, clean
			function Section:Input(cfg)
				elemOrder = elemOrder + 1
				local hasDesc = cfg.Description and cfg.Description ~= ""
				local obj = {Value = cfg.Default or ""}

				local frame = Instance.new("Frame")
				frame.Name = "Inp_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, 0)
				frame.AutomaticSize = Enum.AutomaticSize.Y
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.LayoutOrder = elemOrder
				frame.Parent = sec
				CreatePadding(frame, 2, 2, 0, 0)
				CreateList(frame, 4)

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.LayoutOrder = 1
				lbl.Parent = frame
				registerThemed(lbl, "TextColor3", "TextPrimary")

				if hasDesc then
					local descLbl = Instance.new("TextLabel")
					descLbl.Size = UDim2.new(1, 0, 0, 12)
					descLbl.BackgroundTransparency = 1
					descLbl.Text = cfg.Description
					descLbl.TextColor3 = t.TextDimmed
					descLbl.FontFace = t.Font
					descLbl.TextSize = 10
					descLbl.TextXAlignment = Enum.TextXAlignment.Left
					descLbl.TextTruncate = Enum.TextTruncate.AtEnd
					descLbl.LayoutOrder = 2
					descLbl.Parent = frame
					registerThemed(descLbl, "TextColor3", "TextDimmed")
				end

				local inputBg = Instance.new("Frame")
				inputBg.Size = UDim2.new(1, 0, 0, 26)
				inputBg.BackgroundColor3 = t.Background
				inputBg.BorderSizePixel = 0
				inputBg.LayoutOrder = 3
				CreateCorner(inputBg, 6)
				inputBg.Parent = frame
				registerThemed(inputBg, "BackgroundColor3", "Background")

				local textBox = Instance.new("TextBox")
				textBox.Size = UDim2.new(1, -14, 1, 0)
				textBox.Position = UDim2.fromOffset(7, 0)
				textBox.BackgroundTransparency = 1
				textBox.Text = obj.Value
				textBox.PlaceholderText = cfg.Placeholder or ""
				textBox.PlaceholderColor3 = t.TextDimmed
				textBox.TextColor3 = t.TextPrimary
				textBox.FontFace = t.Font
				textBox.TextSize = 12
				textBox.TextXAlignment = Enum.TextXAlignment.Left
				textBox.ClearTextOnFocus = cfg.ClearOnFocus or false
				textBox.Parent = inputBg

				-- Focus highlight via background
				textBox.Focused:Connect(function()
					Tween(inputBg, TI_FAST, {BackgroundColor3 = t.TertiaryBackground})
				end)
				textBox.FocusLost:Connect(function()
					Tween(inputBg, TI_FAST, {BackgroundColor3 = t.Background})
					if obj._locked then return end
					obj.Value = textBox.Text
					if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
					safeCallback(cfg.Callback, obj.Value)
					fireChanged(obj, obj.Value)
				end)

				obj.Instance = frame

				function obj:SetValue(v)
					obj.Value = v
					textBox.Text = v
					if cfg.Flag then updateFlag(cfg.Flag, v) end
					if not _isLoadingConfig then safeCallback(cfg.Callback, v) end
					fireChanged(obj, v)
				end

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Input", cfg.Flag)
				return obj
			end

			-- KEYBIND — AutomaticSize, AnchorPoint-centered
			function Section:Keybind(cfg)
				elemOrder = elemOrder + 1
				local hasDesc = cfg.Description and cfg.Description ~= ""
				local obj = {Value = cfg.Default or Enum.KeyCode.Unknown}

				local frame = Instance.new("Frame")
				frame.Name = "KB_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, 0)
				frame.AutomaticSize = Enum.AutomaticSize.Y
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.LayoutOrder = elemOrder
				frame.Parent = sec
				CreatePadding(frame, 4, 4, 0, 0)

				local textContainer = Instance.new("Frame")
				textContainer.Size = UDim2.new(1, -64, 0, 0)
				textContainer.AutomaticSize = Enum.AutomaticSize.Y
				textContainer.BackgroundTransparency = 1
				textContainer.Parent = frame
				CreateList(textContainer, 2)

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.LayoutOrder = 1
				lbl.Parent = textContainer
				registerThemed(lbl, "TextColor3", "TextPrimary")

				if hasDesc then
					local kbDescLbl = Instance.new("TextLabel")
					kbDescLbl.Size = UDim2.new(1, 0, 0, 12)
					kbDescLbl.BackgroundTransparency = 1
					kbDescLbl.Text = cfg.Description
					kbDescLbl.TextColor3 = t.TextDimmed
					kbDescLbl.FontFace = t.Font
					kbDescLbl.TextSize = 10
					kbDescLbl.TextXAlignment = Enum.TextXAlignment.Left
					kbDescLbl.TextTruncate = Enum.TextTruncate.AtEnd
					kbDescLbl.LayoutOrder = 2
					kbDescLbl.Parent = textContainer
					registerThemed(kbDescLbl, "TextColor3", "TextDimmed")
				end

				-- Keybind button — AnchorPoint centered
				local keyBtn = Instance.new("TextButton")
				keyBtn.Size = UDim2.fromOffset(50, 22)
				keyBtn.AnchorPoint = Vector2.new(1, 0.5)
				keyBtn.Position = UDim2.new(1, 0, 0.5, 0)
				keyBtn.BackgroundColor3 = t.TertiaryBackground
				keyBtn.Text = obj.Value.Name or "None"
				keyBtn.TextColor3 = t.TextSecondary
				keyBtn.FontFace = t.FontBold
				keyBtn.TextSize = 10
				keyBtn.BorderSizePixel = 0
				CreateCorner(keyBtn, 6)
				keyBtn.Parent = frame

				local listening = false
				obj.Instance = frame

				keyBtn.MouseButton1Click:Connect(function()
					if obj._locked then return end
					listening = true
					keyBtn.Text = "..."
					Tween(keyBtn, TI_FAST, {BackgroundColor3 = t.Accent})
					keyBtn.TextColor3 = t.TextPrimary
				end)

				local kbConn = UserInputService.InputBegan:Connect(function(input, gpe)
					if listening then
						if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
							obj.Value = Enum.KeyCode.Unknown
							keyBtn.Text = "None"
						elseif input.KeyCode ~= Enum.KeyCode.Unknown then
							obj.Value = input.KeyCode
							keyBtn.Text = input.KeyCode.Name
							if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
							if cfg.ChangedCallback then pcall(cfg.ChangedCallback, obj.Value) end
							fireChanged(obj, obj.Value)
						end
						listening = false
						Tween(keyBtn, TI_FAST, {BackgroundColor3 = t.QuaternaryBackground})
						keyBtn.TextColor3 = t.TextSecondary
						return
					end

					if not listening and obj.Value and obj.Value ~= Enum.KeyCode.Unknown and input.KeyCode == obj.Value then
						if cfg.IgnoreGameInput and gpe then return end
						if UserInputService:GetFocusedTextBox() then return end
						safeCallback(cfg.Callback, obj.Value)
					end
				end)
				table.insert(_connections, kbConn)

				function obj:SetValue(v)
					if type(v) == "string" then
						pcall(function() v = Enum.KeyCode[v] end)
					end
					obj.Value = v
					keyBtn.Text = v and v.Name or "None"
					if cfg.Flag then updateFlag(cfg.Flag, v) end
					fireChanged(obj, v)
				end

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Keybind", cfg.Flag)
				return obj
			end

			-- COLORPICKER — AnchorPoint-centered preview
			function Section:Colorpicker(cfg)
				elemOrder = elemOrder + 1
				local obj = {Value = cfg.Default or Color3.new(1, 1, 1), Alpha = cfg.Alpha or 1}

				local frame = Instance.new("Frame")
				frame.Name = "Clr_" .. (cfg.Name or "")
				frame.Size = UDim2.new(1, 0, 0, 0)
				frame.AutomaticSize = Enum.AutomaticSize.Y
				frame.BackgroundTransparency = 1
				frame.BorderSizePixel = 0
				frame.LayoutOrder = elemOrder
				frame.Parent = sec
				CreatePadding(frame, 4, 4, 0, 0)

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -36, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Text = cfg.Name or ""
				lbl.TextColor3 = t.TextPrimary
				lbl.FontFace = t.Font
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = frame
				registerThemed(lbl, "TextColor3", "TextPrimary")

				-- Color preview — AnchorPoint centered
				local preview = Instance.new("Frame")
				preview.Size = UDim2.fromOffset(20, 20)
				preview.AnchorPoint = Vector2.new(1, 0.5)
				preview.Position = UDim2.new(1, 0, 0.5, 0)
				preview.BackgroundColor3 = obj.Value
				preview.BorderSizePixel = 0
				CreateCorner(preview, 5)
				preview.Parent = frame

				local function HSVtoRGB(h, s, v)
					return Color3.fromHSV(math.clamp(h, 0, 1), math.clamp(s, 0, 1), math.clamp(v, 0, 1))
				end

				local panelOpen = false
				local panel

				local prevBtn = Instance.new("TextButton")
				prevBtn.Size = UDim2.new(1, 0, 1, 0)
				prevBtn.BackgroundTransparency = 1
				prevBtn.Text = ""
				prevBtn.ZIndex = 5
				prevBtn.Parent = frame

				local h, s, v = Color3.toHSV(obj.Value)

				prevBtn.MouseButton1Click:Connect(function()
					if obj._locked then return end
					if panelOpen and panel then
						panel:Destroy()
						panelOpen = false
						return
					end
					panelOpen = true
					h, s, v = Color3.toHSV(obj.Value)

					panel = Instance.new("Frame")
					panel.Size = UDim2.fromOffset(210, 210)
					-- Anchor to preview button, not frame
					local previewAbsX = preview.AbsolutePosition.X - mainFrame.AbsolutePosition.X
					local previewAbsY = preview.AbsolutePosition.Y - mainFrame.AbsolutePosition.Y
					-- Position below the preview, clamped to window
					local panelX = math.clamp(previewAbsX - 180, 10, mainFrame.AbsoluteSize.X - 220)
					local panelY = math.clamp(previewAbsY + 28, 10, mainFrame.AbsoluteSize.Y - 220)
					panel.Position = UDim2.fromOffset(panelX, panelY)
					panel.BackgroundColor3 = t.SecondaryBackground
					panel.BorderSizePixel = 0
					panel.ZIndex = 50
					CreateCorner(panel, 10)
					CreateStroke(panel, t.Border, 1, 0.2)
					panel.Parent = mainFrame

					local hsvSquare = Instance.new("Frame")
					hsvSquare.Size = UDim2.fromOffset(135, 95)
					hsvSquare.Position = UDim2.fromOffset(10, 10)
					hsvSquare.BackgroundColor3 = HSVtoRGB(h, 1, 1)
					hsvSquare.BorderSizePixel = 0
					hsvSquare.ZIndex = 51
					CreateCorner(hsvSquare, 6)
					hsvSquare.Parent = panel

					local wg = Instance.new("UIGradient")
					wg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
					wg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
					wg.Parent = hsvSquare

					local bo = Instance.new("Frame")
					bo.Size = UDim2.new(1, 0, 1, 0)
					bo.BackgroundColor3 = Color3.new(0, 0, 0)
					bo.BackgroundTransparency = 0
					bo.BorderSizePixel = 0
					bo.ZIndex = 52
					CreateCorner(bo, 6)
					bo.Parent = hsvSquare

					local bg = Instance.new("UIGradient")
					bg.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))
					bg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
					bg.Rotation = 90
					bg.Parent = bo

					local hueBar = Instance.new("Frame")
					hueBar.Size = UDim2.fromOffset(18, 95)
					hueBar.Position = UDim2.fromOffset(153, 10)
					hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
					hueBar.BorderSizePixel = 0
					hueBar.ZIndex = 51
					CreateCorner(hueBar, 6)
					hueBar.Parent = panel

					local hg = Instance.new("UIGradient")
					hg.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
						ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
						ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
						ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
						ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
					})
					hg.Rotation = 90
					hg.Parent = hueBar

					local hexBg = Instance.new("Frame")
					hexBg.Size = UDim2.new(1, -20, 0, 24)
					hexBg.Position = UDim2.fromOffset(10, 114)
					hexBg.BackgroundColor3 = t.TertiaryBackground
					hexBg.BorderSizePixel = 0
					hexBg.ZIndex = 51
					CreateCorner(hexBg, 6)
					hexBg.Parent = panel

					local hexBox = Instance.new("TextBox")
					hexBox.Size = UDim2.new(1, -12, 1, 0)
					hexBox.Position = UDim2.fromOffset(6, 0)
					hexBox.BackgroundTransparency = 1
					hexBox.Text = string.format("#%02X%02X%02X", obj.Value.R * 255, obj.Value.G * 255, obj.Value.B * 255)
					hexBox.TextColor3 = t.TextSecondary
					hexBox.FontFace = t.Font
					hexBox.TextSize = 11
					hexBox.TextXAlignment = Enum.TextXAlignment.Left
					hexBox.ZIndex = 52
					hexBox.Parent = hexBg

					local cpPreview = Instance.new("Frame")
					cpPreview.Size = UDim2.new(1, -20, 0, 22)
					cpPreview.Position = UDim2.fromOffset(10, 146)
					cpPreview.BackgroundColor3 = obj.Value
					cpPreview.BorderSizePixel = 0
					cpPreview.ZIndex = 51
					CreateCorner(cpPreview, 6)
					cpPreview.Parent = panel

					local applyBtn = Instance.new("TextButton")
					applyBtn.Size = UDim2.new(1, -20, 0, 26)
					applyBtn.Position = UDim2.fromOffset(10, 176)
					applyBtn.BackgroundColor3 = t.Accent
					applyBtn.Text = "Apply"
					applyBtn.TextColor3 = t.TextPrimary
					applyBtn.FontFace = t.FontBold
					applyBtn.TextSize = 12
					applyBtn.BorderSizePixel = 0
					applyBtn.ZIndex = 51
					CreateCorner(applyBtn, 6)
					ApplyAccentGradient(applyBtn)
					applyBtn.Parent = panel

					local function updateColor()
						local newColor = HSVtoRGB(h, s, v)
						obj.Value = newColor
						preview.BackgroundColor3 = newColor
						cpPreview.BackgroundColor3 = newColor
						hsvSquare.BackgroundColor3 = HSVtoRGB(h, 1, 1)
						hexBox.Text = string.format("#%02X%02X%02X", newColor.R * 255, newColor.G * 255, newColor.B * 255)
					end

					local svDrag = false
					local svBtn = Instance.new("TextButton")
					svBtn.Size = UDim2.new(1, 0, 1, 0)
					svBtn.BackgroundTransparency = 1
					svBtn.Text = ""
					svBtn.ZIndex = 53
					svBtn.Parent = hsvSquare
					svBtn.MouseButton1Down:Connect(function() svDrag = true end)

					local hueDrag = false
					local hueBtn = Instance.new("TextButton")
					hueBtn.Size = UDim2.new(1, 0, 1, 0)
					hueBtn.BackgroundTransparency = 1
					hueBtn.Text = ""
					hueBtn.ZIndex = 52
					hueBtn.Parent = hueBar
					hueBtn.MouseButton1Down:Connect(function() hueDrag = true end)

					local cpConn = UserInputService.InputChanged:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
						if svDrag then
							s = math.clamp((input.Position.X - hsvSquare.AbsolutePosition.X) / hsvSquare.AbsoluteSize.X, 0, 1)
							v = 1 - math.clamp((input.Position.Y - hsvSquare.AbsolutePosition.Y) / hsvSquare.AbsoluteSize.Y, 0, 1)
							updateColor()
						end
						if hueDrag then
							h = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
							updateColor()
						end
					end)

					local cpEnd = UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							svDrag = false
							hueDrag = false
						end
					end)

					applyBtn.MouseButton1Click:Connect(function()
						if cfg.Flag then updateFlag(cfg.Flag, obj.Value) end
						safeCallback(cfg.Callback, obj.Value, obj.Alpha)
						fireChanged(obj, obj.Value)
						panel:Destroy()
						panelOpen = false
						cpConn:Disconnect()
						cpEnd:Disconnect()
					end)

					hexBox.FocusLost:Connect(function()
						local hex = hexBox.Text:gsub("#", "")
						if #hex == 6 then
							local r2 = tonumber(hex:sub(1, 2), 16) or 255
							local g2 = tonumber(hex:sub(3, 4), 16) or 255
							local b2 = tonumber(hex:sub(5, 6), 16) or 255
							obj.Value = Color3.fromRGB(r2, g2, b2)
							h, s, v = Color3.toHSV(obj.Value)
							updateColor()
						end
					end)
				end)

				function obj:SetValue(col, alpha)
					obj.Value = col
					if alpha then obj.Alpha = alpha end
					preview.BackgroundColor3 = col
					if cfg.Flag then updateFlag(cfg.Flag, col) end
					if not _isLoadingConfig then safeCallback(cfg.Callback, col, obj.Alpha) end
					fireChanged(obj, col)
				end

				if cfg.Flag then registerFlag(cfg.Flag, obj.Value, obj) end
				wrapElement(obj, "Colorpicker", cfg.Flag)
				return obj
			end

			-- HEADER
			function Section:Header(cfg)
				elemOrder = elemOrder + 1
				local h = Instance.new("TextLabel")
				h.Size = UDim2.new(1, 0, 0, 24)
				h.BackgroundTransparency = 1
				h.Text = cfg.Text or ""
				h.TextColor3 = t.TextPrimary
				h.FontFace = t.FontBold
				h.TextSize = 15
				h.TextXAlignment = Enum.TextXAlignment.Left
				h.LayoutOrder = elemOrder
				h.Parent = sec
				registerThemed(h, "TextColor3", "TextPrimary")
				return {Instance = h}
			end

			-- LABEL
			function Section:Label(cfg)
				elemOrder = elemOrder + 1
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, 0, 0, 20)
				l.BackgroundTransparency = 1
				l.Text = cfg.Text or ""
				l.TextColor3 = t.TextSecondary
				l.FontFace = t.Font
				l.TextSize = 13
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.LayoutOrder = elemOrder
				l.Parent = sec
				registerThemed(l, "TextColor3", "TextSecondary")

				local obj = {Instance = l}
				function obj:SetText(text) l.Text = text end
				function obj:AddKeybind(kcfg) return Section:_addNestedKeybind(l, kcfg) end
				return obj
			end

			-- PARAGRAPH
			function Section:Paragraph(cfg)
				elemOrder = elemOrder + 1
				local pf = Instance.new("Frame")
				pf.Size = UDim2.new(1, 0, 0, 0)
				pf.AutomaticSize = Enum.AutomaticSize.Y
				pf.BackgroundTransparency = 1
				pf.LayoutOrder = elemOrder
				pf.Parent = sec
				CreateList(pf, 3)

				local ph = Instance.new("TextLabel")
				ph.Size = UDim2.new(1, 0, 0, 20)
				ph.BackgroundTransparency = 1
				ph.Text = cfg.Header or ""
				ph.TextColor3 = t.TextPrimary
				ph.FontFace = t.FontBold
				ph.TextSize = 14
				ph.TextXAlignment = Enum.TextXAlignment.Left
				ph.LayoutOrder = 1
				ph.Parent = pf
				registerThemed(ph, "TextColor3", "TextPrimary")

				local pb = Instance.new("TextLabel")
				pb.Size = UDim2.new(1, 0, 0, 0)
				pb.AutomaticSize = Enum.AutomaticSize.Y
				pb.BackgroundTransparency = 1
				pb.Text = cfg.Body or ""
				pb.TextColor3 = t.TextSecondary
				pb.FontFace = t.Font
				pb.TextSize = 12
				pb.TextXAlignment = Enum.TextXAlignment.Left
				pb.TextWrapped = true
				pb.LayoutOrder = 2
				pb.Parent = pf
				registerThemed(pb, "TextColor3", "TextSecondary")

				local obj = {Instance = pf}
				function obj:SetHeader(text) ph.Text = text end
				function obj:SetBody(text) pb.Text = text end
				return obj
			end

			-- DIVIDER
			function Section:Divider()
				elemOrder = elemOrder + 1
				local d = Instance.new("Frame")
				d.Size = UDim2.new(1, 0, 0, 1)
				d.BackgroundColor3 = t.Divider
				d.BackgroundTransparency = 0.4
				d.BorderSizePixel = 0
				d.LayoutOrder = elemOrder
				d.Parent = sec
				registerThemed(d, "BackgroundColor3", "Divider")
				return {Instance = d}
			end

			-- SPACER
			function Section:Spacer(cfg)
				elemOrder = elemOrder + 1
				local s = Instance.new("Frame")
				s.Size = UDim2.new(1, 0, 0, (cfg and cfg.Height) or 10)
				s.BackgroundTransparency = 1
				s.LayoutOrder = elemOrder
				s.Parent = sec
				return {Instance = s}
			end

			-- MENU (collapsible)
			function Section:Menu(cfg)
				elemOrder = elemOrder + 1
				local menuName = cfg.Name or "Menu"
				local isExpanded = cfg.DefaultOpen ~= false

				local container = Instance.new("Frame")
				container.Name = "Menu_" .. menuName
				container.Size = UDim2.new(1, 0, 0, 0)
				container.AutomaticSize = Enum.AutomaticSize.Y
				container.BackgroundTransparency = 1
				container.ClipsDescendants = true
				container.LayoutOrder = elemOrder
				container.Parent = sec

				local header = Instance.new("TextButton")
				header.Size = UDim2.new(1, 0, 0, 28)
				header.BackgroundColor3 = t.TertiaryBackground
				header.BackgroundTransparency = 0.7
				header.BorderSizePixel = 0
				header.Text = ""
				header.LayoutOrder = 0
				CreateCorner(header, 6)
				header.Parent = container

				local arrow = Instance.new("TextLabel")
				arrow.Size = UDim2.fromOffset(16, 30)
				arrow.Position = UDim2.fromOffset(8, 0)
				arrow.BackgroundTransparency = 1
				arrow.Text = isExpanded and "▼" or "▶"
				arrow.TextColor3 = t.TextDimmed
				arrow.FontFace = t.Font
				arrow.TextSize = 10
				arrow.Parent = header

				local menuLbl = Instance.new("TextLabel")
				menuLbl.Size = UDim2.new(1, -30, 0, 30)
				menuLbl.Position = UDim2.fromOffset(24, 0)
				menuLbl.BackgroundTransparency = 1
				menuLbl.Text = menuName
				menuLbl.TextColor3 = t.TextSecondary
				menuLbl.FontFace = t.FontBold
				menuLbl.TextSize = 12
				menuLbl.TextXAlignment = Enum.TextXAlignment.Left
				menuLbl.Parent = header

				local menuContent = Instance.new("Frame")
				menuContent.Name = "MenuContent"
				menuContent.Size = UDim2.new(1, 0, 0, 0)
				menuContent.AutomaticSize = Enum.AutomaticSize.Y
				menuContent.BackgroundTransparency = 1
				menuContent.Visible = isExpanded
				menuContent.LayoutOrder = 1
				menuContent.Parent = container
				CreateList(menuContent, 5)
				CreatePadding(menuContent, 4, 0, 0, 0)

				header.MouseButton1Click:Connect(function()
					isExpanded = not isExpanded
					menuContent.Visible = isExpanded
					arrow.Text = isExpanded and "▼" or "▶"
				end)

				CreateList(container, 2)

				local MenuSection = {}
				local menuElemOrder = 0

				local function makeMenuElement(methodName)
					return function(_, mcfg)
						local savedSec = sec
						sec = menuContent
						local savedOrder = elemOrder
						menuElemOrder = menuElemOrder + 1
						elemOrder = menuElemOrder
						local result = Section[methodName](Section, mcfg)
						elemOrder = savedOrder
						sec = savedSec
						return result
					end
				end

				MenuSection.Toggle = makeMenuElement("Toggle")
				MenuSection.Slider = makeMenuElement("Slider")
				MenuSection.Dropdown = makeMenuElement("Dropdown")
				MenuSection.Button = makeMenuElement("Button")
				MenuSection.Input = makeMenuElement("Input")
				MenuSection.Keybind = makeMenuElement("Keybind")
				MenuSection.Colorpicker = makeMenuElement("Colorpicker")
				MenuSection.Header = makeMenuElement("Header")
				MenuSection.Label = makeMenuElement("Label")
				MenuSection.Paragraph = makeMenuElement("Paragraph")
				MenuSection.Divider = makeMenuElement("Divider")
				MenuSection.Spacer = makeMenuElement("Spacer")

				MenuSection.Instance = container
				function MenuSection:SetExpanded(v)
					isExpanded = v
					menuContent.Visible = v
					arrow.Text = v and "▼" or "▶"
				end

				return MenuSection
			end

			-- ══════════════════════════════
			-- // 15. NESTED ELEMENTS
			-- ══════════════════════════════
			function Section:_addNestedKeybind(parent, kcfg)
				local nObj = {Value = kcfg.Default or Enum.KeyCode.Unknown}

				local kb = Instance.new("TextButton")
				kb.Size = UDim2.fromOffset(28, 20)
				kb.Position = UDim2.new(1, -84, 0.5, -10)
				kb.BackgroundColor3 = t.QuaternaryBackground
				kb.Text = nObj.Value and nObj.Value.Name or "None"
				kb.TextColor3 = t.TextSecondary
				kb.FontFace = t.Font
				kb.TextSize = 9
				kb.BorderSizePixel = 0
				kb.ZIndex = 6
				CreateCorner(kb, 4)
				kb.Parent = parent

				local listening = false
				kb.MouseButton1Click:Connect(function()
					listening = true
					kb.Text = "..."
					Tween(kb, TI_FAST, {BackgroundColor3 = t.Accent})
				end)

				local conn = UserInputService.InputBegan:Connect(function(input, gpe)
					if listening then
						if input.KeyCode == Enum.KeyCode.Escape then
							nObj.Value = Enum.KeyCode.Unknown
							kb.Text = "None"
						elseif input.KeyCode ~= Enum.KeyCode.Unknown then
							nObj.Value = input.KeyCode
							kb.Text = input.KeyCode.Name
							if kcfg.Flag then updateFlag(kcfg.Flag, nObj.Value) end
						end
						listening = false
						Tween(kb, TI_FAST, {BackgroundColor3 = t.QuaternaryBackground})
						return
					end
					if nObj.Value and nObj.Value ~= Enum.KeyCode.Unknown and input.KeyCode == nObj.Value then
						if UserInputService:GetFocusedTextBox() then return end
						if kcfg.Callback then pcall(kcfg.Callback, nObj.Value) end
					end
				end)
				table.insert(_connections, conn)

				nObj.Instance = kb
				nObj._type = "Keybind"
				function nObj:SetValue(v)
					if type(v) == "string" then pcall(function() v = Enum.KeyCode[v] end) end
					nObj.Value = v
					kb.Text = v and v.Name or "None"
					if kcfg.Flag then updateFlag(kcfg.Flag, v) end
				end

				if kcfg.Flag then registerFlag(kcfg.Flag, nObj.Value, nObj) end
				return nObj
			end

			function Section:_addNestedColorpicker(parent, ccfg)
				local nObj = {Value = ccfg.Default or Color3.new(1, 0, 0)}

				local cp = Instance.new("Frame")
				cp.Size = UDim2.fromOffset(18, 18)
				cp.Position = UDim2.new(1, -106, 0.5, -9)
				cp.BackgroundColor3 = nObj.Value
				cp.BorderSizePixel = 0
				cp.ZIndex = 6
				CreateCorner(cp, 5)
				cp.Parent = parent

				nObj.Instance = cp
				nObj._type = "Colorpicker"
				function nObj:SetValue(v)
					nObj.Value = v
					cp.BackgroundColor3 = v
					if ccfg.Flag then updateFlag(ccfg.Flag, v) end
				end

				if ccfg.Flag then registerFlag(ccfg.Flag, nObj.Value, nObj) end
				return nObj
			end

			function Section:_addNestedDropdown(parent, dcfg)
				local nObj = {Value = dcfg.Default or (dcfg.Options and dcfg.Options[1])}
				nObj._type = "Dropdown"
				function nObj:SetValue(v)
					nObj.Value = v
					if dcfg.Flag then updateFlag(dcfg.Flag, v) end
				end
				if dcfg.Flag then registerFlag(dcfg.Flag, nObj.Value, nObj) end
				return nObj
			end

			return Section
		end

		table.insert(Window._tabs, Tab)

		if #Window._tabs == 1 then
			selectThis()
		end

		return Tab
	end

	function Window:CreateTab(cfg)
		return Window:_createTab(cfg, 0)
	end

	-- ══════════════════════════════
	-- // 16. DIALOG — refined
	-- ══════════════════════════════
	function Window:Dialog(cfg)
		local overlay = Instance.new("Frame")
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 0.45
		overlay.ZIndex = 100
		overlay.BorderSizePixel = 0
		overlay.Parent = mainFrame

		local box = Instance.new("Frame")
		box.Size = UDim2.fromOffset(320, cfg.Input and 195 or 170)
		box.Position = UDim2.new(0.5, -160, 0.5, -90)
		box.BackgroundColor3 = t.SecondaryBackground
		box.BorderSizePixel = 0
		box.ZIndex = 101
		CreateCorner(box, 12)
		CreateStroke(box, t.Border, 1, 0.2)
		box.Parent = overlay

		local dTitle = Instance.new("TextLabel")
		dTitle.Size = UDim2.new(1, -32, 0, 22)
		dTitle.Position = UDim2.fromOffset(16, 16)
		dTitle.BackgroundTransparency = 1
		dTitle.Text = cfg.Title or "Dialog"
		dTitle.TextColor3 = t.TextPrimary
		dTitle.FontFace = t.FontBold
		dTitle.TextSize = 15
		dTitle.TextXAlignment = Enum.TextXAlignment.Left
		dTitle.ZIndex = 102
		dTitle.Parent = box

		local dBody = Instance.new("TextLabel")
		dBody.Size = UDim2.new(1, -32, 0, 36)
		dBody.Position = UDim2.fromOffset(16, 44)
		dBody.BackgroundTransparency = 1
		dBody.Text = cfg.Body or ""
		dBody.TextColor3 = t.TextSecondary
		dBody.FontFace = t.Font
		dBody.TextSize = 13
		dBody.TextXAlignment = Enum.TextXAlignment.Left
		dBody.TextWrapped = true
		dBody.ZIndex = 102
		dBody.Parent = box

		if cfg.Input then
			local inputBg = Instance.new("Frame")
			inputBg.Size = UDim2.new(1, -32, 0, 32)
			inputBg.Position = UDim2.fromOffset(16, 88)
			inputBg.BackgroundColor3 = t.TertiaryBackground
			inputBg.BorderSizePixel = 0
			inputBg.ZIndex = 102
			CreateCorner(inputBg, 8)
			CreateStroke(inputBg, t.Border, 1, 0.3)
			inputBg.Parent = box

			local tb = Instance.new("TextBox")
			tb.Size = UDim2.new(1, -14, 1, 0)
			tb.Position = UDim2.fromOffset(7, 0)
			tb.BackgroundTransparency = 1
			tb.PlaceholderText = cfg.Placeholder or ""
			tb.PlaceholderColor3 = t.TextDimmed
			tb.TextColor3 = t.TextPrimary
			tb.FontFace = t.Font
			tb.TextSize = 13
			tb.TextXAlignment = Enum.TextXAlignment.Left
			tb.ZIndex = 103
			tb.Parent = inputBg

			local confirmBtn = Instance.new("TextButton")
			confirmBtn.Size = UDim2.new(1, -32, 0, 32)
			confirmBtn.Position = UDim2.fromOffset(16, 130)
			confirmBtn.BackgroundColor3 = t.Accent
			confirmBtn.Text = "Confirm"
			confirmBtn.TextColor3 = t.TextPrimary
			confirmBtn.FontFace = t.FontBold
			confirmBtn.TextSize = 13
			confirmBtn.BorderSizePixel = 0
			confirmBtn.ZIndex = 102
			confirmBtn.ClipsDescendants = true
			CreateCorner(confirmBtn, 8)
			ApplyAccentGradient(confirmBtn)
			confirmBtn.Parent = box

			confirmBtn.MouseButton1Click:Connect(function()
				RippleEffect(confirmBtn, Vector2.new(Mouse.X, Mouse.Y))
				if cfg.Callback then pcall(cfg.Callback, tb.Text) end
				overlay:Destroy()
			end)
		else
			local btnContainer = Instance.new("Frame")
			btnContainer.Size = UDim2.new(1, -32, 0, 34)
			btnContainer.Position = UDim2.fromOffset(16, 104)
			btnContainer.BackgroundTransparency = 1
			btnContainer.ZIndex = 102
			btnContainer.Parent = box
			CreateList(btnContainer, 8, Enum.FillDirection.Horizontal)

			for i, btnCfg in ipairs(cfg.Buttons or {}) do
				local b = Instance.new("TextButton")
				b.Size = UDim2.fromOffset(120, 32)
				b.BackgroundColor3 = (i == 1) and t.TertiaryBackground or t.Accent
				b.BackgroundTransparency = (i == 1) and 0 or 0.05
				b.Text = btnCfg.Text or "OK"
				b.TextColor3 = t.TextPrimary
				b.FontFace = (i == 1) and t.Font or t.FontBold
				b.TextSize = 13
				b.BorderSizePixel = 0
				b.LayoutOrder = i
				b.ZIndex = 103
				b.ClipsDescendants = true
				CreateCorner(b, 8)
				if i == 1 then CreateStroke(b, t.Border, 1, 0.3) end
				if i > 1 then ApplyAccentGradient(b) end
				b.Parent = btnContainer
				b.MouseButton1Click:Connect(function()
					RippleEffect(b, Vector2.new(Mouse.X, Mouse.Y))
					if btnCfg.Callback then pcall(btnCfg.Callback) end
					overlay:Destroy()
				end)
			end
		end

		local overlayBtn = Instance.new("TextButton")
		overlayBtn.Size = UDim2.new(1, 0, 1, 0)
		overlayBtn.BackgroundTransparency = 1
		overlayBtn.Text = ""
		overlayBtn.ZIndex = 99
		overlayBtn.Parent = overlay
		overlayBtn.MouseButton1Click:Connect(function() overlay:Destroy() end)
	end

	-- ══════════════════════════════
	-- // 17. CONFIG SECTION
	-- ══════════════════════════════
	function Window:InsertConfigSection(tab)
		local sec = tab:CreateSection({Name = "Конфигурация", Side = "Left"})
		local configList = SkrilyaLib:GetConfigList()

		local dd = sec:Dropdown({
			Name = "Config",
			Options = configList,
			Default = _activeConfig or (configList[1]),
		})

		local inp = sec:Input({
			Name = "New Config",
			Placeholder = "config name...",
		})

		sec:Button({
			Name = "Create",
			Callback = function()
				local name = inp.Value
				if name and name ~= "" then
					SkrilyaLib:SaveConfig(name)
					dd:SetOptions(SkrilyaLib:GetConfigList())
					SkrilyaLib:Notify({Title = "Config", Description = "Created: " .. name, Type = "Success"})
				end
			end,
		})

		sec:Button({
			Name = "Load",
			Callback = function()
				if dd.Value then
					SkrilyaLib:LoadConfig(dd.Value)
					SkrilyaLib:Notify({Title = "Config", Description = "Loaded: " .. dd.Value, Type = "Success"})
				end
			end,
		})

		sec:Button({
			Name = "Save",
			Callback = function()
				if dd.Value then
					SkrilyaLib:SaveConfig(dd.Value)
					SkrilyaLib:Notify({Title = "Config", Description = "Saved: " .. dd.Value, Type = "Success"})
				end
			end,
		})

		sec:Button({
			Name = "Set AutoLoad",
			Callback = function()
				if dd.Value then
					SkrilyaLib:SetAutoLoad(dd.Value)
					SkrilyaLib:Notify({Title = "Config", Description = "AutoLoad set: " .. dd.Value, Type = "Info"})
				end
			end,
		})
	end

	-- // 18. THEME SECTION
	function Window:InsertThemeSection(tab)
		local sec = tab:CreateSection({Name = "Тема", Side = "Right"})
		local themeNames = {}
		for name in pairs(Themes) do table.insert(themeNames, name) end

		sec:Dropdown({
			Name = "Theme",
			Options = themeNames,
			Default = _currentTheme,
			Callback = function(v)
				SkrilyaLib:SetTheme(v)
			end,
		})
	end

	-- ══════════════════════════════
	-- // 19. MINIMIZER — refined
	-- ══════════════════════════════
	function Window:CreateMinimizer(cfg)
		cfg = cfg or {}
		local mini = Instance.new("TextButton")
		mini.Name = "Minimizer"
		mini.Size = cfg.Size or UDim2.fromOffset(42, 42)
		mini.Position = UDim2.fromOffset(20, 20)
		mini.BackgroundColor3 = t.Accent
		mini.BackgroundTransparency = 0.08
		mini.Text = "S"
		mini.TextColor3 = t.TextPrimary
		mini.FontFace = t.FontBold
		mini.TextSize = 18
		mini.BorderSizePixel = 0
		mini.Visible = false
		CreateCorner(mini, 12)
		CreateStroke(mini, t.AccentDark, 1, 0.3)
		ApplyAccentGradient(mini)
		mini.Parent = gui

		MakeDraggable(mini, mini)

		mini.MouseButton1Click:Connect(function()
			Window._minimized = false
			mainFrame.Visible = true
			mini.Visible = false
		end)

		Window._minimizerBtn = mini

		local mkConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if UserInputService:GetFocusedTextBox() then return end
			if input.KeyCode == minimizeKey then
				if Window._minimized then
					Window._minimized = false
					mainFrame.Visible = true
					mini.Visible = false
				else
					Window._minimized = true
					mainFrame.Visible = false
					mini.Visible = true
				end
			end
		end)
		table.insert(_connections, mkConn)
	end

	-- ══════════════════════════════
	-- // 20. LIFECYCLE
	-- ══════════════════════════════
	function Window.onUnloaded(fn)
		table.insert(_unloadCallbacks, fn)
	end

	function Window:Unload()
		if getgenv then getgenv()._SkrilyaRunning = false end
		for _, fn in ipairs(_unloadCallbacks) do pcall(fn) end
		for _, conn in ipairs(_connections) do pcall(function() conn:Disconnect() end) end
		for _, thread in ipairs(_threads) do pcall(function() task.cancel(thread) end) end
		if _autoSaveTask then pcall(function() task.cancel(_autoSaveTask) end) end
		-- Remove shadow frames
		pcall(function()
			for _, child in ipairs(gui:GetChildren()) do
				if child.Name == "_Shadow" or child.Name == "_Shadow2" then
					child:Destroy()
				end
			end
		end)
		pcall(function() gui:Destroy() end)
		if getgenv then getgenv()._SkrilyaUI = nil end
	end

	function Window:SelectTab(indexOrTab)
		local tab
		if type(indexOrTab) == "number" then
			tab = Window._tabs[indexOrTab]
		else
			tab = indexOrTab
		end
		if tab and tab._btn then
			tab._btn.MouseButton1Click:Fire()
		end
	end

	function Window:FinishLoading()
		if Window._loadingScreen then
			pcall(function() Window._loadingScreen:Destroy() end)
			Window._loadingScreen = nil
		end
	end

	-- ══════════════════════════════
	-- // 9. LOADING SCREEN — refined
	-- ══════════════════════════════
	if config.LoadingEnabled then
		local ls = config.LoadingSettings or {}
		local loadingGui = Instance.new("Frame")
		loadingGui.Name = "LoadingScreen"
		loadingGui.Size = UDim2.new(1, 0, 1, 0)
		loadingGui.BackgroundColor3 = t.Background
		loadingGui.ZIndex = 200
		loadingGui.BorderSizePixel = 0
		loadingGui.Parent = mainFrame

		-- Subtle accent glow at center
		local centerGlow = Instance.new("Frame")
		centerGlow.Size = UDim2.fromOffset(200, 200)
		centerGlow.Position = UDim2.new(0.5, -100, 0.35, -100)
		centerGlow.BackgroundColor3 = t.Accent
		centerGlow.BackgroundTransparency = 0.92
		centerGlow.BorderSizePixel = 0
		centerGlow.ZIndex = 200
		CreateCorner(centerGlow, 100)
		centerGlow.Parent = loadingGui

		local lTitle = Instance.new("TextLabel")
		lTitle.Size = UDim2.new(1, 0, 0, 32)
		lTitle.Position = UDim2.new(0, 0, 0.38, 0)
		lTitle.BackgroundTransparency = 1
		lTitle.Text = ls.Title or winTitle
		lTitle.TextColor3 = t.TextPrimary
		lTitle.FontFace = t.FontBold
		lTitle.TextSize = 22
		lTitle.ZIndex = 201
		lTitle.Parent = loadingGui

		local lSub = Instance.new("TextLabel")
		lSub.Size = UDim2.new(1, 0, 0, 18)
		lSub.Position = UDim2.new(0, 0, 0.38, 38)
		lSub.BackgroundTransparency = 1
		lSub.Text = ls.Subtitle or "Loading..."
		lSub.TextColor3 = t.TextDimmed
		lSub.FontFace = t.Font
		lSub.TextSize = 13
		lSub.ZIndex = 201
		lSub.Parent = loadingGui

		-- Progress bar — thin accent line
		local progBg = Instance.new("Frame")
		progBg.Size = UDim2.new(0.4, 0, 0, 3)
		progBg.Position = UDim2.new(0.3, 0, 0.38, 68)
		progBg.BackgroundColor3 = t.TertiaryBackground
		progBg.BorderSizePixel = 0
		progBg.ZIndex = 201
		CreateCorner(progBg, 2)
		progBg.Parent = loadingGui

		local progFill = Instance.new("Frame")
		progFill.Size = UDim2.new(0, 0, 1, 0)
		progFill.BackgroundColor3 = t.Accent
		progFill.BorderSizePixel = 0
		progFill.ZIndex = 202
		CreateCorner(progFill, 2)
		progFill.Parent = progBg

		Window._loadingScreen = loadingGui

		if ls.Duration then
			task.spawn(function()
				local start = tick()
				while tick() - start < ls.Duration do
					local pct = (tick() - start) / ls.Duration
					pcall(function()
						Tween(progFill, TI_FAST, {Size = UDim2.new(math.min(pct, 1), 0, 1, 0)})
					end)
					task.wait(0.05)
				end
				-- Fade out
				Tween(lTitle, TI_MED, {TextTransparency = 1})
				Tween(lSub, TI_MED, {TextTransparency = 1})
				Tween(loadingGui, TI_MED, {BackgroundTransparency = 1})
				Tween(centerGlow, TI_MED, {BackgroundTransparency = 1})
				task.wait(0.35)
				pcall(function() loadingGui:Destroy() end)
				Window._loadingScreen = nil
			end)
		end
	end

	_windowRef = Window
	return Window
end

-- // 21. RETURN
return SkrilyaLib
