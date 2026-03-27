--[[
	SkrilyaSaveManager — нативное автосохранение конфигов для SkrilyaHub
	Executor-only (writefile / readfile / isfile / isfolder / makefolder / listfiles / delfile)

	Структура на диске (режим SkrilyaHub):
		SkrilyaHub/
			<GameName>/
				settings/
					default.json
					active_config.txt    ← активный конфиг
					autoload.txt         ← (legacy) поддерживается для обратной совместимости

	Структура на диске (legacy / ручной режим):
		<Folder>/               ← задаётся через SetFolder()
			settings/
				<config>.json
				active_config.txt / autoload.txt

	Использование — SkrilyaHub-стиль (рекомендуется):
		local SaveManager = loadstring(game:HttpGet(REPO.."/Addons/SkrilyaSaveManager.lua"))()
		-- ... создать Window, Tabs, Elements ...
		SaveManager:Init(Fluent)
		SaveManager:BuildConfigSection(Tabs.Settings)

	Использование — legacy-стиль (обратная совместимость с SaveManager.lua):
		SaveManager:SetLibrary(Fluent)
		SaveManager:SetFolder("MyHub/MyGame")   -- отключает авто-определение игры
		SaveManager:IgnoreThemeSettings()
		SaveManager:BuildConfigSection(tab)     -- AutoLoadOnBuild=true → грузит autoload.txt
		-- либо вручную: SaveManager:LoadAutoloadConfig()
]]

local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local HUB_ROOT      = "SkrilyaHub"
local DEFAULT_CONFIG = "default"
local DEBOUNCE_DELAY = 0.35

-- ─── утилиты ─────────────────────────────────────────────────────────────────

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
	if not isfolder(path) then makefolder(path) end
end

-- ─────────────────────────────────────────────────────────────────────────────
--  SaveManager
-- ─────────────────────────────────────────────────────────────────────────────

local SaveManager = {}
do
	-- ── публичные поля ──

	SaveManager.Library          = nil
	SaveManager.Options          = nil
	SaveManager.Ignore           = {}
	SaveManager.Folder           = nil   -- nil → авто; строка → ручной режим
	SaveManager.GameName         = nil
	SaveManager.AutoLoadOnBuild  = false -- legacy: грузить autoload.txt в BuildConfigSection

	-- ── приватные поля ──

	SaveManager._activeConfig    = nil
	SaveManager._debounceId      = 0
	SaveManager._hooksInstalled  = false
	SaveManager._folderOverride  = false -- true когда папка задана вручную через SetFolder

	-- _suppressSave / _suppressAutosave — оба имени поддерживаются
	-- Доступ всегда через метод, чтобы legacy-код `self._suppressAutosave = true` тоже работал
	SaveManager._suppressSave     = false
	SaveManager._autosaveEnabled  = true

	-- ── прокси для legacy-имён ──
	-- Эти поля просто алиасы (читаются/пишутся через __index/__newindex ниже)

	-- ─────────────────────────────────────────────────────────────────
	--  Парсеры (сохранение / восстановление каждого типа элемента)
	-- ─────────────────────────────────────────────────────────────────

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
		-- Слайдер: сохраняем строкой (JSON), но грузим через tonumber чтобы
		-- math.clamp не падал с "attempt to compare string < number"
		Slider = {
			Save = function(idx, obj)
				return { type = "Slider", idx = idx, value = tostring(obj.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local n = tonumber(data.value)
					if n ~= nil then
						SaveManager.Options[idx]:SetValue(n)
					end
				end
			end,
		},
		Dropdown = {
			Save = function(idx, obj)
				return { type = "Dropdown", idx = idx, value = obj.Value, multi = obj.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					-- поддержка legacy-опечатки "mutli"
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

	-- ─────────────────────────────────────────────────────────────────
	--  Привязка библиотеки
	-- ─────────────────────────────────────────────────────────────────

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:SetAutosaveEnabled(enabled)
		self._autosaveEnabled = not not enabled
	end

	-- Принимает и таблицу (ipairs), и хеш-список (next), как в обоих оригиналах
	function SaveManager:SetIgnoreIndexes(list)
		if type(list) == "table" then
			for _, key in ipairs(list) do
				if type(key) == "string" then self.Ignore[key] = true end
			end
		end
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"InterfaceTheme", "AcrylicToggle",
			"TransparentToggle", "MenuKeybind",
		})
	end

	-- ─────────────────────────────────────────────────────────────────
	--  Файловая система / папки
	-- ─────────────────────────────────────────────────────────────────

	-- Ручная установка папки (legacy).  Отключает авто-определение игры.
	function SaveManager:SetFolder(folder)
		self.Folder        = trim(folder)
		self._folderOverride = true
		self:BuildFolderTree()
	end

	-- BuildFolderTree: если папка задана вручную — использует её;
	-- иначе авто SkrilyaHub/<GameName>.
	function SaveManager:BuildFolderTree()
		if not self._folderOverride then
			self.GameName = resolveGameName()
			self.Folder   = HUB_ROOT .. "/" .. self.GameName
			ensureFolder(HUB_ROOT)
		end
		ensureFolder(self.Folder)
		ensureFolder(self.Folder .. "/settings")
	end

	function SaveManager:_configPath(name)
		return self.Folder .. "/settings/" .. name .. ".json"
	end

	function SaveManager:_activeConfigPath()
		return self.Folder .. "/settings/active_config.txt"
	end

	function SaveManager:_autoloadPath()
		return self.Folder .. "/settings/autoload.txt"
	end

	-- ─────────────────────────────────────────────────────────────────
	--  Активный конфиг
	-- ─────────────────────────────────────────────────────────────────

	function SaveManager:GetActiveConfig()
		if self._activeConfig then return self._activeConfig end
		-- 1. новый формат
		local ap = self:_activeConfigPath()
		if isfile(ap) then
			local n = trim(readfile(ap))
			if n ~= "" then self._activeConfig = n; return n end
		end
		-- 2. legacy autoload.txt
		local lp = self:_autoloadPath()
		if isfile(lp) then
			local n = trim(readfile(lp))
			if n ~= "" then self._activeConfig = n; return n end
		end
		return nil
	end

	function SaveManager:SetActiveConfig(name)
		name = trim(name)
		if name == "" then return end
		self._activeConfig = name
		pcall(writefile, self:_activeConfigPath(), name)
	end

	-- Legacy-алиас
	function SaveManager:_setActiveConfigName(name)
		self:SetActiveConfig(name)
	end

	-- Legacy-метод: читает autoload.txt и загружает конфиг
	function SaveManager:LoadAutoloadConfig()
		local lp = self:_autoloadPath()
		if not isfile(lp) then return end
		local name = trim(readfile(lp))
		if name == "" then return end

		local ok, err = self:Load(name)
		if not ok then
			if self.Library then
				self.Library:Notify({
					Title   = "SkrilyaHub",
					Content = "Config",
					SubContent = "Failed to load autoload config: " .. tostring(err),
					Duration = 7,
				})
			end
			return
		end

		if self.Library then
			self.Library:Notify({
				Title   = "SkrilyaHub",
				Content = "Config",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7,
			})
		end
	end

	-- ─────────────────────────────────────────────────────────────────
	--  _suppressSave / _suppressAutosave — оба имени
	-- ─────────────────────────────────────────────────────────────────
	-- Используем __index/__newindex на объекте для прозрачного алиаса

	local _smMeta = {
		__index = function(t, k)
			if k == "_suppressAutosave" then return rawget(t, "_suppressSave") end
			return nil
		end,
		__newindex = function(t, k, v)
			if k == "_suppressAutosave" then
				rawset(t, "_suppressSave", v)
			else
				rawset(t, k, v)
			end
		end,
	}
	setmetatable(SaveManager, _smMeta)

	-- ─────────────────────────────────────────────────────────────────
	--  Save / Load / Delete
	-- ─────────────────────────────────────────────────────────────────

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

		if pending == 0 then self._suppressSave = false end

		self:SetActiveConfig(name)
		return true
	end

	function SaveManager:Delete(name)
		if not name or trim(name) == "" then return false end
		local path = self:_configPath(name)
		if isfile(path) then
			delfile(path)
			if self._activeConfig == name then self._activeConfig = nil end
			return true
		end
		return false
	end

	-- ─────────────────────────────────────────────────────────────────
	--  Автосохранение
	-- ─────────────────────────────────────────────────────────────────

	function SaveManager:_scheduleAutosave()
		if self._suppressSave or not self._autosaveEnabled or not self.Library then return end

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
		if type(option) ~= "table" then return end
		-- поддерживаем оба маркера (новый и legacy)
		if option.__SkrilyaWrapped or option.__SaveManagerAutosaveWrapped then return end
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

		option.__SkrilyaWrapped             = true
		option.__SaveManagerAutosaveWrapped = true  -- legacy-маркер
	end

	-- Legacy-алиасы для имён методов
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

	-- Legacy-алиас
	SaveManager._installAutosaveHooks = SaveManager._installHooks

	-- Legacy-алиас для _getAutosaveConfigName (старый SaveManager)
	function SaveManager:_getAutosaveConfigName()
		return self:GetActiveConfig()
	end

	-- ─────────────────────────────────────────────────────────────────
	--  Список конфигов
	-- ─────────────────────────────────────────────────────────────────

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

	-- ─────────────────────────────────────────────────────────────────
	--  Init — одна точка входа (SkrilyaHub-стиль)
	-- ─────────────────────────────────────────────────────────────────

	function SaveManager:Init(library)
		self:SetLibrary(library)
		self:IgnoreThemeSettings()
		self:BuildFolderTree()
		self:_installHooks()

		local active = self:GetActiveConfig()
		if active and isfile(self:_configPath(active)) then
			local ok, err = self:Load(active)
			if ok and self.Library then
				self.Library:Notify({
					Title      = "SkrilyaHub",
					Content    = "Config",
					SubContent = string.format("Loaded %q", active),
					Duration   = 5,
				})
			end
		else
			self:Save(DEFAULT_CONFIG)
			self:SetActiveConfig(DEFAULT_CONFIG)
		end
	end

	-- ─────────────────────────────────────────────────────────────────
	--  BuildConfigSection — поддерживает оба набора ключей опций
	-- ─────────────────────────────────────────────────────────────────
	-- new:    SM_ConfigName / SM_ConfigList
	-- legacy: SaveManager_ConfigName / SaveManager_ConfigList

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Call Init() or SetLibrary() first")

		-- Убедимся что папки созданы (нужно для legacy-потока без Init)
		if not self.Folder then
			self:BuildFolderTree()
		end

		-- Устанавливаем хуки, если ещё не установлены (legacy без Init)
		if not self._hooksInstalled then
			self:_installHooks()
		end

		-- Определяем префикс ключей: если уже зарегистрированы legacy-ключи — используем их
		local legacyKeys = self.Options and self.Options["SaveManager_ConfigName"] ~= nil
		local nameKey = legacyKeys and "SaveManager_ConfigName" or "SM_ConfigName"
		local listKey = legacyKeys and "SaveManager_ConfigList" or "SM_ConfigList"

		local section = tab:AddSection("Configuration", "save")

		section:AddInput(nameKey, { Title = "Config name" })
		section:AddDropdown(listKey, {
			Title     = "Config list",
			Values    = self:RefreshConfigList(),
			AllowNull = true,
		})

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = trim(self.Options[nameKey].Value)
				if name == "" then
					return self.Library:Notify({
						Title = "SkrilyaHub", Content = "Config",
						SubContent = "Empty config name", Duration = 5,
					})
				end
				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub", Content = "Config",
						SubContent = "Failed: " .. tostring(err), Duration = 5,
					})
				end
				self.Library:Notify({
					Title = "SkrilyaHub", Content = "Config",
					SubContent = string.format("Created %q", name), Duration = 5,
				})
				self.Options[listKey]:SetValues(self:RefreshConfigList())
				self.Options[listKey]:SetValue(nil)
			end,
		})

		section:AddButton({
			Title = "Load config",
			Callback = function()
				local name = self.Options[listKey].Value
				local ok, err = self:Load(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub", Content = "Config",
						SubContent = "Failed: " .. tostring(err), Duration = 5,
					})
				end
				self.Library:Notify({
					Title = "SkrilyaHub", Content = "Config",
					SubContent = string.format("Loaded %q", name), Duration = 5,
				})
			end,
		})

		section:AddButton({
			Title = "Overwrite config",
			Callback = function()
				local name = self.Options[listKey].Value
				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "SkrilyaHub", Content = "Config",
						SubContent = "Failed: " .. tostring(err), Duration = 5,
					})
				end
				self.Library:Notify({
					Title = "SkrilyaHub", Content = "Config",
					SubContent = string.format("Overwritten %q", name), Duration = 5,
				})
			end,
		})

		section:AddButton({
			Title = "Delete config",
			Callback = function()
				local name = self.Options[listKey].Value
				if not name or trim(name) == "" then return end
				self:Delete(name)
				self.Library:Notify({
					Title = "SkrilyaHub", Content = "Config",
					SubContent = string.format("Deleted %q", name), Duration = 5,
				})
				self.Options[listKey]:SetValues(self:RefreshConfigList())
				self.Options[listKey]:SetValue(nil)
			end,
		})

		-- "Set as autoload" (legacy-кнопка, пишет autoload.txt)
		local AutoloadButton
		AutoloadButton = section:AddButton({
			Title       = "Set as autoload",
			Description = "Current autoload: none",
			Callback = function()
				local name = self.Options[listKey].Value
				if not name or trim(name) == "" then return end
				pcall(writefile, self:_autoloadPath(), name)
				self:SetActiveConfig(name)
				AutoloadButton:SetDesc("Current autoload: " .. name)
				self.Library:Notify({
					Title = "SkrilyaHub", Content = "Config",
					SubContent = string.format("Set %q as autoload", name), Duration = 5,
				})
			end,
		})

		-- Показываем текущий autoload в описании кнопки
		local curAuto = self:GetActiveConfig()
		if curAuto then
			AutoloadButton:SetDesc("Current autoload: " .. curAuto)
		end

		section:AddButton({
			Title = "Refresh list",
			Callback = function()
				self.Options[listKey]:SetValues(self:RefreshConfigList())
				self.Options[listKey]:SetValue(nil)
			end,
		})

		self:SetIgnoreIndexes({ nameKey, listKey })

		-- Legacy: AutoLoadOnBuild
		if self.AutoLoadOnBuild then
			self:LoadAutoloadConfig()
		end
	end
end

return SaveManager
