local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Config = require(script.Parent.Parent.config)
local Utils = require(script.Parent.Parent.utils)
local State = require(script.Parent.Parent.state)
local UI = require(script.Parent.Parent.ui)

local create = Utils.create
local tween = Utils.tween
local addCorner = Utils.addCorner
local addStroke = Utils.addStroke
local makeText = Utils.makeText
local addHover = Utils.addHover

local Gameplay = {}

local aimbotConnection, noclipConnection, speedConnection
local jumpPowerConnection, flyConnection, flyVelocity, flyGyro
local fovCircle, fovCircleConnection
local espUpdateConnection, espPlayerAddedConn, espPlayerRemovingConn
local mobileFlyRiseUntil = 0
local startFly, stopFly

local function setSpeedEnabled(state)
	State.settings.speedEnabled = state == true
	if State.settings.speedEnabled then
		if speedConnection then speedConnection:Disconnect() end
		speedConnection = RunService.Heartbeat:Connect(function()
			if not State.settings.speedEnabled then return end
			local char = State.player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.WalkSpeed ~= State.settings.speedValue then hum.WalkSpeed = State.settings.speedValue end
			end
		end)
	else
		if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
		local hum = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = State.settings.defaultSpeed or 16 end
	end
end

local function startJumpPower()
	if jumpPowerConnection then jumpPowerConnection:Disconnect(); jumpPowerConnection = nil end
	local currentHumanoid = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
	if currentHumanoid and State.jumpPowerOriginals[currentHumanoid] == nil then State.jumpPowerOriginals[currentHumanoid] = currentHumanoid.JumpPower end
	jumpPowerConnection = RunService.Heartbeat:Connect(function()
		if not State.settings.jumpEnabled then return end
		local hum = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			if State.jumpPowerOriginals[hum] == nil then State.jumpPowerOriginals[hum] = hum.JumpPower end
			if hum.JumpPower ~= State.settings.jumpValue then hum.JumpPower = State.settings.jumpValue end
		end
	end)
end

local function stopJumpPower()
	if jumpPowerConnection then jumpPowerConnection:Disconnect(); jumpPowerConnection = nil end
	local hum = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
	if hum and State.jumpPowerOriginals[hum] ~= nil then hum.JumpPower = State.jumpPowerOriginals[hum] end
end

stopFly = function()
	if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
	if flyVelocity then pcall(function() flyVelocity:Destroy() end); flyVelocity = nil end
	if flyGyro then pcall(function() flyGyro:Destroy() end); flyGyro = nil end
end

startFly = function()
	stopFly()
	local char = State.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		UI.showNotification("Fly", "El personaje todavía no está listo.")
		return false
	end
	flyVelocity = Instance.new("BodyVelocity")
	flyVelocity.Name = "NovaFlyVelocity"
	flyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
	flyVelocity.P = 15000
	flyVelocity.Velocity = Vector3.zero
	flyVelocity.Parent = root
	flyGyro = Instance.new("BodyGyro")
	flyGyro.Name = "NovaFlyGyro"
	flyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
	flyGyro.P = 10000
	flyGyro.CFrame = root.CFrame
	flyGyro.Parent = root
	flyConnection = RunService.RenderStepped:Connect(function()
		if not State.settings.flyEnabled or not flyVelocity or not flyVelocity.Parent then stopFly(); return end
		local currentChar = State.player.Character
		local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
		local currentHumanoid = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not currentRoot or not currentHumanoid or not cam then return end
		local move = currentHumanoid.MoveDirection
		local vertical = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = -1 end
		if os.clock() < mobileFlyRiseUntil and vertical == 0 then vertical = 1 end
		flyVelocity.Velocity = Vector3.new(move.X, 0, move.Z) * (State.settings.flySpeed or 60) + Vector3.new(0, vertical * (State.settings.flySpeed or 60), 0)
		flyGyro.CFrame = CFrame.lookAt(currentRoot.Position, currentRoot.Position + cam.CFrame.LookVector)
	end)
	return true
end

local function hasLineOfSight(target)
	if not State.settings.wallCheck then return true end
	if not target or not target.Character then return false end
	local hrp = target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local origin = workspace.CurrentCamera.CFrame.Position
	local direction = hrp.Position - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList = {}
	if State.player.Character then table.insert(ignoreList, State.player.Character) end
	table.insert(ignoreList, target.Character)
	params.FilterDescendantsInstances = ignoreList
	local result = workspace:Raycast(origin, direction, params)
	return result == nil
end

local function getPlayerTeamColor(target)
	if State.settings.friends[target] then return Color3.fromRGB(0, 255, 0) end
	if not State.settings.ignoreTeam then return State.settings.espEnemyColor end
	if State.player.Team and target.Team then
		if State.player.Team == target.Team then return State.settings.espTeamColor
		else return State.settings.teamColors[target.Team] or State.settings.espEnemyColor end
	end
	return State.settings.espEnemyColor
end

local function isInDistance(target)
	if not target or not target.Character then return false end
	local hrp = target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local distance = (hrp.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
	return State.settings.espShortRange and distance <= 150 or distance <= State.settings.espDistance
end

local function removeESP(target)
	if State.espObjects[target] then
		pcall(function()
			if State.espObjects[target].partHighlights then
				for _, hl in ipairs(State.espObjects[target].partHighlights) do
					if hl then hl:Destroy() end
				end
			end
			if State.espObjects[target].highlight then State.espObjects[target].highlight:Destroy() end
			if State.espObjects[target].billboard then State.espObjects[target].billboard:Destroy() end
		end)
		State.espObjects[target] = nil
	end
	if State.espConnections[target] then
		pcall(function() State.espConnections[target]:Disconnect() end)
		State.espConnections[target] = nil
	end
end

local function createESP(target)
	if target == State.player or not target.Character then return end
	if not isInDistance(target) then return end
	local char = target.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local humanoidTarget = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoidTarget or humanoidTarget.MaxHealth <= 0 then return end
	if State.espObjects[target] then removeESP(target) end
	local teamColor = getPlayerTeamColor(target)

	local partHighlights = {}
	if State.settings.espUseHighlight then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				local hl = Instance.new("Highlight")
				hl.Name = "xFER_ESP"
				hl.Adornee = part
				hl.FillColor = teamColor
				hl.OutlineColor = teamColor
				hl.FillTransparency = 0.5
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = part
				table.insert(partHighlights, hl)
			end
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "XFER_NAME"
	billboard.Adornee = hrp
	billboard.Size = UDim2.new(0, 140, 0, 43)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	billboard.MaxDistance = State.settings.espDistance + 500
	billboard.Parent = hrp

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 17)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = State.settings.espUseDisplayName and target.DisplayName or target.Name
	nameLabel.TextColor3 = teamColor
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Visible = State.settings.espShowName
	nameLabel.Parent = billboard

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistLabel"
	distLabel.Size = UDim2.new(1, 0, 0, 13)
	distLabel.Position = UDim2.fromOffset(0, 17)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = ""
	distLabel.TextColor3 = teamColor
	distLabel.TextStrokeTransparency = 0
	distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	distLabel.TextSize = 9
	distLabel.Font = Enum.Font.GothamMedium
	distLabel.Visible = State.settings.espShowDistance
	distLabel.Parent = billboard

	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBg"
	healthBg.Size = UDim2.new(0.72, 0, 0, 3)
	healthBg.Position = UDim2.new(0.14, 0, 1, -5)
	healthBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	healthBg.BorderSizePixel = 0
	healthBg.Visible = State.settings.espShowHealth
	healthBg.Parent = billboard
	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(1, 0)
	healthCorner.Parent = healthBg
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(math.clamp(humanoidTarget.Health / math.max(humanoidTarget.MaxHealth, 1), 0, 1), 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(80, 230, 110)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = healthFill

	State.espObjects[target] = {highlight = nil, partHighlights = partHighlights, billboard = billboard, target = target, distLabel = distLabel, nameLabel = nameLabel, healthBg = healthBg}

	if State.espConnections[target] then pcall(function() State.espConnections[target]:Disconnect() end) end
	State.espConnections[target] = target.CharacterAdded:Connect(function()
		task.wait(1)
		if State.settings.esp then createESP(target) end
	end)
end

local function updateAllESPColors()
	for target, espData in pairs(State.espObjects) do
		if espData.target then
			local teamColor = getPlayerTeamColor(espData.target)
			pcall(function()
				if espData.partHighlights then
					for _, hl in ipairs(espData.partHighlights) do
						if hl then
							hl.FillColor = teamColor
							hl.OutlineColor = teamColor
						end
					end
				end
				if espData.nameLabel then espData.nameLabel.TextColor3 = teamColor end
				if espData.distLabel then espData.distLabel.TextColor3 = teamColor end
			end)
		end
	end
end

local function toggleESP(enable)
	State.settings.esp = enable
	if enable then
		for _, target in pairs(Players:GetPlayers()) do
			if target ~= State.player then createESP(target) end
		end
		if espUpdateConnection then espUpdateConnection:Disconnect() end
		espUpdateConnection = RunService.Heartbeat:Connect(function()
			if not State.settings.esp then return end
			for target, espData in pairs(State.espObjects) do
				if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") or not isInDistance(target) then
					removeESP(target)
				else
					local hrp = target.Character.HumanoidRootPart
					local dist = (hrp.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
					if espData.distLabel then
						espData.distLabel.Text = string.format("[%d studs]", math.floor(dist))
						espData.distLabel.Visible = State.settings.espShowDistance
					end
					if espData.nameLabel then
						espData.nameLabel.Visible = State.settings.espShowName
						espData.nameLabel.Text = State.settings.espUseDisplayName and target.DisplayName or target.Name
					end
					if espData.healthBg then
						espData.healthBg.Visible = State.settings.espShowHealth
						local fill = espData.healthBg:FindFirstChild("HealthFill")
						local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
						if fill and hum then
							local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
							fill.Size = UDim2.new(ratio, 0, 1, 0)
							fill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 230, 110), ratio)
						end
					end
				end
			end
			for _, target in pairs(Players:GetPlayers()) do
				if target ~= State.player and not State.espObjects[target] and target.Character and isInDistance(target) then createESP(target) end
			end
		end)
	else
		if espUpdateConnection then espUpdateConnection:Disconnect() espUpdateConnection = nil end
		for target, _ in pairs(State.espObjects) do removeESP(target) end
	end
end
local function buildSettingsOverlay()
	local settingsOverlay = create("Frame", {Name = "SettingsOverlay", BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.05, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 50}, UI.window)
	addCorner(settingsOverlay, 20)
	create("Frame", {BackgroundColor3 = State.COLORS.Border, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 0, 1), ZIndex = 51}, settingsOverlay)

	makeText(settingsOverlay, "⚙️ Ajustes", UDim2.fromOffset(20, 0), UDim2.fromOffset(300, 50), 16, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 52

	local closeSettingsBtn = create("TextButton", {BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(1, -44, 0, 9), Size = UDim2.fromOffset(32, 32), Text = "✕", TextColor3 = State.COLORS.Danger, Font = Config.FONT_BOLD, TextSize = 14, ZIndex = 52}, settingsOverlay)
	addCorner(closeSettingsBtn, 8)
	addHover(closeSettingsBtn, State.COLORS.SurfaceLight, State.COLORS.Danger, State.COLORS)
	closeSettingsBtn.MouseButton1Click:Connect(function() settingsOverlay.Visible = false end)

	local settingsScroll = create("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = State.COLORS.Accent, ZIndex = 52}, settingsOverlay)
	create("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, settingsScroll)

	local y = 0
	local function sectionLabel(text)
		local l = makeText(settingsScroll, text, UDim2.fromOffset(6, y), UDim2.new(1, -12, 0, 18), 9, State.COLORS.Subtle, Config.FONT_BOLD)
		l.ZIndex = 53
		y = y + 22
	end

	sectionLabel("APARIENCIA")
	UI.makeToggle(settingsScroll, "Reducir transparencia", "Paneles más opacos", y, State.reduceTransparency, function(state)
		State.reduceTransparency = state
		for _, surface in ipairs(State.glassSurfaces) do
			if surface.Object.Parent then
				tween(surface.Object, 0.2, {BackgroundTransparency = State.reduceTransparency and surface.Reduced or surface.Normal})
			end
		end
	end)
	y = y + 60

	UI.makeToggle(settingsScroll, "Desactivar Desenfoque", "Quita el blur del menú", y, State.disableBlur, function(state)
		State.disableBlur = state
		UI.blur.Enabled = not state
		if state then UI.blur.Size = 0 end
	end)
	y = y + 60

	UI.makeToggle(settingsScroll, "Mostrar accesos rápidos", "La barra no abre ni cierra el menú", y, State.settings.floatingEnabled, function(state)
		State.settings.floatingEnabled = state
		UI.updateQuickBarVisual()
	end, "floatingEnabled")
	y = y + 60

	sectionLabel("BARRA DE ACCESO RÁPIDO")
	UI.makeSlider(settingsScroll, "Tamaño de accesos rápidos", 36, 72, State.settings.floatingSize or 56, y, function(v)
		State.settings.floatingSize = v
		UI.updateQuickBarVisual()
		State.persistConfig()
	end)
	y = y + 68
	local quickSettingOptions = {
		{"tp1", "Mostrar TP1"}, {"tp2", "Mostrar TP2"}, {"noclip", "Mostrar Noclip"},
		{"infjump", "Mostrar salto infinito"}, {"esp", "Mostrar ESP"}, {"speed", "Mostrar velocidad"},
		{"fly", "Mostrar vuelo"}, {"jump", "Mostrar salto"},
	}
	for _, option in ipairs(quickSettingOptions) do
		local key, label = option[1], option[2]
		local isSelected = false
		for _, currentKey in ipairs(State.settings.floatingQuick or {}) do if currentKey == key then isSelected = true break end end
		UI.makeToggle(settingsScroll, label, "Mostrar u ocultar este botón en la barra", y, isSelected, function(state)
			local nextList = {}
			for _, currentKey in ipairs(State.settings.floatingQuick or {}) do if currentKey ~= key then table.insert(nextList, currentKey) end end
			if state then table.insert(nextList, key) end
			State.settings.floatingQuick = nextList
			UI.updateQuickBarVisual()
			State.persistConfig()
		end)
		y = y + 60
	end

	UI.makeSlider(settingsScroll, "Escala de ventana (%)", 70, 125, math.floor(State.scaleFactor * 100), y, function(v)
		State.scaleFactor = v / 100
		UI.applyWindowSize()
		State.persistConfig()
	end)
	y = y + 68

	sectionLabel("PALETA DE COLORES")
	local palettePanel = UI.makeSurface(settingsScroll, "PalettePanel", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 80), 0.22, 0.06, 12)
	create("UIGridLayout", {CellSize = UDim2.new(0.2, -6, 0, 64), CellPadding = UDim2.new(0, 6, 0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center}, palettePanel)
	create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, palettePanel)
	for name, pal in pairs(Config.PALETTES) do
		local btn = create("TextButton", {BackgroundColor3 = pal.Accent, BorderSizePixel = 0, Text = name, TextColor3 = Color3.new(1,1,1), Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 15}, palettePanel)
		addCorner(btn, 8)
		btn.MouseButton1Click:Connect(function()
			State.applyPalette(name)
			UI.refreshColors()
			State.persistConfig()
			UI.showNotification("Paleta", name .. " aplicada.")
		end)
	end
	y = y + 90

	sectionLabel("CONFIGURACIONES GUARDADAS")
	local presetsPanel = UI.makeSurface(settingsScroll, "PresetsPanel", UDim2.new(0, 6, 0, y), UDim2.new(1, -18, 0, 260), 0.22, 0.06, 12)

	makeText(presetsPanel, "GUARDAR NUEVA CONFIGURACIÓN", UDim2.fromOffset(13, 10), UDim2.new(1, -26, 0, 18), 9, State.COLORS.AccentLight, Config.FONT_BOLD).ZIndex = 14

	local nameBox = create("TextBox", {Size = UDim2.new(1, -26, 0, 32), Position = UDim2.fromOffset(13, 32), BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "", PlaceholderText = "Nombre de configuración...", PlaceholderColor3 = State.COLORS.Subtle, TextColor3 = State.COLORS.Text, TextSize = 12, Font = Config.FONT, ClearTextOnFocus = false, ZIndex = 14, TextXAlignment = Enum.TextXAlignment.Left}, presetsPanel)
	addCorner(nameBox, 8)
	create("UIPadding", {PaddingLeft = UDim.new(0, 10)}, nameBox)

	local presetList = create("ScrollingFrame", {Size = UDim2.new(1, -26, 0, 100), Position = UDim2.fromOffset(13, 134), BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = State.COLORS.Accent, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 14}, presetsPanel)
	addCorner(presetList, 8)
	local presetLayout = create("UIListLayout", {Padding = UDim.new(0, 4)}, presetList)
	create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, presetList)

	local function refreshPresetList()
		for _, c in pairs(presetList:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local files = Utils.listPresets()
		for _, presetName in ipairs(files) do
			local row = create("Frame", {Size = UDim2.new(1, -8, 0, 28), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 15}, presetList)
			addCorner(row, 6)
			makeText(row, presetName, UDim2.fromOffset(8, 0), UDim2.new(0.5, -8, 1, 0), 11, State.COLORS.Text, Config.FONT_MEDIUM).ZIndex = 16
			local loadBtn = create("TextButton", {Size = UDim2.new(0.22, -4, 1, -8), Position = UDim2.new(0.5, 0, 0, 4), BackgroundColor3 = State.COLORS.Success, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Cargar", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 16}, row)
			addCorner(loadBtn, 5)
			loadBtn.MouseButton1Click:Connect(function()
				State.applyPreset(Utils.loadConfig(presetName))
				State.persistConfig()
				UI.showNotification("Cargado", "'" .. presetName .. "' aplicada.")
			end)
			local delBtn = create("TextButton", {Size = UDim2.new(0.22, -4, 1, -8), Position = UDim2.new(0.74, 0, 0, 4), BackgroundColor3 = State.COLORS.Danger, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Borrar", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 16}, row)
			addCorner(delBtn, 5)
			delBtn.MouseButton1Click:Connect(function()
				if typeof(delfile) == "function" then
					pcall(function() delfile(Config.PRESETS_FOLDER .. "/" .. presetName .. ".json") end)
					refreshPresetList()
					UI.showNotification("Borrado", "'" .. presetName .. "' eliminada.")
				end
			end)
		end
		presetList.CanvasSize = UDim2.new(0, 0, 0, presetLayout.AbsoluteContentSize.Y + 8)
	end

	local savePresetBtn = create("TextButton", {Size = UDim2.new(1, -26, 0, 32), Position = UDim2.fromOffset(13, 70), BackgroundColor3 = State.COLORS.Accent, BackgroundTransparency = 0.2, BorderSizePixel = 0, Text = "💾 Guardar configuración", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 12, ZIndex = 14}, presetsPanel)
	addCorner(savePresetBtn, 8)
	addHover(savePresetBtn, State.COLORS.Accent, State.COLORS.AccentLight, State.COLORS)
	savePresetBtn.MouseButton1Click:Connect(function()
		local name = nameBox.Text:gsub("[^%w_%-]", "")
		if name == "" then UI.showNotification("Error", "Ingresa un nombre válido.") return end
		Utils.saveConfig(State.getSettingsSnapshot(), name)
		UI.showNotification("Guardado", "Configuración '" .. name .. "' guardada.")
		refreshPresetList()
	end)

	refreshPresetList()

	local resetAllBtn = create("TextButton", {Size = UDim2.new(1, -26, 0, 34), Position = UDim2.fromOffset(13, 244), BackgroundColor3 = State.COLORS.Danger, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "♻️ Restablecer valores predeterminados", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, presetsPanel)
	addCorner(resetAllBtn, 8)
	addHover(resetAllBtn, State.COLORS.Danger, State.COLORS.Danger:Lerp(Color3.new(1,1,1), 0.15), State.COLORS)
	resetAllBtn.MouseButton1Click:Connect(function()
		State.applyPreset({})
		State.settings.fov = 120
		State.settings.smoothness = 5
		State.settings.wallCheck = true
		State.settings.ignoreTeam = true
		State.settings.aimbot = false
		State.settings.aimbotPart = "Head"
		State.settings.aimbot360 = false
		State.settings.aimbotShortRange = false
		State.settings.fovVisible = true
		State.settings.espDistance = 1000
		State.settings.espShortRange = false
		State.settings.espShowHealth = false
		State.settings.speedValue = 50
		State.settings.speedEnabled = false
		State.settings.noclip = false
		State.settings.infiniteJump = false
		State.settings.instaInteract = false
		State.settings.antiAfk = false
		State.settings.jumpEnabled = false
		State.settings.jumpValue = 50
		State.settings.flyEnabled = false
		State.settings.flySpeed = 60
		State.settings.floatingEnabled = true
		State.settings.floatingSize = 56
		State.settings.floatingOpacity = 0.95
		State.settings.floatingQuick = {"tp1", "tp2", "noclip", "infjump", "esp", "speed", "fly", "jump"}
		State.settings.fullbright = false
		State.settings.fullbrightValue = 2
		State.settings.watermarkEnabled = false
		State.settings.fpsHudEnabled = false
		State.settings.serverFilterMin = 1
		State.settings.serverFilterMax = 50
		State.settings.serverShowFull = true
		State.settings.remoteBlacklist = {}
		State.settings.espTeamColor = Color3.fromRGB(0, 255, 0)
		State.settings.espEnemyColor = Color3.fromRGB(255, 0, 0)
		State.settings.fovColor = Color3.fromRGB(255, 255, 255)
		State.reduceTransparency = false
		State.disableBlur = false
		State.scaleFactor = 1
		State.applyPalette("Default")
		UI.blur.Enabled = true
		UI.refreshColors()
		UI.applyWindowSize()
		UI.updateQuickBarVisual()
		State.persistConfig()
		UI.showNotification("Reset", "Valores predeterminados aplicados.")
	end)

	y = y + 270
	return settingsOverlay, y
end
function Gameplay.init()
	local pageTeleport = UI.createPage("teleport")
	UI.pageHeading(pageTeleport, "Teleport", "Guarda posiciones y teletranspórtate.")

	local yTp = 76
	UI.sectionHeader(pageTeleport, "SLOTS DE TELETRANSPORTE", yTp)
	yTp = yTp + 30

	local slotsPanel = UI.makeSurface(pageTeleport, "SlotsPanel", UDim2.fromOffset(6, yTp), UDim2.new(1, -18, 0, 200), 0.22, 0.06, 12)
	local slotButtons = {}
	for i = 1, 5 do
		local rowY = 12 + (i - 1) * 36
		local row = create("Frame", {BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(10, rowY), Size = UDim2.new(1, -20, 0, 30), ZIndex = 14}, slotsPanel)
		addCorner(row, 8)
		local numberLabel = makeText(row, "Slot " .. i, UDim2.fromOffset(10, 0), UDim2.fromOffset(60, 30), 11, State.COLORS.Text, Config.FONT_BOLD)
		numberLabel.ZIndex = 15
		local statusDot = create("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(70, 11), BackgroundColor3 = State.COLORS.Danger, BorderSizePixel = 0, ZIndex = 15}, row)
		addCorner(statusDot, 4)
		local saveBtn = create("TextButton", {Size = UDim2.new(0, 60, 1, -6), Position = UDim2.new(1, -134, 0, 3), BackgroundColor3 = State.COLORS.Blue, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Guardar", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 15}, row)
		addCorner(saveBtn, 6)
		local tpBtn = create("TextButton", {Size = UDim2.new(0, 60, 1, -6), Position = UDim2.new(1, -68, 0, 3), BackgroundColor3 = State.COLORS.Success, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "TP", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 15}, row)
		addCorner(tpBtn, 6)
		slotButtons[i] = {row = row, saveBtn = saveBtn, tpBtn = tpBtn, dot = statusDot}
		State.tpSlots[i] = nil

		local function updateSlotUI()
			local has = State.tpSlots[i] ~= nil
			statusDot.BackgroundColor3 = has and State.COLORS.Success or State.COLORS.Danger
			tpBtn.Text = has and "TP" or "Vacío"
			tpBtn.BackgroundColor3 = has and State.COLORS.Success or State.COLORS.Surface
		end
		updateSlotUI()

		saveBtn.MouseButton1Click:Connect(function()
			local char = State.player.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			State.tpSlots[i] = root.CFrame
			updateSlotUI()
			UI.refreshQuickButtons()
			UI.showNotification("Slot " .. i, "Posición guardada.")
		end)
		tpBtn.MouseButton1Click:Connect(function()
			local char = State.player.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if not hum or not root then return end
			if not State.tpSlots[i] then UI.showNotification("Slot " .. i, "Está vacío.") return end
			if hum.Health > 0 then
				root.CFrame = State.tpSlots[i]
				tween(row, 0.1, {BackgroundTransparency = 0.05})
				task.delay(0.15, function() tween(row, 0.3, {BackgroundTransparency = 0.4}) end)
			end
		end)
		UI.registerSearchWidget(row, "TP Slot " .. i, "Guardar/teleport a slot")
	end

	State.resetPositionsEvent.Event:Connect(function()
		for i = 1, 5 do
			State.tpSlots[i] = nil
			local sb = slotButtons[i]
			sb.dot.BackgroundColor3 = State.COLORS.Danger
			sb.tpBtn.Text = "Vacío"
			sb.tpBtn.BackgroundColor3 = State.COLORS.Surface
		end
		UI.refreshQuickButtons()
	end)

	yTp = yTp + 208
	local resetBtn = UI.makeSurface(pageTeleport, "ResetSlots", UDim2.fromOffset(6, yTp), UDim2.new(1, -18, 0, 40), 0.22, 0.06, 11)
	local resetSlotsBtn = create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "♻️ Resetear Slots", TextColor3 = State.COLORS.Warning, Font = Config.FONT_BOLD, TextSize = 12, ZIndex = 14}, resetBtn)
	resetSlotsBtn.MouseButton1Click:Connect(function() State.resetPositionsEvent:Fire() UI.showNotification("Slots", "Todos los slots reseteados.") end)
	UI.registerSearchWidget(resetBtn, "Resetear Slots", "Borra todas las posiciones guardadas")

	local pageMovement = UI.createPage("movement")
	UI.pageHeading(pageMovement, "Movimiento", "Controla el movimiento del personaje.")

	local yMov = 76
	UI.sectionHeader(pageMovement, "HABILIDADES", yMov)
	yMov = yMov + 30

	UI.makeToggle(pageMovement, "Noclip", "Atraviesa paredes", yMov, State.settings.noclip, function(state)
		State.settings.noclip = state
		if state then
			if noclipConnection then noclipConnection:Disconnect() end
			noclipConnection = RunService.Stepped:Connect(function()
				if State.character and State.settings.noclip then
					for _, part in pairs(State.character:GetDescendants()) do
						if part:IsA("BasePart") then
							if State.OriginalCanCollide[part] == nil then State.OriginalCanCollide[part] = part.CanCollide end
							part.CanCollide = false
						end
					end
				end
			end)
		else
			if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
			for part, wasCollidable in pairs(State.OriginalCanCollide) do
				if part and part.Parent then pcall(function() part.CanCollide = wasCollidable end) end
			end
			table.clear(State.OriginalCanCollide)
		end
	end, "noclip")
	yMov = yMov + 60

	UI.makeToggle(pageMovement, "Infinite Jump", "Salto infinito", yMov, State.settings.infiniteJump, function(state)
		State.settings.infiniteJump = state
	end, "infiniteJump")
	yMov = yMov + 60

	UI.makeToggle(pageMovement, "Insta Interact", "Prompts instantáneos", yMov, State.settings.instaInteract, function(state)
		State.settings.instaInteract = state
		if state then
			for _, descendant in ipairs(workspace:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					if not State.originalHoldDurations[descendant] then State.originalHoldDurations[descendant] = descendant.HoldDuration end
					descendant.HoldDuration = 0
				end
			end
		else
			for prompt, duration in pairs(State.originalHoldDurations) do
				if prompt and prompt.Parent then prompt.HoldDuration = duration end
			end
			table.clear(State.originalHoldDurations)
		end
	end, "instaInteract")
	yMov = yMov + 60
  UI.sectionHeader(pageMovement, "VELOCIDAD", yMov)
yMov = yMov + 30

UI.makeToggle(pageMovement, "Speed Hack", "Forzar velocidad personalizada", yMov, State.settings.speedEnabled, function(state)
	setSpeedEnabled(state)
end, "speed")
yMov = yMov + 60

UI.makeSlider(pageMovement, "Velocidad Walk", 16, 300, State.settings.speedValue, yMov, function(v)
	State.settings.speedValue = v
	if State.settings.speedEnabled then
		local char = State.player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = v end
		end
	end
	State.persistConfig()
end)
yMov = yMov + 68

UI.makeToggle(pageMovement, "Jump Power", "Forzar potencia de salto personalizada", yMov, State.settings.jumpEnabled, function(state)
	State.settings.jumpEnabled = state
	if state then startJumpPower() else stopJumpPower() end
end, "jump")
yMov = yMov + 60

UI.makeSlider(pageMovement, "Potencia de salto", 50, 300, State.settings.jumpValue, yMov, function(v)
	State.settings.jumpValue = v
	local hum = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
	if hum and State.settings.jumpEnabled then hum.JumpPower = v end
	State.persistConfig()
end)
yMov = yMov + 68

UI.sectionHeader(pageMovement, "VUELO", yMov)
yMov = yMov + 30

local flyJumpRequestConnection = UserInputService.JumpRequest:Connect(function()
	if State.settings and State.settings.flyEnabled then mobileFlyRiseUntil = os.clock() + 0.18 end
end)
State.registerCleanup(function() if flyJumpRequestConnection then flyJumpRequestConnection:Disconnect() end end)

UI.makeToggle(pageMovement, "Fly", "Vuelo con joystick y controles de teclado", yMov, State.settings.flyEnabled, function(state)
	State.settings.flyEnabled = state
	if state then startFly() else stopFly() end
end, "fly")
yMov = yMov + 60

UI.makeSlider(pageMovement, "Velocidad de vuelo", 20, 200, State.settings.flySpeed, yMov, function(v)
	State.settings.flySpeed = v
	State.persistConfig()
end)
yMov = yMov + 68

UI.sectionHeader(pageMovement, "PROMPTS", yMov)
yMov = yMov + 30

UI.makeInput(pageMovement, "Distancia Prompt (studs)", yMov, function(value)
	State.settings.globalPromptDistance = value
	if value then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				descendant.MaxActivationDistance = value
			end
		end
	end
end)

local jumpRequestConnection = UserInputService.JumpRequest:Connect(function()
	if State.settings.infiniteJump and State.humanoid then State.humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
State.registerCleanup(function() if jumpRequestConnection then jumpRequestConnection:Disconnect() end end)
local workspaceDescendantConnection = workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
		task.defer(function()
			if State.settings.globalPromptDistance then descendant.MaxActivationDistance = State.settings.globalPromptDistance end
			if State.settings.instaInteract then
				if not State.originalHoldDurations[descendant] then State.originalHoldDurations[descendant] = descendant.HoldDuration end
				descendant.HoldDuration = 0
			end
		end)
	end
end)
State.registerCleanup(function() if workspaceDescendantConnection then workspaceDescendantConnection:Disconnect() end end)

local pageCombat = UI.createPage("combat")
UI.pageHeading(pageCombat, "Combat", "Aimbot y ajustes de combate.")

local yCombat = 76
UI.sectionHeader(pageCombat, "AIMBOT", yCombat)
yCombat = yCombat + 30

UI.makeToggle(pageCombat, "Aimbot", "Activar aimbot", yCombat, State.settings.aimbot, function(state)
	State.settings.aimbot = state
	if state then
		if aimbotConnection then aimbotConnection:Disconnect() end
		aimbotConnection = RunService.RenderStepped:Connect(function()
			if not State.settings.aimbot then return end
			local camera = workspace.CurrentCamera
			if not camera then return end
			local target = State.settings.lockedTarget
			if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then
				local closest = nil
				local shortest = State.settings.aimbot360 and math.huge or State.settings.fov
				local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
				for _, t in pairs(Players:GetPlayers()) do
					if t ~= State.player and t.Character then
						local hum = t.Character:FindFirstChild("Humanoid")
						local hrp = t.Character:FindFirstChild("HumanoidRootPart")
						if hum and hum.Health > 0 and hrp then
							local skip = false
							if State.settings.ignoreTeam and State.player.Team and t.Team and State.player.Team == t.Team then skip = true end
							if State.settings.friends[t] then skip = true end
							if not skip then
								if not State.settings.aimbotShortRange or (hrp.Position - camera.CFrame.Position).Magnitude <= 200 then
									if hasLineOfSight(t) then
										local sp, onScreen = camera:WorldToViewportPoint(hrp.Position)
										if State.settings.aimbot360 or onScreen then
											local d = (screenCenter - Vector2.new(sp.X, sp.Y)).Magnitude
											if d < shortest then closest = t shortest = d end
										end
									end
								end
							end
						end
					end
				end
				target = closest
			else
				if not hasLineOfSight(target) then target = nil end
			end
			if target and target.Character then
				local part = target.Character:FindFirstChild(State.settings.aimbotPart) or target.Character:FindFirstChild("Head")
				if part then
					local smooth = math.max(0.05, (21 - State.settings.smoothness) / 20)
					local lookVector = (part.Position - camera.CFrame.Position).Unit
					local goal = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + lookVector)
					camera.CFrame = camera.CFrame:Lerp(goal, smooth)
				end
			end
		end)
	else
		if aimbotConnection then aimbotConnection:Disconnect() aimbotConnection = nil end
	end
end, "aimbot")
yCombat = yCombat + 60

UI.makeToggle(pageCombat, "Aimbot 360°", "Apunta en cualquier dirección", yCombat, State.settings.aimbot360, function(state) State.settings.aimbot360 = state end)
yCombat = yCombat + 60

UI.makeToggle(pageCombat, "Aimbot Corto", "Solo apunta a ≤200 studs", yCombat, State.settings.aimbotShortRange, function(state) State.settings.aimbotShortRange = state end)
yCombat = yCombat + 60

UI.makeToggle(pageCombat, "Wall Check", "No apunta a través de paredes", yCombat, State.settings.wallCheck, function(state) State.settings.wallCheck = state end)
yCombat = yCombat + 60

UI.makeToggle(pageCombat, "Ignorar Equipo", "No apunta a aliados", yCombat, State.settings.ignoreTeam, function(state) State.settings.ignoreTeam = state end)
yCombat = yCombat + 60

UI.makeToggle(pageCombat, "Mostrar FOV", "Círculo visual del rango", yCombat, State.settings.fovVisible, function(state) State.settings.fovVisible = state end)
yCombat = yCombat + 60
  	UI.sectionHeader(pageCombat, "PARÁMETROS", yCombat)
	yCombat = yCombat + 30

	fovCircle = nil
	if type(Drawing) == "table" and type(Drawing.new) == "function" then
		local ok, circle = pcall(function() return Drawing.new("Circle") end)
		if ok then
			fovCircle = circle
			pcall(function()
				fovCircle.Visible = false
				fovCircle.Thickness = 2
				fovCircle.NumSides = 64
				fovCircle.Filled = false
				fovCircle.Transparency = 1
			end)
		end
	end

	UI.makeSlider(pageCombat, "FOV", 50, 500, State.settings.fov, yCombat, function(v) State.settings.fov = v if fovCircle then pcall(function() fovCircle.Radius = v end) end State.persistConfig() end)
	yCombat = yCombat + 68

	UI.makeSlider(pageCombat, "Suavizado", 1, 20, State.settings.smoothness, yCombat, function(v) State.settings.smoothness = v State.persistConfig() end)
	yCombat = yCombat + 68

	UI.makeColorPicker(pageCombat, "Color del FOV", State.settings.fovColor, yCombat, function(c) State.settings.fovColor = c if fovCircle then pcall(function() fovCircle.Color = c end) end end)
	yCombat = yCombat + 190

	UI.sectionHeader(pageCombat, "PARTE DEL CUERPO", yCombat)
	yCombat = yCombat + 30

	local aimbotPartContainer = UI.makeSurface(pageCombat, "AimbotPartContainer", UDim2.fromOffset(6, yCombat), UDim2.new(1, -18, 0, 100), 0.22, 0.06, 11)
	local partButtons = {}
	create("UIGridLayout", {CellSize = UDim2.new(0.5, -5, 0, 32), CellPadding = UDim2.new(0, 5, 0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center}, aimbotPartContainer)
	create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, aimbotPartContainer)
	for _, partName in ipairs(Config.partsList) do
		local btn = create("TextButton", {BackgroundColor3 = State.settings.aimbotPart == partName and State.COLORS.Accent or State.COLORS.SurfaceLight, BackgroundTransparency = State.settings.aimbotPart == partName and 0.15 or 0.35, BorderSizePixel = 0, Text = Config.partsDisplay[partName], TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, aimbotPartContainer)
		addCorner(btn, 8)
		partButtons[partName] = btn
		btn.MouseButton1Click:Connect(function()
			State.settings.aimbotPart = partName
			for name, frame in pairs(partButtons) do
				local sel = name == partName
				tween(frame, 0.2, {BackgroundColor3 = sel and State.COLORS.Accent or State.COLORS.SurfaceLight, BackgroundTransparency = sel and 0.15 or 0.35})
			end
			State.persistConfig()
		end)
	end

	fovCircleConnection = RunService.RenderStepped:Connect(function()
		if not fovCircle then return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		pcall(function()
			fovCircle.Visible = State.settings.fovVisible and State.settings.aimbot and not State.settings.aimbot360
			fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
			fovCircle.Radius = State.settings.fov
			fovCircle.Color = State.settings.fovColor
		end)
	end)
	State.registerCleanup(function() if fovCircleConnection then fovCircleConnection:Disconnect() end end)

	local pageESP = UI.createPage("esp")
	UI.pageHeading(pageESP, "ESP", "Visualiza jugadores con resaltado.")

	local yEsp = 76
	UI.sectionHeader(pageESP, "GENERAL", yEsp)
	yEsp = yEsp + 30

	UI.makeToggle(pageESP, "ESP Activo", "Resaltar jugadores", yEsp, State.settings.esp, function(state) toggleESP(state) end, "esp")
	yEsp = yEsp + 60

	UI.makeToggle(pageESP, "ESP Corto", "Solo muestra a ≤150 studs", yEsp, State.settings.espShortRange, function(state)
		State.settings.espShortRange = state
		if State.settings.esp then toggleESP(false) toggleESP(true) end
	end)
	yEsp = yEsp + 60

	UI.makeSlider(pageESP, "Distancia ESP", 100, 2000, State.settings.espDistance, yEsp, function(v)
		State.settings.espDistance = v
		if State.settings.esp then toggleESP(false) toggleESP(true) end
		State.persistConfig()
	end)
	yEsp = yEsp + 68

	UI.makeToggle(pageESP, "Mostrar salud", "Barra de vida sobre el jugador", yEsp, State.settings.espShowHealth, function(state) State.settings.espShowHealth = state State.persistConfig() end, "espShowHealth")
	yEsp = yEsp + 60
	UI.makeToggle(pageESP, "Mostrar nombres", "Nombre del jugador", yEsp, State.settings.espShowName, function(state) State.settings.espShowName = state State.persistConfig() end, "espShowName")
	yEsp = yEsp + 60
	UI.makeToggle(pageESP, "Mostrar distancia", "Distancia en studs", yEsp, State.settings.espShowDistance, function(state) State.settings.espShowDistance = state State.persistConfig() end, "espShowDistance")
	yEsp = yEsp + 60
	UI.makeToggle(pageESP, "Usar DisplayName", "Alternar entre nombre visible y usuario", yEsp, State.settings.espUseDisplayName, function(state)
		State.settings.espUseDisplayName = state
		for _, data in pairs(State.espObjects) do
			if data.nameLabel then data.nameLabel.Text = state and data.target.DisplayName or data.target.Name end
		end
		State.persistConfig()
	end, "espUseDisplayName")
	yEsp = yEsp + 60
	UI.makeToggle(pageESP, "Usar Highlight", "Resaltado del personaje", yEsp, State.settings.espUseHighlight, function(state)
		State.settings.espUseHighlight = state
		if State.settings.esp then toggleESP(false); toggleESP(true) end
		State.persistConfig()
	end, "espUseHighlight")
	yEsp = yEsp + 60

	UI.sectionHeader(pageESP, "COLORES", yEsp)
	yEsp = yEsp + 30

	UI.makeColorPicker(pageESP, "Color Equipo", State.settings.espTeamColor, yEsp, function(c)
		State.settings.espTeamColor = c
		if State.settings.esp then updateAllESPColors() end
	end)
	yEsp = yEsp + 190

	UI.makeColorPicker(pageESP, "Color Enemigos", State.settings.espEnemyColor, yEsp, function(c)
		State.settings.espEnemyColor = c
		if State.settings.esp then updateAllESPColors() end
	end)
	yEsp = yEsp + 190

	UI.sectionHeader(pageESP, "VISUAL Y HUD", yEsp)
	yEsp = yEsp + 30
	UI.makeToggle(pageESP, "Fullbright", "Ajusta la iluminación local", yEsp, State.settings.fullbright, function(state)
		State.settings.fullbright = state
		UI.applyFullbright(state)
	end, "fullbright")
	yEsp = yEsp + 60
	UI.makeSlider(pageESP, "Brillo Fullbright", 1, 5, State.settings.fullbrightValue, yEsp, function(v)
		State.settings.fullbrightValue = v
		if State.settings.fullbright then UI.applyFullbright(true) end
		State.persistConfig()
	end)
	yEsp = yEsp + 68
	UI.makeToggle(pageESP, "Watermark", "Mostrar nombre y versión", yEsp, State.settings.watermarkEnabled, function(state)
		UI.setWatermarkEnabled(state)
	end, "watermark")
	yEsp = yEsp + 60
	UI.makeToggle(pageESP, "FPS + Ping HUD", "Estadísticas locales en vivo", yEsp, State.settings.fpsHudEnabled, function(state)
		UI.setFPSHudEnabled(state)
	end, "fpsHud")

	local pagePlayers = UI.createPage("players")
	UI.pageHeading(pagePlayers, "Jugadores", "Acciones por jugador.")

	local function createPlayerSelection(parent, titleText, y, onClick)
		local sectionFrame = create("Frame", {Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -18, 0, 158), BackgroundTransparency = 1, ZIndex = 103}, parent)
		makeText(sectionFrame, titleText, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 20), 11, State.COLORS.AccentLight, Config.FONT_BOLD).ZIndex = 104
		local searchBar = create("Frame", {Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 22), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.36, BorderSizePixel = 0, ZIndex = 104}, sectionFrame)
		addCorner(searchBar, 8)
		local searchBox = create("TextBox", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Buscar...", PlaceholderColor3 = State.COLORS.Subtle, TextColor3 = State.COLORS.Text, TextSize = 11, Font = Config.FONT, ZIndex = 105}, searchBar)
		local list = create("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 60), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.5, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = State.COLORS.Accent, ZIndex = 104}, sectionFrame)
		addCorner(list, 8)
		local layout = create("UIListLayout", {Padding = UDim.new(0, 4)}, list)
		create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, list)
		local function refresh()
			for _, c in pairs(list:GetChildren()) do
				if c:IsA("TextButton") then c:Destroy() end
			end
			local searchText = searchBox.Text:lower()
			for _, t in pairs(Players:GetPlayers()) do
				if t ~= State.player then
					if searchText == "" or t.DisplayName:lower():find(searchText, 1, true) or t.Name:lower():find(searchText, 1, true) then
						local b = create("TextButton", {Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = t.DisplayName .. " (@" .. t.Name .. ")", TextColor3 = State.COLORS.Text, Font = Config.FONT, TextSize = 11, ZIndex = 105}, list)
						addCorner(b, 6)
						b.MouseButton1Click:Connect(function() onClick(t) end)
					end
				end
			end
			list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
		end
		refresh()
		local playerAddedConnection = Players.PlayerAdded:Connect(refresh)
		local playerRemovingConnection = Players.PlayerRemoving:Connect(refresh)
		local searchTextConnection = searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)
		State.registerCleanup(function()
			if playerAddedConnection then playerAddedConnection:Disconnect() end
			if playerRemovingConnection then playerRemovingConnection:Disconnect() end
			if searchTextConnection then searchTextConnection:Disconnect() end
		end)
		return sectionFrame
	end

	local yPlayers = 76
	createPlayerSelection(pagePlayers, "TELEPORT A JUGADOR", yPlayers, function(target)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			if State.character and State.character:FindFirstChild("HumanoidRootPart") then
				State.character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
				UI.showNotification("Teleport", "Teletransportado a " .. target.DisplayName)
			end
		end
	end)
	yPlayers = yPlayers + 168

	createPlayerSelection(pagePlayers, "FIJAR AIMBOT", yPlayers, function(target)
		State.settings.lockedTarget = target
		UI.showNotification("Aimbot", "Objetivo fijado: " .. target.DisplayName)
	end)
	yPlayers = yPlayers + 168

	local unfixBtn = UI.makeSurface(pagePlayers, "Unfix", UDim2.fromOffset(6, yPlayers), UDim2.new(1, -18, 0, 40), 0.22, 0.06, 11)
	local unfixButton = create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "🔓 Desfijar Aimbot", TextColor3 = State.COLORS.Danger, Font = Config.FONT_BOLD, TextSize = 12, ZIndex = 14}, unfixBtn)
	unfixButton.MouseButton1Click:Connect(function() State.settings.lockedTarget = nil UI.showNotification("Aimbot", "Objetivo desfijado.") end)
	UI.registerSearchWidget(unfixBtn, "Desfijar Aimbot", "Libera el objetivo bloqueado")

	local settingsOverlay = buildSettingsOverlay()
	UI.settingsOverlay = settingsOverlay

	UI.settingsButton.MouseButton1Click:Connect(function()
		settingsOverlay.Visible = not settingsOverlay.Visible
	end)

	espPlayerAddedConn = Players.PlayerAdded:Connect(function(target)
		if State.settings.esp then
			task.wait(1)
			createESP(target)
		end
	end)
	espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(target)
		removeESP(target)
	end)
	State.registerCleanup(function()
		if espPlayerAddedConn then espPlayerAddedConn:Disconnect(); espPlayerAddedConn = nil end
		if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect(); espPlayerRemovingConn = nil end
		if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
		for part, wasCollidable in pairs(State.OriginalCanCollide) do if part and part.Parent then pcall(function() part.CanCollide = wasCollidable end) end end
		table.clear(State.OriginalCanCollide)
		if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
		local currentHumanoid = State.player.Character and State.player.Character:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			pcall(function() currentHumanoid.WalkSpeed = State.settings.defaultSpeed or 16 end)
			if State.jumpPowerOriginals[currentHumanoid] ~= nil then pcall(function() currentHumanoid.JumpPower = State.jumpPowerOriginals[currentHumanoid] end) end
		end
		if jumpPowerConnection then jumpPowerConnection:Disconnect(); jumpPowerConnection = nil end
		if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
		if flyVelocity then pcall(function() flyVelocity:Destroy() end); flyVelocity = nil end
		if flyGyro then pcall(function() flyGyro:Destroy() end); flyGyro = nil end
		if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
		if espUpdateConnection then espUpdateConnection:Disconnect(); espUpdateConnection = nil end
		for _, conn in pairs(State.espConnections) do if conn then pcall(function() conn:Disconnect() end) end end
		if fovCircle and fovCircle.Remove then pcall(function() fovCircle:Remove() end) end
		for _, loop in pairs(State.remotesAutoFireLoops) do
			if loop then loop.active = false end
		end
		table.clear(State.remotesAutoFireTasks)
		table.clear(State.remotesAutoFireLoops)
		if State.settings.fullbright then UI.applyFullbright(false) end
		for prompt, duration in pairs(State.originalHoldDurations) do if prompt and prompt.Parent then pcall(function() prompt.HoldDuration = duration end) end end
		table.clear(State.originalHoldDurations)
	end)

	UI.showNotification(Config.SCRIPT_NAME, Config.SCRIPT_SUBTITLE .. " cargado.")
	UI.setMenuOpen(true)
end

return Gameplay
