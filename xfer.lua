--[[
    xFer Universal
    Version: 1.0.0
    Author: xFernandinho
    Description: Script universal de Roblox con framework de UI modular, auto-actualización y features plug-and-play para la comunidad.

    Changelog:
      - 1.0.0: versión base con auto-update + UI dark+gold + feature registry + guardado por juego
      - Incluye sistema de UI modular en un solo archivo con createNovaUI(options)
      - Soporte para Noclip, Speed, Jump, Fly, Anti-AFK, ESP, Aimbot, Server Browser y Rejoin
      - Persistencia en xFerUniversal/<GameName>_<PlaceId>.json
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local VERSION = "1.0.0"
local RAW_URL = "https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.lua"
local VERSION_URL = "https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.version"

local CONFIG = {
    autoUpdate = true,
    debug = false,
    configFolder = "xFerUniversal",
    theme = "dark_gold",
    defaultTheme = "dark_gold",
}

local function logger(level, message, extra)
    if level == "debug" and CONFIG.debug == false then
        return
    end

    local prefix = "[xFer]"
    if type(level) == "string" then
        prefix = prefix .. " [" .. string.upper(level) .. "]"
    end

    print(prefix .. " " .. tostring(message))
    if extra ~= nil then
        print(tostring(extra))
    end
end

local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        logger("warn", "safeCall failure", result)
        return nil
    end
    return result
end

local function safeHttpGet(url)
    if type(url) ~= "string" or url == "" then
        return nil
    end

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        logger("warn", "HttpGet failed for " .. url, result)
        return nil
    end

    return result
end

local function ensureConfigFolder()
    if typeof(makefolder) ~= "function" then
        return false
    end

    local ok = pcall(function()
        if not isfolder(CONFIG.configFolder) then
            makefolder(CONFIG.configFolder)
        end
    end)

    return ok
end

local function getConfigFileName()
    local base = game.Name or "roblox_game"
    local safeBase = string.gsub(base, "[^%w%-_]", "_")
    local placeId = tostring(game.PlaceId or "local")
    return string.format("%s/%s_%s.json", CONFIG.configFolder, safeBase, placeId)
end

local function saveConfig(data)
    if typeof(writefile) ~= "function" then
        return false
    end

    local ok = pcall(function()
        ensureConfigFolder()
        writefile(getConfigFileName(), HttpService:JSONEncode(data or {}))
    end)

    return ok
end

local function loadConfig()
    if typeof(readfile) ~= "function" then
        return {}
    end

    local filePath = getConfigFileName()
    if typeof(isfile) == "function" and not isfile(filePath) then
        return {}
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(filePath))
    end)

    if ok and type(result) == "table" then
        return result
    end

    return {}
end

local function createTween(obj, duration, props, style, direction)
    if not obj or not obj.Parent then
        return nil
    end

    local tweenInfo = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tween = TweenService:Create(obj, tweenInfo, props or {})
    tween:Play()
    return tween
end

local function getTheme(name)
    name = name or CONFIG.defaultTheme

    local palette = {
        dark_gold = {
            Background = Color3.fromRGB(14, 15, 20),
            Surface = Color3.fromRGB(22, 24, 31),
            SurfaceLight = Color3.fromRGB(32, 35, 44),
            SurfaceHover = Color3.fromRGB(43, 47, 58),
            Border = Color3.fromRGB(81, 74, 50),
            Accent = Color3.fromRGB(212, 175, 55),
            AccentLight = Color3.fromRGB(232, 205, 110),
            Text = Color3.fromRGB(243, 244, 245),
            Muted = Color3.fromRGB(170, 172, 178),
            Subtle = Color3.fromRGB(122, 124, 131),
            Success = Color3.fromRGB(114, 218, 175),
            Danger = Color3.fromRGB(255, 104, 104),
            Warning = Color3.fromRGB(255, 198, 110),
            Blue = Color3.fromRGB(104, 166, 255),
        },
        midnight = {
            Background = Color3.fromRGB(8, 10, 18),
            Surface = Color3.fromRGB(15, 18, 28),
            SurfaceLight = Color3.fromRGB(23, 27, 39),
            SurfaceHover = Color3.fromRGB(35, 41, 58),
            Border = Color3.fromRGB(80, 90, 130),
            Accent = Color3.fromRGB(212, 175, 55),
            AccentLight = Color3.fromRGB(232, 205, 110),
            Text = Color3.fromRGB(245, 245, 245),
            Muted = Color3.fromRGB(165, 170, 185),
            Subtle = Color3.fromRGB(105, 110, 128),
            Success = Color3.fromRGB(100, 220, 160),
            Danger = Color3.fromRGB(255, 90, 120),
            Warning = Color3.fromRGB(255, 190, 100),
            Blue = Color3.fromRGB(95, 170, 255),
        },
    }

    return palette[name] or palette.dark_gold
end

local function getVersionNumber(versionText)
    if type(versionText) ~= "string" then
        return 0
    end

    local cleaned = tostring(versionText):gsub("%s+", "")
    local parts = {}
    for num in string.gmatch(cleaned, "(%d+)") do
        table.insert(parts, tonumber(num) or 0)
    end

    if #parts == 0 then
        return 0
    end

    local total = 0
    for i = 1, #parts do
        total = total + (parts[i] * (10 ^ (3 * (#parts - i))))
    end

    return total
end

local function compareVersions(localVersion, remoteVersion)
    local localNum = getVersionNumber(localVersion)
    local remoteNum = getVersionNumber(remoteVersion)

    if remoteNum > localNum then
        return 1
    elseif remoteNum < localNum then
        return -1
    end

    return 0
end

local function performAutoUpdate()
    if CONFIG.autoUpdate == false then
        return false
    end

    local remoteVersionText = safeHttpGet(VERSION_URL)
    if remoteVersionText == nil then
        logger("debug", "No se pudo obtener la versión remota")
        return false
    end

    local remoteVersion = tostring(remoteVersionText):gsub("%s+", "")
    if remoteVersion == "" then
        return false
    end

    if compareVersions(VERSION, remoteVersion) >= 0 then
        logger("debug", "Ya estás en la última versión local: " .. VERSION)
        return false
    end

    logger("info", "Actualización detectada. Versión local: " .. VERSION .. " | remota: " .. remoteVersion)

    local remoteScript = safeHttpGet(RAW_URL)
    if type(remoteScript) ~= "string" or remoteScript == "" then
        logger("warn", "No se pudo descargar la versión remota del script")
        return false
    end

    local compiled = loadstring(remoteScript)
    if type(compiled) ~= "function" then
        logger("error", "No se pudo compilar el script remoto")
        return false
    end

    local ok, result = pcall(function()
        return compiled()
    end)

    if ok then
        logger("info", "Actualización aplicada correctamente")
        return true
    end

    logger("error", "Error al ejecutar el script remoto", result)
    return false
end

local NovaFeatures = {
    list = {},
}

function NovaFeatures.register(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" then
        return nil
    end

    local item = {
        id = definition.id,
        name = definition.name or definition.id,
        category = definition.category or "General",
        description = definition.description or "",
        default = definition.default,
        type = definition.type or "toggle",
        min = definition.min,
        max = definition.max,
        init = definition.init or function() end,
        options = definition.options or {},
    }

    table.insert(NovaFeatures.list, item)
    return item
end

local function createNovaUI(options)
    local self = {}
    local uiOptions = options or {}
    local state = {
        title = uiOptions.title or "xFer Universal",
        themeName = uiOptions.theme or CONFIG.defaultTheme,
        theme = getTheme(uiOptions.theme or CONFIG.defaultTheme),
        open = true,
        tabs = {},
        pages = {},
        controls = {},
        config = loadConfig(),
        savedConfigs = {},
        listeners = {},
    }

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "xFerNovaUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui

    local blur = Lighting:FindFirstChild("xFerNovaBlur")
    if blur then
        blur:Destroy()
    end

    local blurEffect = Instance.new("BlurEffect")
    blurEffect.Name = "xFerNovaBlur"
    blurEffect.Size = 0
    blurEffect.Enabled = true
    blurEffect.Parent = Lighting

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = UDim2.new(0, 760, 0, 500)
    main.BackgroundColor3 = state.theme.Background
    main.BorderSizePixel = 0
    main.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = state.theme.Border
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.2
    mainStroke.Parent = main

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 62)
    header.BackgroundTransparency = 1
    header.BorderSizePixel = 0
    header.Parent = main

    local dragArea = Instance.new("TextButton")
    dragArea.Name = "DragArea"
    dragArea.BackgroundTransparency = 1
    dragArea.Text = ""
    dragArea.Size = UDim2.new(1, 0, 1, 0)
    dragArea.Parent = header

    local logo = Instance.new("Frame")
    logo.Name = "Logo"
    logo.Size = UDim2.fromOffset(38, 38)
    logo.Position = UDim2.fromOffset(18, 12)
    logo.BackgroundColor3 = state.theme.Accent
    logo.BorderSizePixel = 0
    logo.Parent = header

    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 12)
    logoCorner.Parent = logo

    local logoGradient = Instance.new("UIGradient")
    logoGradient.Rotation = 45
    logoGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, state.theme.Blue),
        ColorSequenceKeypoint.new(0.5, state.theme.Accent),
        ColorSequenceKeypoint.new(1, state.theme.AccentLight),
    })
    logoGradient.Parent = logo

    local logoText = Instance.new("TextLabel")
    logoText.Text = "X"
    logoText.BackgroundTransparency = 1
    logoText.BorderSizePixel = 0
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.Font = Enum.Font.GothamBlack
    logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoText.TextSize = 20
    logoText.Parent = logo

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = state.title
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextColor3 = state.theme.Text
    titleLabel.TextSize = 18
    titleLabel.BackgroundTransparency = 1
    titleLabel.BorderSizePixel = 0
    titleLabel.Position = UDim2.fromOffset(66, 12)
    titleLabel.Size = UDim2.fromOffset(220, 18)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Text = "Multi Tool Script"
    subtitleLabel.Font = Enum.Font.GothamMedium
    subtitleLabel.TextColor3 = state.theme.Muted
    subtitleLabel.TextSize = 10
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.BorderSizePixel = 0
    subtitleLabel.Position = UDim2.fromOffset(67, 34)
    subtitleLabel.Size = UDim2.fromOffset(200, 14)
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.Parent = header

    local versionLabel = Instance.new("TextLabel")
    versionLabel.Text = "v" .. VERSION
    versionLabel.Font = Enum.Font.GothamBold
    versionLabel.TextColor3 = state.theme.Muted
    versionLabel.TextSize = 11
    versionLabel.BackgroundTransparency = 1
    versionLabel.BorderSizePixel = 0
    versionLabel.Position = UDim2.new(1, -96, 0, 18)
    versionLabel.Size = UDim2.fromOffset(80, 18)
    versionLabel.TextXAlignment = Enum.TextXAlignment.Right
    versionLabel.Parent = header

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 170, 1, -88)
    sidebar.Position = UDim2.fromOffset(16, 78)
    sidebar.BackgroundColor3 = state.theme.Surface
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 15)
    sidebarCorner.Parent = sidebar

    local navTitle = Instance.new("TextLabel")
    navTitle.Text = "NAVIGATION"
    navTitle.Font = Enum.Font.GothamBold
    navTitle.TextColor3 = state.theme.Subtle
    navTitle.TextSize = 9
    navTitle.BackgroundTransparency = 1
    navTitle.BorderSizePixel = 0
    navTitle.Position = UDim2.fromOffset(12, 14)
    navTitle.Size = UDim2.new(1, -20, 0, 16)
    navTitle.TextXAlignment = Enum.TextXAlignment.Left
    navTitle.Parent = sidebar

    local navIndicator = Instance.new("Frame")
    navIndicator.Name = "ActiveIndicator"
    navIndicator.Size = UDim2.fromOffset(3, 18)
    navIndicator.Position = UDim2.fromOffset(8, 44)
    navIndicator.BackgroundColor3 = state.theme.Accent
    navIndicator.BorderSizePixel = 0
    navIndicator.Parent = sidebar

    local navCorner = Instance.new("UICorner")
    navCorner.CornerRadius = UDim.new(0, 2)
    navCorner.Parent = navIndicator

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -212, 1, -94)
    content.Position = UDim2.fromOffset(196, 78)
    content.BackgroundColor3 = state.theme.Surface
    content.BorderSizePixel = 0
    content.Parent = main

    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 15)
    contentCorner.Parent = content

    local pagesFolder = Instance.new("Folder")
    pagesFolder.Name = "Pages"
    pagesFolder.Parent = content

    local tabs = {}
    local pages = {}
    local activePage = nil

    local function getPage(name)
        if pages[name] then
            return pages[name]
        end

        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Size = UDim2.new(1, 0, 1, 0)
        page.CanvasSize = UDim2.new(0, 0, 0, 2000)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = state.theme.Accent
        page.Visible = false
        page.Parent = pagesFolder

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 12)
        padding.PaddingBottom = UDim.new(0, 12)
        padding.Parent = page

        pages[name] = page
        return page
    end

    local function setPage(name)
        activePage = name
        for pageName, page in pairs(pages) do
            page.Visible = (pageName == name)
        end

        for tabName, tab in pairs(tabs) do
            local selected = tabName == name
            tab.BackgroundColor3 = selected and state.theme.SurfaceLight or state.theme.Surface
            tab.Label.TextColor3 = selected and state.theme.Text or state.theme.Muted
            tab.Icon.TextColor3 = selected and state.theme.AccentLight or state.theme.Muted
        end

        if tabs[name] then
            local targetY = tabs[name].YPos
            createTween(navIndicator, 0.2, { Position = UDim2.fromOffset(8, targetY) })
        end
    end

    local function addTabEntry(name, icon)
        local tabButton = Instance.new("TextButton")
        tabButton.Name = name .. "Tab"
        tabButton.Text = ""
        tabButton.BackgroundColor3 = state.theme.Surface
        tabButton.BorderSizePixel = 0
        tabButton.AutoButtonColor = false
        tabButton.Size = UDim2.new(1, -20, 0, 32)
        tabButton.Position = UDim2.fromOffset(10, 44 + (#tabs * 38))
        tabButton.Parent = sidebar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 9)
        tabCorner.Parent = tabButton

        local iconLabel = Instance.new("TextLabel")
        iconLabel.Text = icon or "•"
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextColor3 = state.theme.Muted
        iconLabel.TextSize = 14
        iconLabel.BackgroundTransparency = 1
        iconLabel.BorderSizePixel = 0
        iconLabel.Position = UDim2.fromOffset(10, 0)
        iconLabel.Size = UDim2.fromOffset(18, 32)
        iconLabel.TextXAlignment = Enum.TextXAlignment.Center
        iconLabel.Parent = tabButton

        local label = Instance.new("TextLabel")
        label.Text = name
        label.Font = Enum.Font.GothamMedium
        label.TextColor3 = state.theme.Muted
        label.TextSize = 12
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Position = UDim2.fromOffset(36, 0)
        label.Size = UDim2.new(1, -40, 1, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = tabButton

        tabs[name] = {
            Button = tabButton,
            Icon = iconLabel,
            Label = label,
            YPos = 44 + (#tabs * 38) + 7,
        }

        tabButton.MouseButton1Click:Connect(function()
            setPage(name)
        end)

        return tabButton
    end

    local function createHeaderText(parent, text, pos, size, color, fontSize, fontType)
        local label = Instance.new("TextLabel")
        label.Text = text
        label.Position = pos
        label.Size = size
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Font = fontType or Enum.Font.Gotham
        label.TextColor3 = color or state.theme.Text
        label.TextSize = fontSize or 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        return label
    end

    local function createRow(parent, text, value, onChanged)
        local row = Instance.new("Frame")
        row.Name = "Row"
        row.Size = UDim2.new(1, -12, 0, 56)
        row.BackgroundColor3 = state.theme.SurfaceLight
        row.BackgroundTransparency = 0.12
        row.BorderSizePixel = 0
        row.Parent = parent

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 12)
        rowCorner.Parent = row

        local label = createHeaderText(row, text, UDim2.fromOffset(14, 8), UDim2.new(1, -100, 0, 18), state.theme.Text, 12, Enum.Font.GothamBold)
        local sub = createHeaderText(row, value or "", UDim2.fromOffset(14, 28), UDim2.new(1, -100, 0, 16), state.theme.Muted, 9, Enum.Font.Gotham)

        return row, label, sub
    end

    local function addToggle(options)
        local page = pages[activePage] or getPage("General")
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -12, 0, 54)
        row.BackgroundColor3 = state.theme.SurfaceLight
        row.BackgroundTransparency = 0.14
        row.BorderSizePixel = 0
        row.Parent = page

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = row

        local title = createHeaderText(row, options.title or "Toggle", UDim2.fromOffset(14, 8), UDim2.new(1, -110, 0, 18), state.theme.Text, 12, Enum.Font.GothamBold)
        local desc = createHeaderText(row, options.description or "", UDim2.fromOffset(14, 28), UDim2.new(1, -110, 0, 14), state.theme.Muted, 9, Enum.Font.Gotham)

        local track = Instance.new("Frame")
        track.Size = UDim2.fromOffset(52, 24)
        track.Position = UDim2.new(1, -72, 0.5, -12)
        track.BackgroundColor3 = options.value and state.theme.Success or state.theme.Danger
        track.BorderSizePixel = 0
        track.Parent = row

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 12)
        trackCorner.Parent = track

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(18, 18)
        knob.Position = UDim2.fromOffset(options.value and 30 or 3, 3)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = track

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(0, 9)
        knobCorner.Parent = knob

        local button = Instance.new("TextButton")
        button.Text = ""
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, 0, 1, 0)
        button.Parent = row

        local currentValue = options.value == true
        local function refreshVisual()
            track.BackgroundColor3 = currentValue and state.theme.Success or state.theme.Danger
            knob.Position = UDim2.fromOffset(currentValue and 30 or 3, 3)
        end

        button.MouseButton1Click:Connect(function()
            currentValue = not currentValue
            refreshVisual()
            if options.onChanged then
                safeCall(options.onChanged, currentValue)
            end
        end)

        refreshVisual()
        return row
    end

    local function addSlider(options)
        local page = pages[activePage] or getPage("General")
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -12, 0, 80)
        row.BackgroundColor3 = state.theme.SurfaceLight
        row.BackgroundTransparency = 0.14
        row.BorderSizePixel = 0
        row.Parent = page

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 12)
        rowCorner.Parent = row

        local title = createHeaderText(row, options.title or "Slider", UDim2.fromOffset(14, 8), UDim2.new(1, -90, 0, 18), state.theme.Text, 12, Enum.Font.GothamBold)
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Text = tostring(options.value or 0)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextColor3 = state.theme.AccentLight
        valueLabel.TextSize = 11
        valueLabel.BackgroundTransparency = 1
        valueLabel.BorderSizePixel = 0
        valueLabel.Position = UDim2.new(1, -84, 0, 8)
        valueLabel.Size = UDim2.fromOffset(70, 18)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = row

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -28, 0, 14)
        track.Position = UDim2.fromOffset(14, 38)
        track.BackgroundColor3 = state.theme.Background
        track.BorderSizePixel = 0
        track.Parent = row

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 8)
        trackCorner.Parent = track

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0.5, 0, 1, 0)
        fill.BackgroundColor3 = state.theme.Accent
        fill.BorderSizePixel = 0
        fill.Parent = track

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 8)
        fillCorner.Parent = fill

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Position = UDim2.new(0.5, -7, 0.5, -7)
        knob.Parent = track

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(0, 7)
        knobCorner.Parent = knob

        local dragButton = Instance.new("TextButton")
        dragButton.Text = ""
        dragButton.BackgroundTransparency = 1
        dragButton.BorderSizePixel = 0
        dragButton.Size = UDim2.new(1, 0, 1, 0)
        dragButton.Parent = track

        local minValue = options.min or 0
        local maxValue = options.max or 100
        local currentValue = options.value or minValue

        local function updateVisual(rawValue)
            local clamped = math.clamp(rawValue, minValue, maxValue)
            local ratio = (clamped - minValue) / (maxValue - minValue)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            knob.Position = UDim2.new(ratio, -7, 0.5, -7)
            valueLabel.Text = tostring(math.floor(clamped + 0.5))
            currentValue = clamped
        end

        local dragging = false
        dragButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local x = input.Position.X
                local ratio = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local value = minValue + ((maxValue - minValue) * ratio)
                updateVisual(value)
                if options.onChanged then
                    safeCall(options.onChanged, value)
                end
            end
        end)

        dragButton.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local value = minValue + ((maxValue - minValue) * ratio)
                updateVisual(value)
                if options.onChanged then
                    safeCall(options.onChanged, value)
                end
            end
        end)

        dragButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        updateVisual(currentValue)
        return row
    end

    local function addButton(options)
        local page = pages[activePage] or getPage("General")
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -12, 0, 58)
        row.BackgroundColor3 = state.theme.SurfaceLight
        row.BackgroundTransparency = 0.14
        row.BorderSizePixel = 0
        row.Parent = page

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 12)
        rowCorner.Parent = row

        local button = Instance.new("TextButton")
        button.Text = options.title or "Button"
        button.Font = Enum.Font.GothamBold
        button.TextColor3 = options.textColor or state.theme.Text
        button.TextSize = options.textSize or 12
        button.BackgroundColor3 = options.color or state.theme.Accent
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -16, 1, -12)
        button.Position = UDim2.fromOffset(8, 6)
        button.Parent = row

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = button

        button.MouseButton1Click:Connect(function()
            if options.onClick then
                safeCall(options.onClick)
            end
        end)

        return row
    end

    local function addTextBox(options)
        local page = pages[activePage] or getPage("General")
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -12, 0, 56)
        row.BackgroundColor3 = state.theme.SurfaceLight
        row.BackgroundTransparency = 0.14
        row.BorderSizePixel = 0
        row.Parent = page

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 12)
        rowCorner.Parent = row

        local label = createHeaderText(row, options.title or "Input", UDim2.fromOffset(14, 8), UDim2.new(1, -110, 0, 16), state.theme.Text, 12, Enum.Font.GothamBold)

        local input = Instance.new("TextBox")
        input.Text = tostring(options.value or "")
        input.TextColor3 = state.theme.Text
        input.TextSize = 12
        input.Font = Enum.Font.Gotham
        input.PlaceholderText = options.placeholder or ""
        input.PlaceholderColor3 = state.theme.Subtle
        input.BackgroundColor3 = state.theme.Background
        input.BorderSizePixel = 0
        input.Position = UDim2.fromOffset(14, 28)
        input.Size = UDim2.new(1, -28, 0, 18)
        input.Parent = row

        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 8)
        inputCorner.Parent = input

        input.FocusLost:Connect(function()
            if options.onChanged then
                safeCall(options.onChanged, input.Text)
            end
        end)

        return row
    end

    local function showToast(titleText, descriptionText)
        local holder = Instance.new("Frame")
        holder.Name = "xFerToast"
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.new(0.5, 0, 1, -18)
        holder.Size = UDim2.fromOffset(320, 62)
        holder.BackgroundColor3 = state.theme.Surface
        holder.BorderSizePixel = 0
        holder.Parent = screenGui

        local holderCorner = Instance.new("UICorner")
        holderCorner.CornerRadius = UDim.new(0, 12)
        holderCorner.Parent = holder

        local stroke = Instance.new("UIStroke")
        stroke.Color = state.theme.Border
        stroke.Transparency = 0.35
        stroke.Thickness = 1
        stroke.Parent = holder

        local accent = Instance.new("Frame")
        accent.Size = UDim2.fromOffset(4, 26)
        accent.Position = UDim2.fromOffset(12, 18)
        accent.BackgroundColor3 = state.theme.Accent
        accent.BorderSizePixel = 0
        accent.Parent = holder

        local accentCorner = Instance.new("UICorner")
        accentCorner.CornerRadius = UDim.new(0, 3)
        accentCorner.Parent = accent

        local top = Instance.new("TextLabel")
        top.Text = titleText or "xFer"
        top.Font = Enum.Font.GothamBold
        top.TextColor3 = state.theme.Text
        top.TextSize = 11
        top.BackgroundTransparency = 1
        top.BorderSizePixel = 0
        top.Position = UDim2.fromOffset(22, 8)
        top.Size = UDim2.fromOffset(200, 18)
        top.TextXAlignment = Enum.TextXAlignment.Left
        top.Parent = holder

        local msg = Instance.new("TextLabel")
        msg.Text = descriptionText or ""
        msg.Font = Enum.Font.Gotham
        msg.TextColor3 = state.theme.Muted
        msg.TextSize = 9
        msg.BackgroundTransparency = 1
        msg.BorderSizePixel = 0
        msg.Position = UDim2.fromOffset(22, 28)
        msg.Size = UDim2.fromOffset(260, 18)
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.Parent = holder

        createTween(holder, 0.2, { Position = UDim2.new(0.5, 0, 1, -60) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        task.delay(2.5, function()
            if holder and holder.Parent then
                createTween(holder, 0.18, { Position = UDim2.new(0.5, 0, 1, 20) })
                task.delay(0.2, function()
                    if holder and holder.Parent then
                        holder:Destroy()
                    end
                end)
            end
        end)
    end

    local function setTheme(themeName)
        state.themeName = themeName
        state.theme = getTheme(themeName)
        main.BackgroundColor3 = state.theme.Background
        sidebar.BackgroundColor3 = state.theme.Surface
        content.BackgroundColor3 = state.theme.Surface
        for _, row in pairs(state.controls) do
            if row and row.Parent then
                row.BackgroundColor3 = state.theme.SurfaceLight
            end
        end
    end

    local function refreshSavedConfigList()
        state.savedConfigs = {}
        local files = {}

        if typeof(listfiles) == "function" then
            local ok, result = pcall(function()
                return listfiles(CONFIG.configFolder)
            end)
            if ok and type(result) == "table" then
                files = result
            end
        end

        for _, filePath in ipairs(files) do
            local name = tostring(filePath):match("([^/\\]+)%.json$")
            if name then
                table.insert(state.savedConfigs, name)
            end
        end
    end

    self.addTab = function(name, builder)
        addTabEntry(name, builder.icon or "•")
        getPage(name)

        if builder then
            builder(getPage(name), {
                addToggle = addToggle,
                addSlider = addSlider,
                addButton = addButton,
                addTextBox = addTextBox,
            })
        end

        if activePage == nil then
            setPage(name)
        end
    end

    self.addToggle = function(opts)
        local finalOptions = {
            title = opts.title or "Toggle",
            description = opts.description or "",
            value = opts.value or false,
            onChanged = opts.onChanged,
        }
        return addToggle(finalOptions)
    end

    self.addSlider = function(opts)
        local finalOptions = {
            title = opts.title or "Slider",
            value = opts.value or 0,
            min = opts.min or 0,
            max = opts.max or 100,
            onChanged = opts.onChanged,
        }
        return addSlider(finalOptions)
    end

    self.addButton = function(opts)
        return addButton({
            title = opts.title or "Button",
            color = opts.color or state.theme.Accent,
            textColor = opts.textColor or state.theme.Text,
            onClick = opts.onClick,
        })
    end

    self.addTextBox = function(opts)
        return addTextBox({
            title = opts.title or "Input",
            value = opts.value or "",
            placeholder = opts.placeholder or "",
            onChanged = opts.onChanged,
        })
    end

    self.showToast = showToast
    self.setTheme = setTheme
    self.saveConfig = function(data)
        return saveConfig(data or state.config)
    end
    self.loadConfig = function()
        state.config = loadConfig()
        return state.config
    end
    self.show = function()
        state.open = true
        main.Visible = true
        createTween(blurEffect, 0.18, { Size = 12 })
        createTween(main, 0.2, { GroupTransparency = 0 })
    end
    self.hide = function()
        state.open = false
        createTween(blurEffect, 0.18, { Size = 0 })
        createTween(main, 0.2, { GroupTransparency = 1 })
        task.delay(0.22, function()
            if main and main.Parent then
                main.Visible = false
            end
        end)
    end
    self.toggle = function()
        if state.open then
            self.hide()
        else
            self.show()
        end
    end
    self.destroy = function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
        if blurEffect and blurEffect.Parent then
            blurEffect:Destroy()
        end
    end

    main.Visible = true
    createTween(main, 0.2, { GroupTransparency = 0 })
    createTween(blurEffect, 0.2, { Size = 12 })

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextColor3 = state.theme.Danger
    closeBtn.TextSize = 14
    closeBtn.AutoButtonColor = false
    closeBtn.Size = UDim2.fromOffset(32, 32)
    closeBtn.Position = UDim2.new(1, -48, 0, 18)
    closeBtn.BackgroundColor3 = state.theme.SurfaceLight
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        self.hide()
    end)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Text = "⚙"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextColor3 = state.theme.Text
    toggleBtn.TextSize = 15
    toggleBtn.AutoButtonColor = false
    toggleBtn.Size = UDim2.fromOffset(32, 32)
    toggleBtn.Position = UDim2.new(1, -92, 0, 18)
    toggleBtn.BackgroundColor3 = state.theme.SurfaceLight
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = header

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        self.showToast("xFer", "Configuración abierta")
    end)

    local dragging = false
    local dragStart = nil
    local startPos = nil

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPos then
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragStart = nil
            startPos = nil
        end
    end)

    self.showToast = showToast

    return self
end

local function buildFeatureRegistry()
    local featureList = {
        {
            id = "character_noclip",
            name = "Noclip",
            category = "Character",
            type = "toggle",
            default = false,
            description = "Atraviesa paredes",
            init = function(api)
                local state = { enabled = false }
                local originalStates = {}

                local function apply()
                    local character = api.character and api.character()
                    if not character then
                        return
                    end

                    for _, descendant in ipairs(character:GetDescendants()) do
                        if descendant:IsA("BasePart") then
                            if state.enabled then
                                originalStates[descendant] = descendant.CanCollide
                                descendant.CanCollide = false
                            else
                                if originalStates[descendant] ~= nil then
                                    descendant.CanCollide = originalStates[descendant]
                                end
                            end
                        end
                    end
                end

                api.addToggle({
                    title = "Noclip",
                    description = "Atraviesa paredes",
                    value = state.enabled,
                    onChanged = function(enabled)
                        state.enabled = enabled
                        pcall(apply)
                    end,
                })
            end,
        },
        {
            id = "character_speed",
            name = "Speed",
            category = "Character",
            type = "slider",
            default = 16,
            min = 16,
            max = 200,
            description = "Velocidad del personaje",
            init = function(api)
                local state = { value = 16 }
                local humanoid = nil

                local function refresh()
                    humanoid = api.character and api.character() and api.character():FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.WalkSpeed = tonumber(state.value) or 16
                    end
                end

                api.addSlider({
                    title = "WalkSpeed",
                    min = 16,
                    max = 200,
                    value = state.value,
                    onChanged = function(value)
                        state.value = value
                        pcall(refresh)
                    end,
                })
            end,
        },
        {
            id = "character_jump",
            name = "Jump",
            category = "Character",
            type = "slider",
            min = 50,
            max = 500,
            default = 50,
            description = "Potencia del salto",
            init = function(api)
                local state = { value = 50 }
                api.addSlider({
                    title = "JumpPower",
                    min = 50,
                    max = 500,
                    value = state.value,
                    onChanged = function(value)
                        state.value = value
                        pcall(function()
                            local character = api.character and api.character()
                            if character then
                                local hum = character:FindFirstChildOfClass("Humanoid")
                                if hum then
                                    hum.JumpPower = value
                                end
                            end
                        end)
                    end,
                })
            end,
        },
        {
            id = "character_fly",
            name = "Fly",
            category = "Character",
            type = "toggle",
            default = false,
            description = "Vuelo básico",
            init = function(api)
                local enabled = false
                local root = nil
                local bodyVelocity = nil
                local bodyGyro = nil

                local function ensureParts()
                    if not root then
                        local character = api.character and api.character()
                        if character then
                            root = character:FindFirstChild("HumanoidRootPart")
                        end
                    end

                    if root and not bodyVelocity then
                        bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                        bodyVelocity.P = 2000
                        bodyVelocity.Parent = root
                    end

                    if root and not bodyGyro then
                        bodyGyro = Instance.new("BodyGyro")
                        bodyGyro.MaxTorque = Vector3.new(50000, 50000, 50000)
                        bodyGyro.Parent = root
                    end
                end

                local function updateFly()
                    local character = api.character and api.character()
                    if not character then
                        return
                    end

                    root = character:FindFirstChild("HumanoidRootPart")
                    if not root then
                        return
                    end

                    if enabled then
                        ensureParts()
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                        bodyGyro.CFrame = CFrame.new(root.Position, root.Position + Camera.CFrame.LookVector)
                    else
                        if bodyVelocity then
                            bodyVelocity.Velocity = Vector3.zero
                        end
                        if bodyGyro then
                            bodyGyro.CFrame = CFrame.new(root.Position)
                        end
                    end
                end

                api.addToggle({
                    title = "Fly",
                    description = "Vuelo básico",
                    value = false,
                    onChanged = function(value)
                        enabled = value
                        pcall(updateFly)
                    end,
                })
            end,
        },
        {
            id = "character_antiafk",
            name = "Anti-AFK",
            category = "Character",
            type = "toggle",
            default = false,
            description = "Evita inactividad",
            init = function(api)
                local enabled = false
                local connection = nil

                api.addToggle({
                    title = "Anti-AFK",
                    description = "Evita el afk",
                    value = false,
                    onChanged = function(value)
                        enabled = value
                        if enabled then
                            if connection then
                                connection:Disconnect()
                            end
                            connection = localPlayer.Idled:Connect(function()
                                pcall(function()
                                    local virtualUser = game:GetService("VirtualUser")
                                    virtualUser:CaptureController()
                                    virtualUser:ClickButton2(Vector2.new())
                                end)
                            end)
                        elseif connection then
                            connection:Disconnect()
                            connection = nil
                        end
                    end,
                })
            end,
        },
        {
            id = "vehicle_speed_hack",
            name = "Vehicle Speed Hack",
            category = "Vehicle",
            type = "slider",
            min = 50,
            max = 300,
            default = 100,
            description = "Velocidad del vehículo",
            init = function(api)
                api.addSlider({
                    title = "Vehicle Speed",
                    min = 50,
                    max = 300,
                    value = 100,
                    onChanged = function(value)
                        pcall(function()
                            local vehicle = workspace:FindFirstChildOfClass("Model")
                            if vehicle then
                                for _, part in ipairs(vehicle:GetDescendants()) do
                                    if part:IsA("BasePart") then
                                        part.AssemblyLinearVelocity = Vector3.new(value, part.AssemblyLinearVelocity.Y, value)
                                    end
                                end
                            end
                        end)
                    end,
                })
            end,
        },
        {
            id = "vehicle_noclip",
            name = "Vehicle Noclip",
            category = "Vehicle",
            type = "toggle",
            default = false,
            description = "No colisionar con el vehículo",
            init = function(api)
                api.addToggle({
                    title = "Vehicle Noclip",
                    description = "No colisionar con el vehículo",
                    value = false,
                    onChanged = function(value)
                        pcall(function()
                            local vehicle = workspace:FindFirstChildOfClass("Model")
                            if vehicle then
                                for _, descendant in ipairs(vehicle:GetDescendants()) do
                                    if descendant:IsA("BasePart") then
                                        descendant.CanCollide = not value
                                    end
                                end
                            end
                        end)
                    end,
                })
            end,
        },
        {
            id = "combat_esp",
            name = "ESP",
            category = "Combat",
            type = "toggle",
            default = false,
            description = "Resaltar jugadores",
            init = function(api)
                local highlights = {}
                local enabled = false

                local function refresh()
                    local players = Players:GetPlayers()
                    for _, player in ipairs(players) do
                        if player ~= localPlayer then
                            local char = player.Character
                            if char then
                                if enabled then
                                    if not highlights[player] then
                                        local highlight = Instance.new("Highlight")
                                        highlight.FillColor = Color3.fromRGB(255, 90, 90)
                                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                                        highlight.FillTransparency = 0.35
                                        highlight.OutlineTransparency = 0
                                        highlight.Adornee = char
                                        highlight.Parent = char
                                        highlights[player] = highlight
                                    end
                                elseif highlights[player] then
                                    highlights[player]:Destroy()
                                    highlights[player] = nil
                                end
                            end
                        end
                    end
                end

                api.addToggle({
                    title = "ESP",
                    description = "Resaltar jugadores",
                    value = false,
                    onChanged = function(value)
                        enabled = value
                        pcall(refresh)
                    end,
                })
            end,
        },
        {
            id = "combat_aimbot",
            name = "Aimbot",
            category = "Combat",
            type = "toggle",
            default = false,
            description = "Apuntar automáticamente",
            init = function(api)
                local enabled = false
                local connection = nil

                local function findTarget()
                    local cameraPos = Camera.CFrame.Position
                    local nearestTarget = nil
                    local nearestDistance = math.huge

                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= localPlayer and player.Character then
                            local hum = player.Character:FindFirstChildOfClass("Humanoid")
                            local root = player.Character:FindFirstChild("HumanoidRootPart")
                            if hum and hum.Health > 0 and root then
                                local dist = (root.Position - cameraPos).Magnitude
                                if dist < nearestDistance then
                                    nearestDistance = dist
                                    nearestTarget = player
                                end
                            end
                        end
                    end

                    return nearestTarget
                end

                local function tick()
                    if not enabled then
                        return
                    end

                    local target = findTarget()
                    if not target or not target.Character then
                        return
                    end

                    local head = target.Character:FindFirstChild("Head")
                    if not head then
                        return
                    end

                    local lookAt = CFrame.new(Camera.CFrame.Position, head.Position)
                    local current = Camera.CFrame:Lerp(lookAt, 0.14)
                    Camera.CFrame = current
                end

                api.addToggle({
                    title = "Aimbot",
                    description = "Apuntar automáticamente",
                    value = false,
                    onChanged = function(value)
                        enabled = value
                        if value then
                            if connection then
                                connection:Disconnect()
                            end
                            connection = RunService.RenderStepped:Connect(tick)
                        elseif connection then
                            connection:Disconnect()
                            connection = nil
                        end
                    end,
                })
            end,
        },
        {
            id = "utility_server_browser",
            name = "Server Browser",
            category = "Utility",
            type = "button",
            default = nil,
            description = "Abre navegador de servidores",
            init = function(api)
                api.addButton({
                    title = "Server Browser",
                    color = Color3.fromRGB(212, 175, 55),
                    onClick = function()
                        api.notify("Server Browser", "Función de navegador en desarrollo")
                    end,
                })
            end,
        },
        {
            id = "utility_rejoin",
            name = "Rejoin",
            category = "Utility",
            type = "button",
            default = nil,
            description = "Vuelve a unirse al servidor",
            init = function(api)
                api.addButton({
                    title = "Rejoin",
                    color = Color3.fromRGB(255, 104, 104),
                    onClick = function()
                        pcall(function()
                            local placeId = game.PlaceId
                            local jobId = game.JobId
                            if jobId and jobId ~= "" then
                                TeleportService:Teleport(placeId, localPlayer)
                            end
                        end)
                    end,
                })
            end,
        },
    }

    for _, feature in ipairs(featureList) do
        NovaFeatures.register(feature)
    end
end

local function initializeFeatures(ui)
    local featureApi = {
        addToggle = ui.addToggle,
        addSlider = ui.addSlider,
        addButton = ui.addButton,
        addTextBox = ui.addTextBox,
        character = function()
            return localPlayer.Character
        end,
        notify = function(title, message)
            if ui and ui.showToast then
                ui.showToast(title or "xFer", message or "")
            end
        end,
        save = function(data)
            return ui.saveConfig(data)
        end,
        load = function()
            if ui and ui.loadConfig then
                return ui.loadConfig()
            end
            return loadConfig()
        end,
        log = function(level, message, extra)
            logger(level or "info", message, extra)
        end,
    }

    for _, feature in ipairs(NovaFeatures.list) do
        if type(feature.init) == "function" then
            pcall(function()
                feature.init(featureApi)
            end)
        end
    end
end

local function main()
    local ok, result = pcall(function()
        if CONFIG.autoUpdate then
            performAutoUpdate()
        end

        local ui = createNovaUI({
            title = "xFer Universal",
            theme = "dark_gold",
            mobileFriendly = true,
            resizable = true,
        })

        -- Añadimos una tab de overview básica
        ui.addTab("Overview", function(page, api)
            local intro = Instance.new("TextLabel")
            intro.Text = "xFer Universal\n\nScript universal para Roblox con framework modular, actualizaciones automáticas y features plug-and-play."
            intro.BackgroundTransparency = 1
            intro.BorderSizePixel = 0
            intro.Size = UDim2.new(1, -24, 0, 120)
            intro.Position = UDim2.fromOffset(12, 10)
            intro.Font = Enum.Font.Gotham
            intro.TextColor3 = getTheme(CONFIG.defaultTheme).Text
            intro.TextSize = 13
            intro.TextWrapped = true
            intro.TextXAlignment = Enum.TextXAlignment.Left
            intro.TextYAlignment = Enum.TextYAlignment.Top
            intro.Parent = page

            api.addToggle({
                title = "Auto-Update",
                description = "Comprobar actualizaciones",
                value = CONFIG.autoUpdate,
                onChanged = function(value)
                    CONFIG.autoUpdate = value
                end,
            })
        end)

        ui.addTab("Character", function(page, api)
            api.addToggle({ title = "Noclip", description = "Atraviesa paredes", value = false, onChanged = function(value) end })
            api.addSlider({ title = "WalkSpeed", min = 16, max = 200, value = 16, onChanged = function(value) end })
            api.addSlider({ title = "JumpPower", min = 50, max = 500, value = 50, onChanged = function(value) end })
            api.addToggle({ title = "Fly", description = "Vuelo básico", value = false, onChanged = function(value) end })
            api.addToggle({ title = "Anti-AFK", description = "Evita inactividad", value = false, onChanged = function(value) end })
        end)

        ui.addTab("Combat", function(page, api)
            api.addToggle({ title = "ESP", description = "Resalte simple", value = false, onChanged = function(value) end })
            api.addToggle({ title = "Aimbot", description = "Apunta automáticamente", value = false, onChanged = function(value) end })
        end)

        ui.addTab("Utility", function(page, api)
            api.addButton({ title = "Server Browser", color = getTheme(CONFIG.defaultTheme).Accent, onClick = function() ui.showToast("Server Browser", "Módulo en desarrollo") end })
            api.addButton({ title = "Rejoin", color = getTheme(CONFIG.defaultTheme).Danger, onClick = function() end })
        end)

        initializeFeatures(ui)
        logger("info", "xFer Universal cargado correctamente.")
        return ui
    end)

    if not ok then
        logger("error", "Error principal del script", result)
    end
end

local success = pcall(main)
if not success then
    logger("error", "Carga fallida del script principal")
end
