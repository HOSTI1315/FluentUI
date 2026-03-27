--[[
	SkrilyaSaveManager — нативное автосохранение конфигов для SkrilyaHub
	Executor-only (writefile / readfile / isfolder / makefolder / listfiles / delfile)

	Структура на диске:
		SkrilyaHub/
			<GameName>/
				settings/
					default.json
					active_config.txt

	Использование:
		local SaveManager = loadstring(game:HttpGet(REPO .. "/Addons/SkrilyaSaveManager.lua"))()
		-- ... создать Window, Tabs, Elements ...
		SaveManager:Init(Fluent)                       -- папки + хуки + автозагрузка
		SaveManager:BuildConfigSection(Tabs.Settings)  -- UI для ручного управления
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local HUB_ROOT = "SkrilyaHub"
local DEFAULT_CONFIG = "default"
local DEBOUNCE_DELAY = 0.35

local function trim(s)
	if type(s) ~= "string" then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitizeName(raw)
	local clean = raw:gsub("[^%w%s%-_]", ""):gsub("%s+", " ")
	clean = trim(clean)
	if clean == "" then return nil end
	return clean:sub(1, 64)
end

local function resolveGameName()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and info and type(info.Name) == "string" then
		local name = sanitizeName(info.Name)
		if name then return name end
	end
	local fallback = sanitizeName(game.Name)
	if fallback then return fallback end
	return tostring(game.PlaceId)
end

local function ensureFolder(path)
	if not isfolder(path) then
		makefolder(path)
	end
end

-- ─────────────────────────────────────────────
--  SaveManager
-- ─────────────────────────────────────────────

local SaveManager = {}
do
	SaveManager.Library      = nil
	SaveManager.Options      = nil
	SaveManager.Ignore       = {}
	SaveManager.Folder       = nil   -- SkrilyaHub/<GameName>
	SaveManager.GameName     = nil

	SaveManager._activeConfig    = nil
	SaveManager._debounceId      = 0
	SaveManager._hooksInstalled  = false
	SaveManager._suppressSave    = false
	SaveManager._autosaveEnabled = true

	-- ── Парсеры для каждого типа элемента ──

	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, obj)
				return { type = "Toggle", idx = idx, value = obj.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, obj)
				return { type = "Slider", idx = idx, value = tostring(obj.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, obj)
				return { type = "Dropdown", idx = idx, value = obj.Value, multi = obj.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, obj)
				return { type = "Colorpicker", idx = idx, value = obj.Value:ToHex(), transparency = obj.Transparency }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, obj)
				return { type = "Keybind", idx = idx, key = obj.Value, mode = obj.Mode }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},
		Input = {
			Save = function(idx, obj)
				return { type = "Input", idx = idx, text = obj.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	-- ── Привязка библиотеки ──

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:SetAutosaveEnabled(enabled)
		self._autosaveEnabled = not not enabled
	end

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in ipairs(list) do
			self.Ignore[key] = true
		end
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"InterfaceTheme", "AcrylicToggle",
			"TransparentToggle", "MenuKeybind",
		})
	end

	-- ── Файловая система ──

	function SaveManager:BuildFolderTree()
		self.GameName = resolveGameName()
		self.Folder = HUB_ROOT .. "/" .. self.GameName

		ensureFolder(HUB_ROOT)
		ensureFolder(self.Folder)
		ensureFolder(self.Folder .. "/settings")
	end

	function SaveManager:_configPath(name)
		return self.Folder .. "/settings/" .. name .. ".json"
	end

	function SaveManager:_activeConfigPath()
		return self.Folder .. "/settings/active_config.txt"
	end

	-- ── Активный конфиг ──

	function SaveManager:GetActiveConfig()
		if self._activeConfig then
			return self._activeConfig
		end
		local path = self:_activeConfigPath()
		if isfile(path) then
			local name = trim(readfile(path))
			if name ~= "" then
				self._activeConfig = name
				return name
			end
		end
		return nil
	end

	function SaveManager:SetActiveConfig(name)
		name = trim(name)
		if name == "" then return end
		self._activeConfig = name
		pcall(writefile, self:_activeConfigPath(), name)
	end

	-- ── Save / Load ──

	function SaveManager:Save(name)
		name = name or self:GetActiveConfig() or DEFAULT_CONFIG

		local payload = { objects = {} }

		for idx, option in pairs(self.Options) do
			if self.Ignore[idx] then continue end
			local parser = self.Parser[option.Type]
			if not parser then continue end
			table.insert(payload.objects, parser.Save(idx, option))
		end

		local ok, json = pcall(HttpService.JSONEncode, HttpService, payload)
		if not ok then return false, "encode error" end

		local wOk, wErr = pcall(writefile, self:_configPath(name), json)
		if not wOk then return false, "write error: " .. tostring(wErr) end

		self:SetActiveConfig(name)
		return true
	end

	function SaveManager:Load(name)
		name = name or self:GetActiveConfig()
		if not name then return false, "no config selected" end

		local path = self:_configPath(name)
		if not isfile(path) then return false, "file not found" end

		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		if not ok or type(decoded) ~= "table" then return false, "decode error" end

		self._suppressSave = true

		local objs = decoded.objects
		if type(objs) ~= "table" then objs = {} end

		local pending = 0
		for _, entry in ipairs(objs) do
			local parser = self.Parser[entry.type]
			if parser then
				pending += 1
				task.spawn(function()
					pcall(parser.Load, entry.idx, entry)
					pending -= 1
					if pending == 0 then
						self._suppressSave = false
					end
				end)
			end
		end

		if pending == 0 then
			self._suppressSave = false
		end

		self:SetActiveConfig(name)
		return true
	end

	function SaveManager:Delete(name)
		if not name or trim(name) == "" then return false end
		local path = self:_configPath(name)
		if isfile(path) then
			delfile(path)
			if self._activeConfig == name then
				self._activeConfig = nil
			end
			return true
		end
		return false
	end

	-- ── Автосохранение с дебаунсом ──

	function SaveManager:_scheduleAutosave()
		if self._suppressSave or not self._autosaveEnabled or not self.Library then
			return
		end

		local target = self:GetActiveConfig()
		if not target then return end

		self._debounceId += 1
		local token = self._debounceId

		task.delay(DEBOUNCE_DELAY, function()
			if token ~= self._debounceId then return end
			if self._suppressSave or not self._autosaveEnabled then return end
			self:Save(target)
		end)
	end

	function SaveManager:_wrapOption(idx, option)
		if self.Ignore[idx] then return end
		if type(option) ~= "table" or option.__SkrilyaWrapped then return end
		if not self.Parser[option.Type] then return end

		local origSetValue = option.SetValue
		if type(origSetValue) == "function" then
			option.SetValue = function(o, ...)
				origSetValue(o, ...)
				SaveManager:_scheduleAutosave()
			end
		end

		if option.Type == "Colorpicker" then
			local origRGB = option.SetValueRGB
			if type(origRGB) == "function" then
				option.SetValueRGB = function(o, ...)
					origRGB(o, ...)
					SaveManager:_scheduleAutosave()
				end
			end
		end

		option.__SkrilyaWrapped = true
	end

	function SaveManager:_installHooks()
		if self._hooksInstalled or not self.Options then return end

		for idx, option in pairs(self.Options) do
			self:_wrapOption(idx, option)
		end

		setmetatable(self.Options, {
			__newindex = function(t, idx, option)
				rawset(t, idx, option)
				SaveManager:_wrapOption(idx, option)
			end,
		})

		self._hooksInstalled = true
	end

	-- ── Список конфигов ──

	function SaveManager:RefreshConfigList()
		local dir = self.Folder .. "/settings"
		if not isfolder(dir) then return {} end

		local out = {}
		for _, path in ipairs(listfiles(dir)) do
			if path:sub(-5) == ".json" then
				local name = path:match("([^/\\]+)%.json$")
				if name then
					table.insert(out, name)
				end
			end
		end
		return out
	end

	-- ── Init: одна точка входа ──
	-- Вызывать ПОСЛЕ создания всех элементов UI

	function SaveManager:Init(library)
		self:SetLibrary(library)
		self:IgnoreThemeSettings()
		self:BuildFolderTree()
		self:_installHooks()

		local active = self:GetActiveConfig()
		if active and isfile(self:_configPath(active)) then
			local ok, err = self:Load(active)
			if ok then
				self.Library:Notify({
					Title = "SkrilyaHub",
					Content = "Config",
					SubContent = string.format("Loaded %q", active),
					Duration = 5,
				})
			end
		else
			self:Save(DEFAULT_CONFIG)
			self:SetActiveConfig(DEFAULT_CONFIG)
		end
	end

	-- ── UI-секция для ручного управления конфигами ──

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Call Init() or SetLibrary() first")

		local section = tab:AddSection("Configuration", "save")

		section:AddInput("SM_ConfigName", { Title = "Config name" })
		section:AddDropdown("SM_ConfigList", {
			Title = "Config list",
			Values = self:RefreshConfigList(),
			AllowNull = true,
		})

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = trim(self.Options.SM_ConfigName.Value)
				if name == "" then
					return self.Library:Notify({
						Title = "SkrilyaHub",
						Content = "Config",
						SubContent = "Empty name",
						Duration = 5,
					})
				end

				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub",
						Content = "Config",
						SubContent = "Failed: " .. tostring(err),
						Duration = 5,
					})
				end

				self.Library:Notify({
					Title = "SkrilyaHub",
					Content = "Config",
					SubContent = string.format("Created %q", name),
					Duration = 5,
				})
				self.Options.SM_ConfigList:SetValues(self:RefreshConfigList())
				self.Options.SM_ConfigList:SetValue(nil)
			end,
		})

		section:AddButton({
			Title = "Load config",
			Callback = function()
				local name = self.Options.SM_ConfigList.Value
				local ok, err = self:Load(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub",
						Content = "Config",
						SubContent = "Failed: " .. tostring(err),
						Duration = 5,
					})
				end
				self.Library:Notify({
					Title = "SkrilyaHub",
					Content = "Config",
					SubContent = string.format("Loaded %q", name),
					Duration = 5,
				})
			end,
		})

		section:AddButton({
			Title = "Overwrite config",
			Callback = function()
				local name = self.Options.SM_ConfigList.Value
				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub",
						Content = "Config",
						SubContent = "Failed: " .. tostring(err),
						Duration = 5,
					})
				end
				self.Library:Notify({
					Title = "SkrilyaHub",
					Content = "Config",
					SubContent = string.format("Overwritten %q", name),
					Duration = 5,
				})
			end,
		})

		section:AddButton({
			Title = "Delete config",
			Callback = function()
				local name = self.Options.SM_ConfigList.Value
				if not name or trim(name) == "" then return end
				self:Delete(name)
				self.Library:Notify({
					Title = "SkrilyaHub",
					Content = "Config",
					SubContent = string.format("Deleted %q", name),
					Duration = 5,
				})
				self.Options.SM_ConfigList:SetValues(self:RefreshConfigList())
				self.Options.SM_ConfigList:SetValue(nil)
			end,
		})

		section:AddButton({
			Title = "Refresh list",
			Callback = function()
				self.Options.SM_ConfigList:SetValues(self:RefreshConfigList())
				self.Options.SM_ConfigList:SetValue(nil)
			end,
		})

		self:SetIgnoreIndexes({ "SM_ConfigName", "SM_ConfigList" })

		if not self._hooksInstalled then
			self:_installHooks()
		end
	end
end

return SaveManager
