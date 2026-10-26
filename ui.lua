local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(script.Parent.config)
local Utils = require(script.Parent.utils)
local State = require(script.Parent.state)

local UI = {}

local create = Utils.create
local tween = Utils.tween
local addCorner = Utils.addCorner
local addStroke = Utils.addStroke
local makeText = Utils.makeText
local addHover = Utils.addHover

UI.screenGui = create("ScreenGui", {Name = "xFerFusion", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100}, State.playerGui)

local previousGui = State.playerGui:FindFirstChild("xFerFusion")
if previousGui and previousGui ~= UI.screenGui then previousGui:Destroy() end
local previousBlur = Lighting:FindFirstChild("xFerFusionBlur")
if previousBlur then previousBlur:Destroy() end

UI.blur = create("BlurEffect", {Name = "xFerFusionBlur", Size = 0, Enabled = not State.disableBlur}, Lighting)

UI.shadow = create("Frame", {Name = "WindowShadow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 500), Visible = false, ZIndex = 9}, UI.screenGui)
addCorner(UI.shadow, 22)
UI.shadowScale = create("UIScale", {Scale = 1}, UI.shadow)

UI.window = create("CanvasGroup", {Name = "MainWindow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.12, BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 500), GroupTransparency = 1, Visible = false, ZIndex = 10}, UI.screenGui)
addCorner(UI.window, 20)
addStroke(UI.window, State.COLORS.Border, 0.25, 1.2, true, State.COLORS)
UI.windowScale = create("UIScale", {Scale = 1}, UI.window)

function UI.updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local viewport = cam.ViewportSize
	local size = Utils.getWindowSize(State.scaleFactor)
	local s = math.min(1, (viewport.X - 24) / size.X, (viewport.Y - 24) / size.Y)
	s = math.clamp(s, 0.35, 1)
	UI.windowScale.Scale = s
	UI.shadowScale.Scale = s
end

function UI.applyWindowSize()
	local size = Utils.getWindowSize(State.scaleFactor)
	tween(UI.window, 0.22, {Size = UDim2.fromOffset(size.X, size.Y)})
	tween(UI.shadow, 0.22, {Size = UDim2.fromOffset(size.X + 8, size.Y + 8)})
	UI.updateScale()
end

UI.header = create("Frame", {Name = "Header", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 68), ZIndex = 11}, UI.window)
UI.dragHandle = create("TextButton", {Name = "DragHandle", Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -240, 1, 0), Text = "", ZIndex = 12}, UI.header)

UI.logo = create("Frame", {Active = false, BackgroundColor3 = State.COLORS.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 15), Size = UDim2.fromOffset(38, 38), ZIndex = 13}, UI.dragHandle)
addCorner(UI.logo, 12)
UI.logoGradient = create("UIGradient", {Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, State.COLORS.Blue),
	ColorSequenceKeypoint.new(0.5, State.COLORS.Accent),
	ColorSequenceKeypoint.new(1, State.COLORS.AccentLight)
}), Rotation = 45}, UI.logo)
makeText(UI.logo, "X", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 19, Color3.fromRGB(255, 255, 255), Config.FONT_BOLD, Enum.TextXAlignment.Center).ZIndex = 14

makeText(UI.dragHandle, Config.SCRIPT_NAME, UDim2.fromOffset(70, 8), UDim2.fromOffset(220, 22), 15, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 13
makeText(UI.dragHandle, Config.SCRIPT_SUBTITLE, UDim2.fromOffset(71, 30), UDim2.fromOffset(220, 14), 9, State.COLORS.Muted, Config.FONT_MEDIUM).ZIndex = 13

UI.searchContainer = create("Frame", {Name = "GlobalSearch", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.new(1, -388, 0, 18), Size = UDim2.fromOffset(200, 32), ZIndex = 15}, UI.header)
addCorner(UI.searchContainer, 8)
addStroke(UI.searchContainer, State.COLORS.Border, 0.7, 1, false, State.COLORS)
makeText(UI.searchContainer, "🔍", UDim2.fromOffset(8, 0), UDim2.fromOffset(24, 32), 13, State.COLORS.Muted, Config.FONT_MEDIUM, Enum.TextXAlignment.Center).ZIndex = 16
UI.globalSearch = create("TextBox", {Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Buscar opción...", PlaceholderColor3 = State.COLORS.Subtle, TextColor3 = State.COLORS.Text, TextSize = 12, Font = Config.FONT, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, ClearTextOnFocus = false}, UI.searchContainer)

UI.settingsButton = create("TextButton", {Name = "SettingsButton", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(1, -180, 0, 18), Size = UDim2.fromOffset(32, 32), Text = "⚙️", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 16, ZIndex = 15}, UI.header)
addCorner(UI.settingsButton, 8)
addHover(UI.settingsButton, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)

UI.closeWindowBtn = create("TextButton", {Name = "CloseButton", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(1, -142, 0, 18), Size = UDim2.fromOffset(32, 32), Text = "✕", TextColor3 = State.COLORS.Danger, Font = Config.FONT_BOLD, TextSize = 14, ZIndex = 15}, UI.header)
addCorner(UI.closeWindowBtn, 8)
addHover(UI.closeWindowBtn, State.COLORS.SurfaceLight, State.COLORS.Danger, State.COLORS)
UI.closeWindowBtn.MouseButton1Click:Connect(function()
	if UI.setMenuOpen then UI.setMenuOpen(false) end
end)

create("Frame", {BackgroundColor3 = State.COLORS.Border, BackgroundTransparency = 0.68, BorderSizePixel = 0, Position = UDim2.new(0, 18, 0, 67), Size = UDim2.new(1, -36, 0, 1), ZIndex = 13}, UI.window)

UI.sidebar = create("Frame", {Name = "Sidebar", BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 78), Size = UDim2.new(0, 174, 1, -94), ZIndex = 11}, UI.window)
addCorner(UI.sidebar, 15)
addStroke(UI.sidebar, State.COLORS.Border, 0.75, 1, false, State.COLORS)
UI.registerSurface(UI.sidebar, 0.25, 0.07)
makeText(UI.sidebar, "NAVEGACIÓN", UDim2.fromOffset(16, 15), UDim2.new(1, -30, 0, 20), 9, State.COLORS.Subtle, Config.FONT_BOLD)

UI.activeIndicator = create("Frame", {BackgroundColor3 = State.COLORS.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 66), Size = UDim2.fromOffset(3, 20), ZIndex = 14}, UI.sidebar)
addCorner(UI.activeIndicator, 3)

for index, definition in ipairs(Config.navDefinitions) do
	local button = create("TextButton", {Name = definition.Key .. "Tab", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.85, BorderSizePixel = 0, Position = UDim2.fromOffset(12, Utils.getTabPosition(index)), Size = UDim2.new(1, -24, 0, 38), Text = "", ZIndex = 13}, UI.sidebar)
	addCorner(button, 10)
	addHover(button, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)
	local icon = create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 28, 1, 0), Font = Config.FONT_MEDIUM, Text = definition.Icon, TextColor3 = State.COLORS.Muted, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 14}, button)
	local label = create("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -52, 1, 0), Font = Config.FONT_MEDIUM, Text = definition.Title, TextColor3 = State.COLORS.Muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 14}, button)
	State.tabButtons[definition.Key] = {Button = button, Icon = icon, Label = label, Index = index}
end

UI.userCard = create("Frame", {Name = "UserCard", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.new(0, 11, 1, -57), Size = UDim2.new(1, -22, 0, 44), ZIndex = 12}, UI.sidebar)
addCorner(UI.userCard, 11)
UI.userAvatar = create("Frame", {Active = false, BackgroundColor3 = State.COLORS.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(30, 30), ZIndex = 13}, UI.userCard)
addCorner(UI.userAvatar, 9)
makeText(UI.userAvatar, "X", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12, Color3.new(1, 1, 1), Config.FONT_BOLD, Enum.TextXAlignment.Center).ZIndex = 14
makeText(UI.userCard, State.player.DisplayName, UDim2.fromOffset(44, 6), UDim2.new(1, -51, 0, 16), 10, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 13
makeText(UI.userCard, "Sesión local", UDim2.fromOffset(44, 22), UDim2.new(1, -51, 0, 13), 8, State.COLORS.Muted, Config.FONT).ZIndex = 13

UI.contentSurface = create("Frame", {Name = "ContentArea", BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.67, BorderSizePixel = 0, Position = UDim2.fromOffset(202, 78), Size = UDim2.new(1, -218, 1, -94), ZIndex = 11}, UI.window)
addCorner(UI.contentSurface, 15)
UI.registerSurface(UI.contentSurface, 0.67, 0.45)

function UI.registerSearchWidget(widget, title, desc)
	widget:SetAttribute("SearchTitle", title or "")
	widget:SetAttribute("SearchDesc", desc or "")
	table.insert(State.searchWidgets, widget)
end

function UI.registerSurface(object, normalTransparency, reducedTransparency)
	table.insert(State.glassSurfaces, {Object = object, Normal = normalTransparency, Reduced = reducedTransparency})
	object.BackgroundTransparency = State.reduceTransparency and reducedTransparency or normalTransparency
	return object
end

function UI.makeSurface(parent, name, position, size, transparency, reducedTransparency, radius)
	local surface = create("Frame", {Name = name or "Surface", BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = transparency or 0.15, BorderSizePixel = 0, Position = position, Size = size}, parent)
	addCorner(surface, radius or 14)
	UI.registerSurface(surface, transparency or 0.15, reducedTransparency or 0.04)
	return surface
end

function UI.createPage(key)
	local group = create("CanvasGroup", {Name = key .. "Page", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), GroupTransparency = 0, Visible = key == State.activePageKey, ZIndex = 12}, UI.contentSurface)
	local scrolling = create("ScrollingFrame", {Name = "ScrollContent", Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = State.COLORS.Accent, ScrollBarImageTransparency = 0.25, ZIndex = 12}, group)
	State.pageGroups[key] = {Group = group, Scroll = scrolling}
	return scrolling
end

function UI.sectionHeader(parent, text, y)
	local container = create("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -18, 0, 22), ZIndex = 13}, parent)
	local line = create("Frame", {BackgroundColor3 = State.COLORS.Accent, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(3, 12), ZIndex = 14}, container)
	addCorner(line, 2)
	makeText(container, text, UDim2.fromOffset(12, 0), UDim2.new(1, -12, 1, 0), 10, State.COLORS.Subtle, Config.FONT_BOLD).ZIndex = 14
	UI.registerSearchWidget(container, text, "")
	return container, 28
end

function UI.pageHeading(parent, title, subtitle)
	makeText(parent, title, UDim2.fromOffset(10, 10), UDim2.new(1, -24, 0, 31), 21, State.COLORS.Text, Config.FONT_BOLD)
	makeText(parent, subtitle, UDim2.fromOffset(11, 41), UDim2.new(1, -26, 0, 23), 10, State.COLORS.Muted, Config.FONT)
end

function UI.makeChip(parent, text, position, size, color)
	local chip = create("Frame", {BackgroundColor3 = color or State.COLORS.Accent, BackgroundTransparency = 0.83, BorderSizePixel = 0, Position = position, Size = size}, parent)
	addCorner(chip, 8)
	makeText(chip, text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 9, color or State.COLORS.AccentLight, Config.FONT_BOLD, Enum.TextXAlignment.Center)
	return chip
end

function UI.showNotification(title, description)
	State.notificationId = State.notificationId + 1
	local currentId = State.notificationId
	local existing = UI.screenGui:FindFirstChild("xFerToast")
	if existing then existing:Destroy() end
	local toast = create("CanvasGroup", {Name = "xFerToast", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 1, 80), Size = UDim2.fromOffset(340, 62), GroupTransparency = 1, ZIndex = 40}, UI.screenGui)
	addCorner(toast, 14)
	addStroke(toast, State.COLORS.Border, 0.45, 1, true, State.COLORS)
	local accent = create("Frame", {BackgroundColor3 = State.COLORS.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 16), Size = UDim2.fromOffset(4, 30), ZIndex = 41}, toast)
	addCorner(accent, 3)
	makeText(toast, title, UDim2.fromOffset(26, 10), UDim2.new(1, -40, 0, 21), 11, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 41
	makeText(toast, description, UDim2.fromOffset(26, 32), UDim2.new(1, -40, 0, 19), 9, State.COLORS.Muted, Config.FONT).ZIndex = 41
	tween(toast, 0.32, {Position = UDim2.new(0.5, 0, 1, -24), GroupTransparency = 0})
	task.delay(2.5, function()
		if State.notificationId ~= currentId or not toast.Parent then return end
		local hideAnimation = tween(toast, 0.25, {Position = UDim2.new(0.5, 0, 1, 60), GroupTransparency = 1})
		hideAnimation.Completed:Connect(function()
			if toast.Parent and State.notificationId == currentId then toast:Destroy() end
		end)
	end)
end

function UI.makeToggle(parent, title, subtitle, y, initial, callback, stateKey)
	local container = UI.makeSurface(parent, title .. "Toggle", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 52), 0.22, 0.06, 11)
	local btn = create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 14}, container)
	makeText(container, title, UDim2.fromOffset(14, 7), UDim2.new(1, -100, 0, 18), 12, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 15
	makeText(container, subtitle, UDim2.fromOffset(14, 26), UDim2.new(1, -100, 0, 16), 9, State.COLORS.Muted, Config.FONT).ZIndex = 15

	local track = create("Frame", {Active = false, BackgroundColor3 = initial and State.COLORS.Success or State.COLORS.Danger, BorderSizePixel = 0, Position = UDim2.new(1, -70, 0.5, -12), Size = UDim2.fromOffset(52, 24), ZIndex = 15}, container)
	addCorner(track, 12)
	local knob = create("Frame", {Active = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(initial and 30 or 3, 3), Size = UDim2.fromOffset(18, 18), ZIndex = 16}, track)
	addCorner(knob, 9)
	local stateLabel = makeText(track, initial and "ON" or "OFF", UDim2.fromOffset(3, 0), UDim2.new(1, -6, 1, 0), 9, Color3.new(1, 1, 1), Config.FONT_BOLD, Enum.TextXAlignment.Center)
	stateLabel.ZIndex = 16
	stateLabel.TextXAlignment = initial and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right

	local state = initial == true
	local function renderState()
		track.BackgroundColor3 = state and State.COLORS.Success or State.COLORS.Danger
		knob.Position = UDim2.fromOffset(state and 30 or 3, 3)
		stateLabel.Text = state and "ON" or "OFF"
		stateLabel.TextXAlignment = state and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	end
	local function setState(nextState, shouldSave, forceCallback)
		nextState = nextState == true
		if state == nextState and not forceCallback then
			UI.refreshQuickButtons()
			return true
		end
		local previousState = state
		state = nextState
		tween(track, 0.18, {BackgroundColor3 = state and State.COLORS.Success or State.COLORS.Danger})
		tween(knob, 0.18, {Position = UDim2.fromOffset(state and 30 or 3, 3)})
		stateLabel.Text = state and "ON" or "OFF"
		stateLabel.TextXAlignment = state and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		local ok, err = pcall(function() if callback then callback(state) end end)
		if not ok then
			state = previousState
			renderState()
			UI.showNotification("Error", title .. ": " .. tostring(err))
			UI.refreshQuickButtons()
			return false
		end
		if shouldSave ~= false then State.persistConfig() end
		UI.refreshQuickButtons()
		return true
	end
	btn.Activated:Connect(function() setState(not state, true) end)
	if stateKey then State.toggleControllers[stateKey] = function(nextState, forceCallback, shouldSave) return setState(nextState, shouldSave ~= false, forceCallback) end end
	UI.registerSearchWidget(container, title, subtitle)
	return container
end
function UI.makeSlider(parent, name, min, max, default, y, callback, step)
	local frame = UI.makeSurface(parent, name .. "Slider", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 60), 0.22, 0.06, 11)
	local valueLabel = makeText(frame, tostring(default), UDim2.new(1, -70, 0, 8), UDim2.fromOffset(60, 20), 12, State.COLORS.AccentLight, Config.FONT_BOLD, Enum.TextXAlignment.Right)
	valueLabel.ZIndex = 15
	local label = makeText(frame, name, UDim2.fromOffset(14, 8), UDim2.new(1, -80, 0, 20), 12, State.COLORS.Text, Config.FONT_BOLD)
	label.ZIndex = 15
	local sliderBg = create("Frame", {Size = UDim2.new(1, -28, 0, 16), Position = UDim2.fromOffset(14, 34), BackgroundColor3 = State.COLORS.Background, BorderSizePixel = 0, ZIndex = 15}, frame)
	addCorner(sliderBg, 8)
	local fill = create("Frame", {Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = State.COLORS.Accent, BorderSizePixel = 0, ZIndex = 16}, sliderBg)
	addCorner(fill, 8)
	local knob = create("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 17}, sliderBg)
	addCorner(knob, 7)
	local hitbox = create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 18}, sliderBg)
	local dragging = false
	local s = step or 1
	local function update(input)
		local relativeX = math.clamp(input.Position.X - sliderBg.AbsolutePosition.X, 0, sliderBg.AbsoluteSize.X)
		local pct = relativeX / sliderBg.AbsoluteSize.X
		local value = min + (max - min) * pct
		value = math.floor(value / s + 0.5) * s
		pct = (value - min) / (max - min)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		knob.Position = UDim2.new(pct, -7, 0.5, -7)
		valueLabel.Text = tostring(value)
		callback(value)
	end
	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input)
		end
	end)
	hitbox.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
	end)
	hitbox.InputEnded:Connect(function() dragging = false end)
	local sliderInputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	State.registerCleanup(function() if sliderInputEndedConnection then sliderInputEndedConnection:Disconnect() end end)
	UI.registerSearchWidget(frame, name, "")
	return frame
end

function UI.makeColorPicker(parent, name, currentColor, y, callback)
	local r = math.floor(currentColor.R * 255 + 0.5)
	local g = math.floor(currentColor.G * 255 + 0.5)
	local b = math.floor(currentColor.B * 255 + 0.5)
	local function applyRGB()
		local color = Color3.fromRGB(r, g, b)
		callback(color)
		State.persistConfig()
	end
	makeText(parent, name .. " · RGB", UDim2.new(0, 8, 0, y), UDim2.new(1, -20, 0, 20), 11, State.COLORS.AccentLight, Config.FONT_BOLD).ZIndex = 14
	UI.makeSlider(parent, name .. " R", 0, 255, r, y + 22, function(v) r = v; applyRGB() end)
	UI.makeSlider(parent, name .. " G", 0, 255, g, y + 84, function(v) g = v; applyRGB() end)
	UI.makeSlider(parent, name .. " B", 0, 255, b, y + 146, function(v) b = v; applyRGB() end)
end

function UI.makeButton(parent, title, subtitle, y, color, callback)
	local container = UI.makeSurface(parent, title .. "Btn", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 46), 0.22, 0.06, 11)
	local btn = create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 15}, container)
	makeText(container, title, UDim2.fromOffset(14, subtitle and 6 or 0), UDim2.new(1, -20, subtitle and 0.5 or 1, 0), 12, color or State.COLORS.Text, Config.FONT_BOLD).ZIndex = 16
	if subtitle then
		makeText(container, subtitle, UDim2.fromOffset(14, 24), UDim2.new(1, -20, 0, 18), 9, State.COLORS.Muted, Config.FONT).ZIndex = 16
	end
	btn.MouseButton1Click:Connect(function()
		tween(container, 0.1, {BackgroundTransparency = 0.05})
		task.wait(0.1)
		tween(container, 0.25, {BackgroundTransparency = 0.22})
		callback()
	end)
	UI.registerSearchWidget(container, title, subtitle or "")
	return container
end

function UI.makeInput(parent, placeholder, y, callback)
	local container = UI.makeSurface(parent, placeholder .. "Input", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 44), 0.22, 0.06, 11)
	local box = create("TextBox", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = State.COLORS.Subtle, TextColor3 = State.COLORS.Text, TextSize = 12, Font = Config.FONT, ZIndex = 15, TextXAlignment = Enum.TextXAlignment.Left}, container)
	box.FocusLost:Connect(function()
		local num = tonumber(box.Text)
		if num then callback(num)
		elseif box.Text == "" then callback(nil) end
	end)
	UI.registerSearchWidget(container, placeholder, "")
	return container
end

function UI.setActivePage(key)
	if State.activePageKey == key then return end
	local previousKey = State.activePageKey
	local previousGroup = State.pageGroups[previousKey].Group
	local nextGroup = State.pageGroups[key].Group
	State.activePageKey = key
	nextGroup.Visible = true
	nextGroup.GroupTransparency = 1
	nextGroup.Position = UDim2.fromOffset(12, 0)
	tween(nextGroup, 0.26, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
	local exitAnimation = tween(previousGroup, 0.2, {GroupTransparency = 1, Position = UDim2.fromOffset(-8, 0)})
	exitAnimation.Completed:Connect(function()
		if State.activePageKey ~= previousKey and previousGroup.Parent then
			previousGroup.Visible = false
			previousGroup.Position = UDim2.fromOffset(0, 0)
			previousGroup.GroupTransparency = 0
		end
	end)
	for tabKey, item in pairs(State.tabButtons) do
		local selected = tabKey == key
		tween(item.Button, 0.2, {BackgroundTransparency = selected and 0.15 or 0.85})
		tween(item.Label, 0.2, {TextColor3 = selected and State.COLORS.Text or State.COLORS.Muted})
		tween(item.Icon, 0.2, {TextColor3 = selected and State.COLORS.AccentLight or State.COLORS.Muted})
	end
	tween(UI.activeIndicator, 0.25, {Position = UDim2.fromOffset(7, Utils.getTabPosition(State.tabButtons[key].Index) + 9), Size = UDim2.fromOffset(3, 20)})
end

for key, item in pairs(State.tabButtons) do
	local targetKey = key
	item.Button.Activated:Connect(function() UI.setActivePage(targetKey) end)
end
for key, item in pairs(State.tabButtons) do
	local selected = key == State.activePageKey
	item.Button.BackgroundTransparency = selected and 0.15 or 0.85
	item.Label.TextColor3 = selected and State.COLORS.Text or State.COLORS.Muted
	item.Icon.TextColor3 = selected and State.COLORS.AccentLight or State.COLORS.Muted
end
tween(UI.activeIndicator, 0, {Position = UDim2.fromOffset(7, Utils.getTabPosition(State.tabButtons[State.activePageKey].Index) + 9)})

function UI.refreshColors()
	UI.logo.BackgroundColor3 = State.COLORS.Accent
	if UI.logoGradient then UI.logoGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, State.COLORS.Blue),
		ColorSequenceKeypoint.new(0.5, State.COLORS.Accent),
		ColorSequenceKeypoint.new(1, State.COLORS.AccentLight)
	}) end
	UI.window.BackgroundColor3 = State.COLORS.Background
	UI.sidebar.BackgroundColor3 = State.COLORS.Surface
	UI.contentSurface.BackgroundColor3 = State.COLORS.Surface
	UI.activeIndicator.BackgroundColor3 = State.COLORS.Accent
	UI.userAvatar.BackgroundColor3 = State.COLORS.Accent
end

UI.floatingButton = create("TextButton", {Name = "FloatingMenuButton", AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.05, BorderSizePixel = 0, Position = UDim2.new(0, 23, 0.5, 0), Size = UDim2.fromOffset(56, 56), Text = "", AutoButtonColor = false, ZIndex = 30}, UI.screenGui)
addCorner(UI.floatingButton, 18)
addStroke(UI.floatingButton, State.COLORS.Border, 0.2, 1.25, true, State.COLORS)
UI.floatingScale = create("UIScale", {Scale = 1}, UI.floatingButton)
UI.barTop = create("Frame", {Active = false, BackgroundColor3 = State.COLORS.Text, BorderSizePixel = 0, Position = UDim2.new(0.5, -10, 0.5, -7), Size = UDim2.fromOffset(20, 2), ZIndex = 32}, UI.floatingButton)
UI.barMiddle = create("Frame", {Active = false, BackgroundColor3 = State.COLORS.Text, BorderSizePixel = 0, Position = UDim2.new(0.5, -10, 0.5, -1), Size = UDim2.fromOffset(20, 2), ZIndex = 32}, UI.floatingButton)
UI.barBottom = create("Frame", {Active = false, BackgroundColor3 = State.COLORS.Text, BorderSizePixel = 0, Position = UDim2.new(0.5, -10, 0.5, 5), Size = UDim2.fromOffset(20, 2), ZIndex = 32}, UI.floatingButton)
addCorner(UI.barTop, 2)
addCorner(UI.barMiddle, 2)
addCorner(UI.barBottom, 2)
addHover(UI.floatingButton, State.COLORS.Surface, State.COLORS.SurfaceHover, State.COLORS)

function UI.animateMenuIcon(open)
	if open then
		tween(UI.barTop, 0.25, {Position = UDim2.new(0.5, -10, 0.5, -1), Rotation = 45, Size = UDim2.fromOffset(20, 2)})
		tween(UI.barMiddle, 0.15, {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 2)})
		tween(UI.barBottom, 0.25, {Position = UDim2.new(0.5, -10, 0.5, -1), Rotation = -45, Size = UDim2.fromOffset(20, 2)})
	else
		tween(UI.barTop, 0.25, {Position = UDim2.new(0.5, -10, 0.5, -7), Rotation = 0, Size = UDim2.fromOffset(20, 2)})
		tween(UI.barMiddle, 0.22, {BackgroundTransparency = 0, Size = UDim2.fromOffset(20, 2)})
		tween(UI.barBottom, 0.25, {Position = UDim2.new(0.5, -10, 0.5, 5), Rotation = 0, Size = UDim2.fromOffset(20, 2)})
	end
	tween(UI.floatingScale, 0.16, {Scale = open and 0.96 or 1})
end

function UI.setMenuOpen(open)
	State.isOpen = open
	local size = Utils.getWindowSize(State.scaleFactor)
	if open then
		UI.updateScale()
		UI.window.Visible = true
		UI.shadow.Visible = true
		UI.window.Position = UDim2.fromScale(0.5, 0.5)
		UI.shadow.Position = UI.window.Position
		UI.window.Size = UDim2.fromOffset(size.X * 0.92, size.Y * 0.92)
		UI.shadow.Size = UI.window.Size
		UI.window.GroupTransparency = 1
		UI.shadow.BackgroundTransparency = 0.85
		tween(UI.window, 0.32, {Size = UDim2.fromOffset(size.X, size.Y), GroupTransparency = 0}, Enum.EasingStyle.Back)
		tween(UI.shadow, 0.32, {Size = UDim2.fromOffset(size.X + 8, size.Y + 8), BackgroundTransparency = 0.57})
		if not State.disableBlur then tween(UI.blur, 0.32, {Size = 16}) end
		UI.animateMenuIcon(true)
	else
		local closeAnimation = tween(UI.window, 0.22, {Size = UDim2.fromOffset(size.X * 0.94, size.Y * 0.94), GroupTransparency = 1})
		tween(UI.shadow, 0.2, {BackgroundTransparency = 1, Size = UDim2.fromOffset(size.X * 0.94, size.Y * 0.94)})
		tween(UI.blur, 0.24, {Size = 0})
		if UI.settingsOverlay then UI.settingsOverlay.Visible = false end
		UI.animateMenuIcon(false)
		closeAnimation.Completed:Connect(function()
			if not State.isOpen then
				UI.window.Visible = false
				UI.shadow.Visible = false
			end
		end)
	end
end
UI.floatingButton.Activated:Connect(function() UI.setMenuOpen(not State.isOpen) end)

UI.quickBar = create("Frame", {Name = "QuickActionBar", AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.12, BorderSizePixel = 0, Position = UDim2.new(1, -8, 0, 76), Size = UDim2.fromOffset(64, 16), Visible = State.settings.floatingEnabled, ZIndex = 35, Active = false}, UI.screenGui)
addCorner(UI.quickBar, 12)
addStroke(UI.quickBar, State.COLORS.Border, 0.25, 1, true, State.COLORS)
create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, UI.quickBar)
create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, UI.quickBar)

UI.quickButtons = {}

function UI.isQuickActive(key)
	if key == "tp1" then return State.tpSlots[1] ~= nil end
	if key == "tp2" then return State.tpSlots[2] ~= nil end
	if key == "noclip" then return State.settings.noclip == true end
	if key == "infjump" then return State.settings.infiniteJump == true end
	if key == "esp" then return State.settings.esp == true end
	if key == "speed" then return State.settings.speedEnabled == true end
	if key == "fly" then return State.settings.flyEnabled == true end
	if key == "jump" then return State.settings.jumpEnabled == true end
	return false
end

function UI.quickAction(key)
	if key == "tp1" or key == "tp2" then
		local index = tonumber(key:match("%d+")) or 1
		local saved = State.tpSlots[index]
		local root = State.player.Character and State.player.Character:FindFirstChild("HumanoidRootPart")
		if not saved then UI.showNotification("Slot " .. index, "Guarda una posición antes de usar este acceso."); return end
		if root then root.CFrame = saved; UI.showNotification("Teleport", "Posición del slot " .. index .. " aplicada.") end
		return
	end
	local controllerKey = ({infjump = "infiniteJump"})[key] or key
	local controller = State.toggleControllers[controllerKey]
	if controller then
		controller(not UI.isQuickActive(key))
	else
		UI.showNotification("Acceso no disponible", "No hay un controlador conectado para " .. tostring(key) .. ".")
	end
end

function UI.refreshQuickButtons()
	for key, button in pairs(UI.quickButtons) do
		if button and button.Parent then
			local active = UI.isQuickActive(key)
			button.BackgroundColor3 = active and State.COLORS.Success or (State.COLORS[Config.quickDefs[key].color] or State.COLORS.Accent)
			button.BackgroundTransparency = active and 0.04 or 0.2
			if key == "tp1" or key == "tp2" then
				button.Text = Config.quickDefs[key].label .. "\n" .. (active and "SAVED" or "EMPTY")
			else
				button.Text = Config.quickDefs[key].label .. "\n" .. (active and "ON" or "OFF")
			end
		end
	end
end

function UI.buildQuickBar()
	for _, button in pairs(UI.quickButtons) do if button and button.Parent then button:Destroy() end end
	table.clear(UI.quickButtons)
	local selected = {}
	for _, key in ipairs(type(State.settings.floatingQuick) == "table" and State.settings.floatingQuick or {}) do
		if Config.quickDefs[key] and not selected[key] then table.insert(selected, key); selected[key] = true end
	end
	if #selected == 0 then selected = {"tp1", "tp2", "noclip", "infjump", "esp", "speed", "fly", "jump"} end
	local rowHeight = math.clamp((State.settings.floatingSize or 56) - 22, 14, 50)
	local buttonWidth = math.clamp((State.settings.floatingSize or 56) - 8, 28, 64)
	for index, key in ipairs(selected) do
		local def = Config.quickDefs[key]
		local button = create("TextButton", {Name = "Quick_" .. key, BackgroundColor3 = State.COLORS[def.color] or State.COLORS.Accent, BackgroundTransparency = 0.18, BorderSizePixel = 0, Size = UDim2.fromOffset(buttonWidth, rowHeight), Text = def.label, TextColor3 = Color3.new(1, 1, 1), Font = Config.FONT_BOLD, TextSize = math.clamp(math.floor(rowHeight / 3.5), 8, 13), TextWrapped = true, AutoButtonColor = false, LayoutOrder = index, ZIndex = 36}, UI.quickBar)
		addCorner(button, 8)
		button.Activated:Connect(function() UI.quickAction(key) end)
		UI.quickButtons[key] = button
	end
	UI.quickBar.Size = UDim2.fromOffset(buttonWidth + 16, #selected * (rowHeight + 4) + 16)
	UI.quickBar.Visible = State.settings.floatingEnabled == true
	UI.refreshQuickButtons()
end

function UI.updateQuickBarVisual()
	if not UI.quickBar or not UI.quickBar.Parent then return end
	UI.quickBar.BackgroundTransparency = 1 - math.clamp(State.settings.floatingOpacity or 0.95, 0.3, 1)
	UI.quickBar.Visible = State.settings.floatingEnabled == true
	UI.buildQuickBar()
end

UI.buildQuickBar()

UI.watermark = create("Frame", {Name = "NovaWatermark", BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.12, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(174, 28), Visible = State.settings.watermarkEnabled == true, ZIndex = 24}, UI.screenGui)
addCorner(UI.watermark, 8)
addStroke(UI.watermark, State.COLORS.Border, 0.35, 1, true, State.COLORS)
makeText(UI.watermark, Config.SCRIPT_NAME .. " · V1.1", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), 10, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 25

UI.fpsHud = create("Frame", {Name = "NovaFpsHud", BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.18, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 46), Size = UDim2.fromOffset(146, 26), Visible = State.settings.fpsHudEnabled == true, ZIndex = 24}, UI.screenGui)
addCorner(UI.fpsHud, 8)
UI.fpsLabel = makeText(UI.fpsHud, "FPS: -- | Ping: --", UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0), 9, State.COLORS.Text, Config.FONT_BOLD, Enum.TextXAlignment.Center)
UI.fpsLabel.ZIndex = 25

UI.fpsConnection = nil
function UI.setFPSHudEnabled(state)
	State.settings.fpsHudEnabled = state == true
	if UI.fpsHud then UI.fpsHud.Visible = State.settings.fpsHudEnabled end
	if not State.settings.fpsHudEnabled then
		if UI.fpsConnection then UI.fpsConnection:Disconnect(); UI.fpsConnection = nil end
		return
	end
	if UI.fpsConnection or not UI.fpsLabel then return end
	local frames = 0
	local lastUpdate = os.clock()
	UI.fpsConnection = RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = os.clock()
		if now - lastUpdate >= 1 then
			local pingText = "--"
			local ok, ping = pcall(function() return math.floor(State.player:GetNetworkPing() * 1000) end)
			if ok and type(ping) == "number" then pingText = tostring(ping) end
			UI.fpsLabel.Text = string.format("FPS: %d | Ping: %s", frames, pingText)
			frames = 0
			lastUpdate = now
		end
	end)
end

function UI.setWatermarkEnabled(state)
	State.settings.watermarkEnabled = state == true
	if UI.watermark then UI.watermark.Visible = State.settings.watermarkEnabled end
end

function UI.applyFullbright(state)
	if state then
		if State.fullbrightOriginal.Ambient == nil then
			State.fullbrightOriginal.Ambient = Lighting.Ambient
			State.fullbrightOriginal.OutdoorAmbient = Lighting.OutdoorAmbient
			State.fullbrightOriginal.Brightness = Lighting.Brightness
			State.fullbrightOriginal.ClockTime = Lighting.ClockTime
			State.fullbrightOriginal.FogEnd = Lighting.FogEnd
		end
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
		Lighting.Brightness = State.settings.fullbrightValue or 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1000000
	else
		if State.fullbrightOriginal.Ambient ~= nil then
			Lighting.Ambient = State.fullbrightOriginal.Ambient
			Lighting.OutdoorAmbient = State.fullbrightOriginal.OutdoorAmbient
			Lighting.Brightness = State.fullbrightOriginal.Brightness
			Lighting.ClockTime = State.fullbrightOriginal.ClockTime
			Lighting.FogEnd = State.fullbrightOriginal.FogEnd
			table.clear(State.fullbrightOriginal)
		end
	end
end

function UI.performGlobalSearch(query)
	local q = query:lower()
	if q == "" then
		for _, w in ipairs(State.searchWidgets) do
			if w.Parent then w.Visible = true end
		end
		for _, data in pairs(State.pageGroups) do
			for _, child in pairs(data.Scroll:GetDescendants()) do
				if child:IsA("Frame") and child:GetAttribute("SearchTitle") == nil then
					child.Visible = true
				end
			end
		end
		return
	end
	for _, w in ipairs(State.searchWidgets) do
		if w.Parent then
			local title = (w:GetAttribute("SearchTitle") or ""):lower()
			local desc = (w:GetAttribute("SearchDesc") or ""):lower()
			local match = title:find(q, 1, true) or desc:find(q, 1, true)
			w.Visible = match and true or false
		end
	end
end
UI.globalSearch:GetPropertyChangedSignal("Text"):Connect(function()
	UI.performGlobalSearch(UI.globalSearch.Text)
end)

local dragging = false
local dragStart, startingPosition = nil, nil
UI.dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startingPosition = UI.window.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

local inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
	if not dragging or not dragStart or not startingPosition then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		local newPos = UDim2.new(startingPosition.X.Scale, startingPosition.X.Offset + delta.X, startingPosition.Y.Scale, startingPosition.Y.Offset + delta.Y)
		UI.window.Position = newPos
		UI.shadow.Position = newPos
	end
end)
State.registerCleanup(function() if inputChangedConnection then inputChangedConnection:Disconnect() end end)

local inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
State.registerCleanup(function() if inputEndedConnection then inputEndedConnection:Disconnect() end end)

local currentViewportConnection = nil
function UI.hookCamera(cam)
	if currentViewportConnection then currentViewportConnection:Disconnect(); currentViewportConnection = nil end
	State.camera = cam
	if not cam then return end
	currentViewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(UI.updateScale)
	UI.updateScale()
end
UI.hookCamera(Workspace.CurrentCamera)
local currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() UI.hookCamera(Workspace.CurrentCamera) end)
State.registerCleanup(function()
	if currentCameraConnection then currentCameraConnection:Disconnect(); currentCameraConnection = nil end
	if currentViewportConnection then currentViewportConnection:Disconnect(); currentViewportConnection = nil end
end)

State.registerCleanup(function()
	pcall(function() UI.screenGui:Destroy() end)
	pcall(function() UI.blur:Destroy() end)
end)

return UI
