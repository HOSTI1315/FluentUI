-- Replace YOUR_ORG/YOUR_REPO with your GitHub org/repo name
local REPO = "https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main"
local Fluent = loadstring(game:HttpGet(REPO .. "/FluentPlus/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet(REPO .. "/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet(REPO .. "/Addons/InterfaceManager.lua"))()

--[[ ============================================
    KEY SYSTEM (optional, remove if not needed)
    Call BEFORE CreateWindow. Blocks until valid key entered.
    Set SaveKey = true to remember the key on disk.
=============================================== ]]
local keyValid = Fluent:CreateKeySystem({
    Title = "My Script Hub",
    Subtitle = "Enter key to unlock",
    Key = "mykey123",                    -- single key
    -- Keys = {"key1", "key2"},          -- or multiple valid keys
    SaveKey = true,                      -- remember key between sessions
    FolderName = "MyScriptHub",          -- folder for saved key
    Note = "Join discord for free keys", -- optional note
    URL = "https://discord.gg/example",  -- optional: copies URL to clipboard
    URLText = "Copy Discord Link",       -- button text for URL
})

--[[ ============================================
    WINDOW
=============================================== ]]
local Window = Fluent:CreateWindow({
    Title = "Fluent " .. Fluent.Version,
    SubTitle = "by dawid",
    Search = true,
    Icon = "home",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    UserInfo = true,
    UserInfoTop = false,
    UserInfoTitle = game:GetService("Players").LocalPlayer.DisplayName,
    UserInfoSubtitle = "User",
    UserInfoSubtitleColor = Color3.fromRGB(71, 123, 255)
})

--[[ ============================================
    STATUS BAR (FPS / Ping / custom fields)
    Shows a small bar on screen with live stats.
=============================================== ]]
local StatusBar = Fluent:CreateStatusBar({
    FPS = true,
    Ping = true,
    Fields = {
        { Name = "Status" },
    },
    Position = UDim2.new(1, -10, 0, 10),
    AnchorPoint = Vector2.new(1, 0),
})
StatusBar:SetField("Status", "Running")

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Columns = Window:AddTab({ Title = "Columns", Icon = "columns" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Minimizer = Fluent:CreateMinimizer({
    Icon = "home",
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 320, 0, 24),
    Acrylic = true,
    Corner = 10,
    Transparency = 1,
    Draggable = true,
    Visible = true
})

local Options = Fluent.Options

--[[ ============================================
    MAIN TAB — standard elements
=============================================== ]]
do
    local Section = Tabs.Main:AddSection("Section", "apple")

    Fluent:Notify({
        Title = "Notification",
        Content = "This is a notification",
        SubContent = "SubContent",
        Duration = 5
    })

    Tabs.Main:AddParagraph({
        Icon = "home",
        Title = "Paragraph",
        Content = "This is a paragraph with an icon.\nSecond line!"
    })

    Tabs.Main:AddButton({
        Title = "Button",
        Description = "Very important button",
        Callback = function()
            Window:Dialog({
                Title = "Title",
                Content = "This is a dialog",
                Buttons = {
                    { Title = "Confirm", Callback = function() print("Confirmed") end },
                    { Title = "Cancel", Callback = function() print("Cancelled") end }
                }
            })
        end
    })

    -- Horizontal button row (2-4 buttons side by side)
    Section:AddButtonRow({
        { Title = "TP Lobby", Callback = function() print("TP Lobby") end },
        { Title = "TP Shop",  Callback = function() print("TP Shop") end },
        { Title = "TP Boss",  Callback = function() print("TP Boss") end },
    })

    local Toggle = Tabs.Main:AddToggle("MyToggle", { Title = "Toggle", Default = false })
    Toggle:OnChanged(function()
        print("Toggle changed:", Options.MyToggle.Value)
    end)

    local Slider = Tabs.Main:AddSlider("Slider", {
        Title = "Slider",
        Description = "This is a slider",
        Default = 2,
        Min = 0,
        Max = 5,
        Rounding = 1,
        Callback = function(Value)
            print("Slider was changed:", Value)
        end
    })

    local Dropdown = Tabs.Main:AddDropdown("Dropdown", {
        Title = "Dropdown",
        Values = {"one", "two", "three", "four", "five"},
        Multi = false,
        Default = 1,
    })

    local Colorpicker = Tabs.Main:AddColorpicker("Colorpicker", {
        Title = "Colorpicker",
        Default = Color3.fromRGB(96, 205, 255)
    })

    local Keybind = Tabs.Main:AddKeybind("Keybind", {
        Title = "KeyBind",
        Mode = "Toggle",
        Default = "LeftControl",
        Callback = function(Value) print("Keybind clicked!", Value) end,
        ChangedCallback = function(New) print("Keybind changed!", New) end
    })

    local Input = Tabs.Main:AddInput("Input", {
        Title = "Input",
        Default = "Default",
        Placeholder = "Placeholder",
        Numeric = false,
        Finished = false,
        Callback = function(Value) print("Input changed:", Value) end
    })
end

--[[ ============================================
    COLUMNS TAB — multi-column layout demo
    Tab:AddRow(N) returns a table of N columns.
    Each column supports :AddSection() and all Add* element methods.
=============================================== ]]
do
    -- Two-column layout
    local Cols = Tabs.Columns:AddRow(2)

    local LeftSection = Cols[1]:AddSection("Combat")
    LeftSection:AddToggle("KillAura", { Title = "Kill Aura", Default = false })
    LeftSection:AddSlider("AttackRange", {
        Title = "Range", Default = 5, Min = 1, Max = 20, Rounding = 0,
    })
    LeftSection:AddToggle("AutoParry", { Title = "Auto Parry", Default = false })

    local RightSection = Cols[2]:AddSection("Movement")
    RightSection:AddToggle("SpeedHack", { Title = "Speed Hack", Default = false })
    RightSection:AddSlider("SpeedValue", {
        Title = "Speed", Default = 16, Min = 1, Max = 100, Rounding = 0,
    })
    RightSection:AddToggle("Fly", { Title = "Fly", Default = false })

    -- Three-column layout
    local Cols3 = Tabs.Columns:AddRow(3)

    local S1 = Cols3[1]:AddSection("ESP")
    S1:AddToggle("PlayerESP", { Title = "Players", Default = false })
    S1:AddToggle("ItemESP", { Title = "Items", Default = false })

    local S2 = Cols3[2]:AddSection("Farm")
    S2:AddToggle("AutoFarm", { Title = "Auto Farm", Default = false })
    S2:AddToggle("AutoCollect", { Title = "Auto Collect", Default = false })

    local S3 = Cols3[3]:AddSection("Misc")
    S3:AddToggle("AntiAFK", { Title = "Anti AFK", Default = false })
    S3:AddToggle("FPSBoost", { Title = "FPS Boost", Default = false })

    -- Button row inside a column
    Cols3[1]:AddButtonRow({
        { Title = "On",  Callback = function() print("All ESP On") end },
        { Title = "Off", Callback = function() print("All ESP Off") end },
    })
end

--[[ ============================================
    SETTINGS TAB — SaveManager + InterfaceManager
    Autosave hooks install automatically in BuildConfigSection.
=============================================== ]]
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent",
    Content = "The script has been loaded.",
    Duration = 8
})

SaveManager:LoadAutoloadConfig()
