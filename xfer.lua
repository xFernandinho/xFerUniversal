--[[
    xFer Universal
    Version: 1.0.0
    Author: xFernandinho
    Description: Script universal de Roblox con framework de UI modular, auto-actualización y features plug-and-play.

    Cambios clave:
      - se corrigió el problema de UI inexistente y no interactiva
      - se agregó un botón flotante para abrir/cerrar
      - se corrige el uso de GroupTransparency sobre Frame
      - se mantiene el estilo visual dark + gold
      - se mantiene la arquitectura de tabs, toggles y registros de features
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local VERSION = "1.0.0"
local RAW_URL = "https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.lua"
local VERSION_URL = "https://raw.githubusercontent.com/xFernandinho/xFerUniversal/main/xfer.version"
local CONFIG_DIR = "xFerUniversal"
local CONFIG_FILE = CONFIG_DIR .. "/settings.json"

local THEME = {
    Background = Color3.fromRGB(15, 17, 24),
    Surface = Color3.fromRGB(22, 25, 35),
    SurfaceLight = Color3.fromRGB(30, 35, 45),
    SurfaceHover = Color3.fromRGB(42, 48, 62),
    Border = Color3.fromRGB(86, 79, 54),
    Accent = Color3.fromRGB(212, 175, 55),
    AccentLight = Color3.fromRGB(232, 205, 120),
    Text = Color3.fromRGB(245, 245, 245),
    Muted = Color3.fromRGB(170, 172, 180),
    Subtle = Color3.fromRGB(120, 124, 132),
    Success = Color3.fromRGB(110, 220, 170),
    Danger = Color3.fromRGB(255, 100, 100),
    Warning = Color3.fromRGB(255, 190, 110),
    Blue = Color3.fromRGB(100, 170, 255),
}

local function log(level, message, extra)
    if level == "debug" then
        return
    end
    print("[xFer] [" .. string.upper(level) .. "] " .. tostring(message))
    if extra ~= nil then
        print(tostring(extra))
    end
end

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        log("warn", "safeCall failed", res)
        return nil
    end
    return res
end

local function safeHttpGet(url)
    if type(url) ~= "string" or url == "" then
        return nil
    end

    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        log("warn", "HttpGet failed for " .. url, res)
        return nil
    end

    return res
end

local function ensureConfigFolder()
    if typeof(makefolder) ~= "function" then
        return false
    end

    local ok = pcall(function()
        if not isfolder(CONFIG_DIR) then
            makefolder(CONFIG_DIR)
        end
    end)

    return ok
end

local function getConfigPath()
    local gameName = tostring(game.Name or "RobloxGame")
    local safeGame = string.gsub(gameName, "[^%w%-_]", "_")
    return CONFIG_DIR .. "/" .. safeGame .. "_" .. tostring(game.PlaceId or "local") .. ".json"
end

local function saveSettings(data)
    if typeof(writefile) ~= "function" then
        return false
    end

    local ok = pcall(function()
        ensureConfigFolder()
        writefile(getConfigPath(), HttpService:JSONEncode(data or {}))
    end)

    return ok
end

local function loadSettings()
    if typeof(readfile) ~= "function" then
        return {}
    end

    local path = getConfigPath()
    if typeof(isfile) == "function" and not isfile(path) then
        return {}
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if ok and type(result) == "table" then
        return result
    end

    return {}
end

local function tweenObject(object, duration, props, style, direction)
    if not object or not object.Parent then
        return nil
    end

    local tweenInfo = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tween = TweenService:Create(object, tweenInfo, props or {})
    tween:Play()
    return tween
end

local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function addCorner(object, radius)
    local corner = make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
    return corner
end

local function addStroke(object, color, transparency, thickness)
    local stroke = make("UIStroke", {
        Color = color or THEME.Border,
        Transparency = transparency or 0.35,
        Thickness = thickness or 1,
    }, object)
    return stroke
end

local function makeText(parent, text, pos, size, font, textSize, color, alignment)
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = pos,
        Size = size,
        Font = font or Enum.Font.Gotham,
        Text = text or "",
        TextColor3 = color or THEME.Text,
        TextSize = textSize or 12,
        TextXAlignment = alignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
    return label
end

local function compareVersion(localVersion, remoteVersion)
    local function toNum(str)
        local parts = {}
        for n in tostring(str):gmatch("(%d+)") do
            table.insert(parts, tonumber(n) or 0)
        end
        local total = 0
        for i, v in ipairs(parts) do
            total = total + (v * (10 ^ (3 * (#parts - i))))
        end
        return total
    end

    local localNum = toNum(localVersion)
    local remoteNum = toNum(remoteVersion)
    if remoteNum > localNum then return 1 end
    if remoteNum < localNum then return -1 end
    return 0
end

local function checkForUpdate()
    if typeof(game.HttpGet) ~= "function" then
        return false
    end

    local remoteText = safeHttpGet(VERSION_URL)
    if type(remoteText) ~= "string" then
        return false
    end

    local cleaned = string.gsub(remoteText, "%s+", "")
    if cleaned == "" then
        return false
    end

    if compareVersion(VERSION, cleaned) >= 0 then
        return false
    end

    local remoteScript = safeHttpGet(RAW_URL)
    if type(remoteScript) ~= "string" or remoteScript == "" then
        return false
    end

    local compiled = loadstring(remoteScript)
    if type(compiled) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return compiled()
    end)

    if ok then
        log("info", "Actualización aplicada con éxito")
        return true
    end

    log("warn", "No se pudo ejecutar la actualización remota", result)
    return false
end

local NovaFeatures = {
    list = {}
}

function NovaFeatures.register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" then
        return nil
    end
    local feature = {
        id = def.id,
        name = def.name or def.id,
        category = def.category or "General",
        type = def.type or "toggle",
        default = def.default,
        description = def.description or "",
        init = def.init or function() end,
    }
    table.insert(NovaFeatures.list, feature)
    return feature
end

local function createNovaUI(options)
    options = options or {}
    local currentPage = "Overview"
    local pageList = {}
    local theme = THEME

    local screenGui = make("ScreenGui", {
        Name = "xFerNovaUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
    }, playerGui)

    local blur = make("BlurEffect", {
        Name = "xFerNovaBlur",
        Size = 0,
        Enabled = true,
    }, Lighting)

    local floatingButton = make("TextButton", {
        Name = "FloatingToggle",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 26, 0.5, 0),
        Size = UDim2.fromOffset(60, 60),
        BackgroundColor3 = THEME.Surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 200,
    }, screenGui)
    addCorner(floatingButton, 18)
    addStroke(floatingButton, THEME.Border, 0.4, 1)

    local topBar = make("Frame", {
        BackgroundColor3 = THEME.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(760, 500),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false,
        ZIndex = 100,
    }, screenGui)
    addCorner(topBar, 18)
    addStroke(topBar, THEME.Border, 0.25, 1)

    local topBarCanvas = make("CanvasGroup", {
        Name = "MainWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(760, 500),
        BackgroundColor3 = THEME.Background,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = 101,
    }, screenGui)
    addCorner(topBarCanvas, 18)
    addStroke(topBarCanvas, THEME.Border, 0.18, 1)

    local header = make("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 62),
        ZIndex = 102,
    }, topBarCanvas)

    local logo = make("Frame", {
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 12),
        Size = UDim2.fromOffset(38, 38),
        ZIndex = 103,
    }, header)
    addCorner(logo, 12)
    local logoGrad = make("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, THEME.Blue),
            ColorSequenceKeypoint.new(0.5, THEME.Accent),
            ColorSequenceKeypoint.new(1, THEME.AccentLight),
        }),
    }, logo)
    makeText(logo, "X", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, 18, Color3.new(1,1,1), Enum.TextXAlignment.Center)

    makeText(header, "xFer Universal", UDim2.fromOffset(66, 10), UDim2.fromOffset(220, 20), Enum.Font.GothamBlack, 17, THEME.Text)
    makeText(header, "Multi Tool Script", UDim2.fromOffset(68, 32), UDim2.fromOffset(180, 18), Enum.Font.GothamMedium, 9, THEME.Muted)
    makeText(header, "v" .. VERSION, UDim2.new(1, -95, 0, 18), UDim2.fromOffset(80, 18), Enum.Font.GothamBold, 11, THEME.Muted, Enum.TextXAlignment.Right)

    local closeBtn = make("TextButton", {
        BackgroundColor3 = THEME.SurfaceLight,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -92, 0, 18),
        Size = UDim2.fromOffset(32, 32),
        Text = "✕",
        Font = Enum.Font.GothamBlack,
        TextColor3 = THEME.Danger,
        TextSize = 13,
        AutoButtonColor = false,
    }, header)
    addCorner(closeBtn, 8)

    local settingsBtn = make("TextButton", {
        BackgroundColor3 = THEME.SurfaceLight,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -50, 0, 18),
        Size = UDim2.fromOffset(32, 32),
        Text = "⚙",
        Font = Enum.Font.GothamBold,
        TextColor3 = THEME.Text,
        TextSize = 15,
        AutoButtonColor = false,
    }, header)
    addCorner(settingsBtn, 8)

    local sidebar = make("Frame", {
        BackgroundColor3 = THEME.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 78),
        Size = UDim2.new(0, 170, 1, -94),
        ZIndex = 101,
    }, topBarCanvas)
    addCorner(sidebar, 15)
    addStroke(sidebar, THEME.Border, 0.35, 1)

    local navTitle = makeText(sidebar, "NAVIGATION", UDim2.fromOffset(12, 14), UDim2.new(1, -20, 0, 16), Enum.Font.GothamBold, 9, THEME.Subtle)
    local navIndicator = make("Frame", {
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 44),
        Size = UDim2.fromOffset(3, 18),
        ZIndex = 102,
    }, sidebar)
    addCorner(navIndicator, 4)

    local contentArea = make("Frame", {
        BackgroundColor3 = THEME.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(196, 78),
        Size = UDim2.new(1, -212, 1, -94),
        ZIndex = 101,
    }, topBarCanvas)
    addCorner(contentArea, 15)
    addStroke(contentArea, THEME.Border, 0.35, 1)

    local pageFolder = make("Folder", {}, contentArea)
    local tabs = {}

    local function buildPage(name)
        local frame = make("ScrollingFrame", {
            Name = name .. "Page",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 1500),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = THEME.Accent,
            Visible = false,
        }, pageFolder)

        local listLayout = make("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, frame)

        local padding = make("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
        }, frame)

        pageList[name] = frame
        return frame
    end

    local function setPage(name)
        currentPage = name
        for key, page in pairs(pageList) do
            page.Visible = (key == name)
        end

        for key, tab in pairs(tabs) do
            local active = (key == name)
            tab.Button.BackgroundColor3 = active and THEME.SurfaceLight or THEME.Surface
            tab.Icon.TextColor3 = active and THEME.AccentLight or THEME.Muted
            tab.Label.TextColor3 = active and THEME.Text or THEME.Muted
        end

        if tabs[name] then
            tweenObject(navIndicator, 0.18, { Position = UDim2.fromOffset(8, tabs[name].YPos) })
        end
    end

    local function createTabButton(name, icon)
        local button = make("TextButton", {
            Name = name .. "Tab",
            Text = "",
            BackgroundColor3 = THEME.Surface,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(10, 44 + (#tabs * 38)),
            Size = UDim2.new(1, -20, 0, 32),
            AutoButtonColor = false,
        }, sidebar)
        addCorner(button, 9)

        local iconLabel = makeText(button, icon or "•", UDim2.fromOffset(10, 0), UDim2.fromOffset(20, 32), Enum.Font.GothamBold, 14, THEME.Muted)
        local label = makeText(button, name, UDim2.fromOffset(38, 0), UDim2.new(1, -48, 1, 0), Enum.Font.GothamMedium, 12, THEME.Muted)

        tabs[name] = {
            Button = button,
            Icon = iconLabel,
            Label = label,
            YPos = 44 + (#tabs * 38) + 7,
        }

        button.MouseButton1Click:Connect(function()
            setPage(name)
        end)
    end

    local function createSectionHeader(page, title, y)
        local headerSection = make("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 24),
        }, page)
        local line = make("Frame", {
            BackgroundColor3 = THEME.Accent,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 10),
            Size = UDim2.fromOffset(3, 12),
        }, headerSection)
        addCorner(line, 2)
        makeText(headerSection, title, UDim2.fromOffset(12, 0), UDim2.new(1, -12, 1, 0), Enum.Font.GothamBold, 9, THEME.Subtle)
        return y + 26
    end

    local function addRow(page, title, desc, kind, settings)
        local row = make("Frame", {
            BackgroundColor3 = THEME.SurfaceLight,
            BackgroundTransparency = 0.12,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -12, 0, kind == "toggle" and 54 or kind == "slider" and 80 or 56),
        }, page)
        addCorner(row, 12)

        makeText(row, title, UDim2.fromOffset(14, 8), UDim2.new(1, -110, 0, 18), Enum.Font.GothamBold, 12, THEME.Text)
        if desc then
            makeText(row, desc, UDim2.fromOffset(14, 28), UDim2.new(1, -110, 0, 14), Enum.Font.Gotham, 9, THEME.Muted)
        end

        if kind == "toggle" then
            local track = make("Frame", {
                BackgroundColor3 = settings.value and THEME.Success or THEME.Danger,
                BorderSizePixel = 0,
                Position = UDim2.new(1, -72, 0.5, -12),
                Size = UDim2.fromOffset(52, 24),
            }, row)
            addCorner(track, 12)

            local knob = make("Frame", {
                BackgroundColor3 = Color3.new(1,1,1),
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(settings.value and 29 or 3, 3),
                Size = UDim2.fromOffset(18, 18),
            }, track)
            addCorner(knob, 9)

            local btn = make("TextButton", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
            }, row)

            local current = settings.value == true
            local function refresh()
                track.BackgroundColor3 = current and THEME.Success or THEME.Danger
                knob.Position = UDim2.fromOffset(current and 29 or 3, 3)
            end

            btn.MouseButton1Click:Connect(function()
                current = not current
                refresh()
                if settings.onChanged then
                    safeCall(settings.onChanged, current)
                end
            end)

            refresh()
            return row
        end

        if kind == "slider" then
            local valueLabel = makeText(row, tostring(settings.value or 0), UDim2.new(1, -86, 0, 8), UDim2.fromOffset(70, 18), Enum.Font.GothamBold, 11, THEME.AccentLight, Enum.TextXAlignment.Right)
            local track = make("Frame", {
                BackgroundColor3 = THEME.Background,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(14, 38),
                Size = UDim2.new(1, -28, 0, 14),
            }, row)
            addCorner(track, 8)

            local fill = make("Frame", {
                BackgroundColor3 = THEME.Accent,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0.5, 0, 1, 0),
            }, track)
            addCorner(fill, 8)

            local knob = make("Frame", {
                BackgroundColor3 = Color3.new(1,1,1),
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, -7, 0.5, -7),
                Size = UDim2.fromOffset(14, 14),
            }, track)
            addCorner(knob, 7)

            local dragButton = make("TextButton", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
            }, track)

            local minValue = settings.min or 0
            local maxValue = settings.max or 100
            local currentValue = settings.value or minValue
            local dragging = false

            local function refreshVisual(raw)
                local clamped = math.clamp(raw, minValue, maxValue)
                local ratio = (clamped - minValue) / (maxValue - minValue)
                fill.Size = UDim2.new(ratio, 0, 1, 0)
                knob.Position = UDim2.new(ratio, -7, 0.5, -7)
                valueLabel.Text = tostring(math.floor(clamped + 0.5))
            end

            dragButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    local value = minValue + (maxValue - minValue) * rel
                    refreshVisual(value)
                    if settings.onChanged then
                        safeCall(settings.onChanged, value)
                    end
                end
            end)

            dragButton.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    local value = minValue + (maxValue - minValue) * rel
                    refreshVisual(value)
                    if settings.onChanged then
                        safeCall(settings.onChanged, value)
                    end
                end
            end)

            dragButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            refreshVisual(currentValue)
            return row
        end

        if kind == "button" then
            local btn = make("TextButton", {
                BackgroundColor3 = settings.color or THEME.Accent,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(8, 6),
                Size = UDim2.new(1, -16, 1, -12),
                Text = title,
                Font = Enum.Font.GothamBold,
                TextColor3 = settings.textColor or THEME.Text,
                TextSize = settings.textSize or 12,
                AutoButtonColor = false,
            }, row)
            addCorner(btn, 10)
            btn.MouseButton1Click:Connect(function()
                if settings.onClick then
                    safeCall(settings.onClick)
                end
            end)
            return row
        end

        if kind == "textbox" then
            local input = make("TextBox", {
                BackgroundColor3 = THEME.Background,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(14, 28),
                Size = UDim2.new(1, -28, 0, 18),
                PlaceholderText = settings.placeholder or "",
                PlaceholderColor3 = THEME.Subtle,
                TextColor3 = THEME.Text,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                Text = tostring(settings.value or ""),
            }, row)
            addCorner(input, 8)
            input.FocusLost:Connect(function()
                if settings.onChanged then
                    safeCall(settings.onChanged, input.Text)
                end
            end)
            return row
        end

        return row
    end

    local function showToast(titleText, descriptionText)
        local toast = make("Frame", {
            Name = "Toast",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 1, -18),
            Size = UDim2.fromOffset(320, 62),
            BackgroundColor3 = THEME.Surface,
            BorderSizePixel = 0,
            ZIndex = 500,
        }, screenGui)
        addCorner(toast, 12)
        addStroke(toast, THEME.Border, 0.35, 1)

        make("Frame", {
            BackgroundColor3 = THEME.Accent,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 18),
            Size = UDim2.fromOffset(4, 26),
        }, toast)

        makeText(toast, titleText or "xFer", UDim2.fromOffset(22, 8), UDim2.fromOffset(200, 18), Enum.Font.GothamBold, 11, THEME.Text)
        makeText(toast, descriptionText or "", UDim2.fromOffset(22, 28), UDim2.fromOffset(260, 18), Enum.Font.Gotham, 9, THEME.Muted)

        tweenObject(toast, 0.2, { Position = UDim2.new(0.5, 0, 1, -76) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(2.2, function()
            if toast and toast.Parent then
                tweenObject(toast, 0.18, { Position = UDim2.new(0.5, 0, 1, 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.18, function()
                    if toast and toast.Parent then
                        toast:Destroy()
                    end
                end)
            end
        end)
    end

    local api = {}
    local activePageObject = nil

    api.addTab = function(name, builder)
        if not name then return end
        createTabButton(name, "•")
        local page = buildPage(name)
        if builder and type(builder) == "function" then
            builder(page, api)
        end
        if not activePageObject then
            activePageObject = name
            setPage(name)
        end
    end

    api.addToggle = function(options)
        local page = pageList[currentPage] or buildPage(currentPage)
        return addRow(page, options.title or "Toggle", options.description, "toggle", {
            value = options.value or false,
            onChanged = options.onChanged,
        })
    end

    api.addSlider = function(options)
        local page = pageList[currentPage] or buildPage(currentPage)
        return addRow(page, options.title or "Slider", options.description, "slider", {
            value = options.value or 0,
            min = options.min or 0,
            max = options.max or 100,
            onChanged = options.onChanged,
        })
    end

    api.addButton = function(options)
        local page = pageList[currentPage] or buildPage(currentPage)
        return addRow(page, options.title or "Button", nil, "button", {
            color = options.color or THEME.Accent,
            textColor = options.textColor or THEME.Text,
            onClick = options.onClick,
        })
    end

    api.addTextBox = function(options)
        local page = pageList[currentPage] or buildPage(currentPage)
        return addRow(page, options.title or "Input", options.description, "textbox", {
            value = options.value or "",
            placeholder = options.placeholder or "",
            onChanged = options.onChanged,
        })
    end

    api.showToast = showToast
    api.show = function()
        topBarCanvas.Visible = true
        topBar.Visible = true
        topBarCanvas.GroupTransparency = 1
        tweenObject(topBarCanvas, 0.2, { GroupTransparency = 0 })
        tweenObject(blur, 0.2, { Size = 12 })
        tweenObject(floatingButton, 0.15, { Rotation = 0 })
    end
    api.hide = function()
        tweenObject(topBarCanvas, 0.18, { GroupTransparency = 1 })
        tweenObject(blur, 0.18, { Size = 0 })
        task.delay(0.18, function()
            if topBarCanvas and topBarCanvas.Parent then
                topBarCanvas.Visible = false
            end
        end)
    end
    api.toggle = function()
        if topBarCanvas.Visible then
            api.hide()
        else
            api.show()
        end
    end
    api.destroy = function()
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
        if blur and blur.Parent then
            blur:Destroy()
        end
    end

    local function updateMenuIcon(open)
        if open then
            tweenObject(floatingButton, 0.12, { Rotation = 90 })
        else
            tweenObject(floatingButton, 0.12, { Rotation = 0 })
        end
    end

    floatingButton.MouseButton1Click:Connect(function()
        if topBarCanvas.Visible then
            api.hide()
            updateMenuIcon(false)
        else
            api.show()
            updateMenuIcon(true)
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        api.hide()
        updateMenuIcon(false)
    end)

    settingsBtn.MouseButton1Click:Connect(function()
        showToast("xFer", "Ajustes rápidos disponibles")
    end)

    local dragging = false
    local dragStart = nil
    local startPos = nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = topBarCanvas.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPos then
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                topBarCanvas.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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

    local defaultPage = buildPage("Overview")
    createTabButton("Overview", "◉")
    createTabButton("Character", "🏃")
    createTabButton("Combat", "⚔")
    createTabButton("Utility", "⚙")
    setPage("Overview")

    local mainTitle = makeText(defaultPage, "xFer Universal", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 26), Enum.Font.GothamBlack, 20, THEME.Text)
    local info = makeText(defaultPage, "Script universal con tabs, controles, auto-update y base para features plug-and-play.", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 46), Enum.Font.Gotham, 12, THEME.Muted, Enum.TextXAlignment.Left)
    info.TextWrapped = true

    local statusCard = make("Frame", {
        BackgroundColor3 = THEME.SurfaceLight,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 88),
        Size = UDim2.new(1, -24, 0, 120),
    }, defaultPage)
    addCorner(statusCard, 12)
    makeText(statusCard, "Estado", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 18), Enum.Font.GothamBold, 12, THEME.Text)
    makeText(statusCard, "Versión local: " .. VERSION, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Muted)
    makeText(statusCard, "Auto-update: activo", UDim2.fromOffset(14, 60), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Success)
    makeText(statusCard, "Configuración: xFerUniversal", UDim2.fromOffset(14, 82), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Muted)

    return api
end

local function registerBuiltins()
    NovaFeatures.register({
        id = "noclip",
        name = "Noclip",
        category = "Character",
        type = "toggle",
        description = "Atraviesa paredes",
        init = function(api)
            local enabled = false
            local parentsCache = {}
            local function apply()
                local character = localPlayer.Character
                if not character then return end
                for _, object in ipairs(character:GetDescendants()) do
                    if object:IsA("BasePart") then
                        if enabled then
                            object.CanCollide = false
                        else
                            if parentsCache[object] ~= nil then
                                object.CanCollide = parentsCache[object]
                            end
                        end
                    end
                end
            end

            api.addToggle({
                title = "Noclip",
                description = "Atraviesa paredes",
                value = false,
                onChanged = function(value)
                    enabled = value
                    safeCall(apply)
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "speed",
        name = "Speed",
        category = "Character",
        type = "slider",
        description = "Velocidad del personaje",
        init = function(api)
            local value = 16
            api.addSlider({
                title = "WalkSpeed",
                description = "Velocidad del jugador",
                min = 16,
                max = 200,
                value = value,
                onChanged = function(newValue)
                    value = newValue
                    safeCall(function()
                        local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum.WalkSpeed = newValue
                        end
                    end)
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "jump",
        name = "Jump",
        category = "Character",
        type = "slider",
        description = "Potencia del salto",
        init = function(api)
            local value = 50
            api.addSlider({
                title = "JumpPower",
                description = "Fuerza del salto",
                min = 50,
                max = 500,
                value = value,
                onChanged = function(newValue)
                    value = newValue
                    safeCall(function()
                        local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum.JumpPower = newValue
                        end
                    end)
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "fly",
        name = "Fly",
        category = "Character",
        type = "toggle",
        description = "Vuelo básico",
        init = function(api)
            local enabled = false
            local root = nil
            local velocity = nil
            local gyro = nil

            local function ensureParts()
                local character = localPlayer.Character
                if not character then return end
                root = character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                if not velocity then
                    velocity = make("BodyVelocity", { MaxForce = Vector3.new(5000,5000,5000), Velocity = Vector3.zero, P = 2000 }, root)
                end
                if not gyro then
                    gyro = make("BodyGyro", { MaxTorque = Vector3.new(50000,50000,50000), CFrame = root.CFrame }, root)
                end
            end

            api.addToggle({
                title = "Fly",
                description = "Vuelo básico",
                value = false,
                onChanged = function(value)
                    enabled = value
                    safeCall(function()
                        local character = localPlayer.Character
                        if not character then return end
                        root = character:FindFirstChild("HumanoidRootPart")
                        if not root then return end
                        ensureParts()
                        if enabled then
                            velocity.Velocity = Vector3.new(0, 0, 0)
                            gyro.CFrame = CFrame.new(root.Position, root.Position + camera.CFrame.LookVector)
                        else
                            velocity.Velocity = Vector3.zero
                        end
                    end)
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "antiafk",
        name = "Anti-AFK",
        category = "Character",
        type = "toggle",
        description = "Evita inactividad",
        init = function(api)
            local enabled = false
            local conn = nil
            api.addToggle({
                title = "Anti-AFK",
                description = "Evita desconexión por AFK",
                value = false,
                onChanged = function(value)
                    enabled = value
                    if enabled then
                        if conn then conn:Disconnect() end
                        conn = localPlayer.Idled:Connect(function()
                            safeCall(function()
                                local virtualUser = game:GetService("VirtualUser")
                                virtualUser:CaptureController()
                                virtualUser:ClickButton2(Vector2.new())
                            end)
                        end)
                    elseif conn then
                        conn:Disconnect()
                        conn = nil
                    end
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "esp",
        name = "ESP",
        category = "Combat",
        type = "toggle",
        description = "Resaltar jugadores",
        init = function(api)
            local enabled = false
            local highlights = {}
            local function refresh()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= localPlayer then
                        local character = player.Character
                        if character then
                            if enabled and (not highlights[player]) then
                                local highlight = make("Highlight", {
                                    Adornee = character,
                                    FillColor = THEME.Danger,
                                    OutlineColor = Color3.new(1,1,1),
                                    FillTransparency = 0.4,
                                    OutlineTransparency = 0,
                                }, character)
                                highlights[player] = highlight
                            elseif (not enabled) and highlights[player] then
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
                    safeCall(refresh)
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "aimbot",
        name = "Aimbot",
        category = "Combat",
        type = "toggle",
        description = "Apuntar automáticamente",
        init = function(api)
            local enabled = false
            local conn = nil
            local function findTarget()
                local bestTarget = nil
                local bestDist = math.huge
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= localPlayer and player.Character then
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        local head = player.Character:FindFirstChild("Head")
                        if hum and hum.Health > 0 and head then
                            local dist = (head.Position - camera.CFrame.Position).Magnitude
                            if dist < bestDist then
                                bestDist = dist
                                bestTarget = player
                            end
                        end
                    end
                end
                return bestTarget
            end

            local function tick()
                if not enabled then return end
                local target = findTarget()
                if target and target.Character and target.Character:FindFirstChild("Head") then
                    local head = target.Character.Head
                    local lookAt = CFrame.new(camera.CFrame.Position, head.Position)
                    camera.CFrame = camera.CFrame:Lerp(lookAt, 0.18)
                end
            end

            api.addToggle({
                title = "Aimbot",
                description = "Apunta automáticamente",
                value = false,
                onChanged = function(value)
                    enabled = value
                    if enabled then
                        if conn then conn:Disconnect() end
                        conn = RunService.RenderStepped:Connect(tick)
                    elseif conn then
                        conn:Disconnect()
                        conn = nil
                    end
                end,
            })
        end,
    })

    NovaFeatures.register({
        id = "rejoin",
        name = "Rejoin",
        category = "Utility",
        type = "button",
        description = "Reintentara reconectar al servidor",
        init = function(api)
            api.addButton({
                title = "Rejoin",
                color = THEME.Danger,
                onClick = function()
                    safeCall(function()
                        local placeId = game.PlaceId
                        if placeId then
                            game:GetService("TeleportService"):Teleport(placeId, localPlayer)
                        end
                    end)
                end,
            })
        end,
    })
end

local function initializeFeatures(ui)
    local api = {
        addToggle = ui.addToggle,
        addSlider = ui.addSlider,
        addButton = ui.addButton,
        addTextBox = ui.addTextBox,
        showToast = ui.showToast,
        save = saveSettings,
        load = loadSettings,
    }

    for _, feature in ipairs(NovaFeatures.list) do
        if type(feature.init) == "function" then
            safeCall(feature.init, api)
        end
    end
end

local function main()
    local settings = loadSettings()

    if settings and settings.autoUpdate ~= nil then
        -- no-op
    end

    if CONFIG_DIR and not isfolder(CONFIG_DIR) then
        ensureConfigFolder()
    end

    local ui = createNovaUI({ title = "xFer Universal", theme = "dark_gold" })

    ui.addTab("Overview", function(page, api)
        makeText(page, "xFer Universal", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 26), Enum.Font.GothamBlack, 20, THEME.Text)
        local text = makeText(page, "Script universal con UI modular, auto-update y feature registry para Roblox.", UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 50), Enum.Font.Gotham, 12, THEME.Muted, Enum.TextXAlignment.Left)
        text.TextWrapped = true

        local card = make("Frame", {
            BackgroundColor3 = THEME.SurfaceLight,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 94),
            Size = UDim2.new(1, -24, 0, 120),
        }, page)
        addCorner(card, 12)
        makeText(card, "Estado", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 18), Enum.Font.GothamBold, 12, THEME.Text)
        makeText(card, "Versión local: " .. VERSION, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Muted)
        makeText(card, "Auto-update: activo", UDim2.fromOffset(14, 60), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Success)
        makeText(card, "Configuración: " .. CONFIG_DIR, UDim2.fromOffset(14, 82), UDim2.new(1, -28, 0, 18), Enum.Font.Gotham, 12, THEME.Muted)
    end)

    ui.addTab("Character", function(page, api)
        api.addToggle({ title = "Noclip", description = "Atraviesa paredes", value = false, onChanged = function(v) end })
        api.addSlider({ title = "WalkSpeed", description = "Velocidad", min = 16, max = 200, value = 16, onChanged = function(v) end })
        api.addSlider({ title = "JumpPower", description = "Salto", min = 50, max = 500, value = 50, onChanged = function(v) end })
        api.addToggle({ title = "Fly", description = "Vuelo", value = false, onChanged = function(v) end })
        api.addToggle({ title = "Anti-AFK", description = "Evita inactividad", value = false, onChanged = function(v) end })
    end)

    ui.addTab("Combat", function(page, api)
        api.addToggle({ title = "ESP", description = "Resaltar jugadores", value = false, onChanged = function(v) end })
        api.addToggle({ title = "Aimbot", description = "Apunta automáticamente", value = false, onChanged = function(v) end })
    end)

    ui.addTab("Utility", function(page, api)
        api.addButton({ title = "Server Browser", color = THEME.Accent, onClick = function() ui.showToast("Server Browser", "Funcionalidad en desarrollo") end })
        api.addButton({ title = "Rejoin", color = THEME.Danger, onClick = function() end })
    end)

    registerBuiltins()
    initializeFeatures(ui)

    ui.showToast("xFer Universal", "Cargado correctamente")
    return ui
end

local success, result = pcall(main)
if not success then
    log("error", "Fallo al iniciar xFer", result)
end

if CONFIG_DIR and typeof(isfolder) == "function" and not isfolder(CONFIG_DIR) then
    safeCall(function()
        if typeof(makefolder) == "function" then
            makefolder(CONFIG_DIR)
        end
    end)
end

safeCall(checkForUpdate)
