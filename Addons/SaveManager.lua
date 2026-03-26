local httpService = game:GetService("HttpService")

local function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager._autosaveEnabled = true
	SaveManager._suppressAutosave = false
	SaveManager._autosaveDebounceId = 0
	SaveManager._hooksInstalled = false

	SaveManager.AutoLoadOnBuild = false

	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object)
				return { type = "Toggle", idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetAutosaveEnabled(enabled)
		self._autosaveEnabled = not not enabled
	end

	function SaveManager:_getActiveConfigPath()
		return self.Folder .. "/settings/active_config.txt"
	end

	function SaveManager:_getAutosaveConfigName()
		local activePath = self:_getActiveConfigPath()
		if isfile(activePath) then
			local n = trim(readfile(activePath))
			if n ~= "" then
				return n
			end
		end
		local autoPath = self.Folder .. "/settings/autoload.txt"
		if isfile(autoPath) then
			local n = trim(readfile(autoPath))
			if n ~= "" then
				return n
			end
		end
		return nil
	end

	function SaveManager:_setActiveConfigName(name)
		if type(name) ~= "string" or trim(name) == "" then
			return
		end
		self:BuildFolderTree()
		writefile(self:_getActiveConfigPath(), trim(name))
	end

	function SaveManager:_scheduleAutosave()
		if not self._autosaveEnabled or self._suppressAutosave or not self.Library then
			return
		end
		local name = self:_getAutosaveConfigName()
		if not name then
			return
		end

		self._autosaveDebounceId += 1
		local token = self._autosaveDebounceId
		task.delay(0.28, function()
			if token ~= self._autosaveDebounceId or self._suppressAutosave or not self._autosaveEnabled then
				return
			end
			self:Save(name)
		end)
	end

	function SaveManager:_wrapOptionForAutosave(idx, option)
		if self.Ignore[idx] then
			return
		end
		if type(option) ~= "table" or option.__SaveManagerAutosaveWrapped then
			return
		end
		if not self.Parser[option.Type] then
			return
		end

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

		option.__SaveManagerAutosaveWrapped = true
	end

	function SaveManager:_installAutosaveHooks()
		if self._hooksInstalled or not self.Library then
			return
		end

		local opts = self.Library.Options
		for idx, option in pairs(opts) do
			self:_wrapOptionForAutosave(idx, option)
		end

		setmetatable(opts, {
			__newindex = function(t, idx, option)
				rawset(t, idx, option)
				SaveManager:_wrapOptionForAutosave(idx, option)
			end,
		})

		self._hooksInstalled = true
	end

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if not name then
			return false, "no config file is selected"
		end

		local fullPath = self.Folder .. "/settings/" .. name .. ".json"

		local data = {
			objects = {},
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then
				continue
			end
			if self.Ignore[idx] then
				continue
			end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if not name then
			return false, "no config file is selected"
		end

		local file = self.Folder .. "/settings/" .. name .. ".json"
		if not isfile(file) then
			return false, "invalid file"
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then
			return false, "decode error"
		end

		self._suppressAutosave = true

		local objs = decoded.objects
		if type(objs) ~= "table" then
			objs = {}
		end

		local pending = 0
		for _, option in next, objs do
			if self.Parser[option.type] then
				pending += 1
				task.spawn(function()
					pcall(function()
						self.Parser[option.type].Load(option.idx, option)
					end)
					pending -= 1
					if pending == 0 then
						self._suppressAutosave = false
					end
				end)
			end
		end

		if pending == 0 then
			self._suppressAutosave = false
		end

		self:_setActiveConfigName(name)
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			"InterfaceTheme",
			"AcrylicToggle",
			"TransparentToggle",
			"MenuKeybind",
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. "/settings",
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")

		local out = {}
		for i = 1, #list do
			local f = list[i]
			if f:sub(-5) == ".json" then
				local pos = f:find(".json", 1, true)
				local start = pos

				local char = f:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = f:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local confName = f:sub(pos + 1, start - 1)
					if confName ~= "options" then
						table.insert(out, confName)
					end
				end
			end
		end

		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = trim(readfile(self.Folder .. "/settings/autoload.txt"))
			if name == "" then
				return
			end

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load autoload config: " .. err,
					Duration = 7,
				})
			end

			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7,
			})
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName", { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigName.Value

				if name:gsub(" ", "") == "" then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Invalid config name (empty)",
						Duration = 7,
					})
				end

				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to save config: " .. err,
						Duration = 7,
					})
				end

				self:_setActiveConfigName(name)

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Created config %q", name),
					Duration = 7,
				})

				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
			end,
		})

		section:AddButton({
			Title = "Load config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				local ok, err = self:Load(name)
				if not ok then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to load config: " .. err,
						Duration = 7,
					})
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Loaded config %q", name),
					Duration = 7,
				})
			end,
		})

		section:AddButton({
			Title = "Overwrite config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value

				local ok, err = self:Save(name)
				if not ok then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to overwrite config: " .. err,
						Duration = 7,
					})
				end

				self:_setActiveConfigName(name)

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Overwrote config %q", name),
					Duration = 7,
				})
			end,
		})

		section:AddButton({
			Title = "Refresh list",
			Callback = function()
				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
			end,
		})

		local AutoloadButton
		AutoloadButton = section:AddButton({
			Title = "Set as autoload",
			Description = "Current autoload config: none",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigList.Value
				writefile(self.Folder .. "/settings/autoload.txt", name)
				self:_setActiveConfigName(name)
				AutoloadButton:SetDesc("Current autoload config: " .. name)
				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Set %q to auto load", name),
					Duration = 7,
				})
			end,
		})

		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = trim(readfile(self.Folder .. "/settings/autoload.txt"))
			if name ~= "" then
				AutoloadButton:SetDesc("Current autoload config: " .. name)
			end
		end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })

		self:_installAutosaveHooks()

		if self.AutoLoadOnBuild then
			self:LoadAutoloadConfig()
		end
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
