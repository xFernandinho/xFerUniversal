local Config = require(script.Parent.config)
local Utils = require(script.Parent.utils)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local State = {}

State.player = Players.LocalPlayer
State.playerGui = State.player:WaitForChild("PlayerGui")
State.character = State.player.Character or State.player.CharacterAdded:Wait()
State.humanoid = State.character:WaitForChild("Humanoid")
State.camera = workspace.CurrentCamera

State.cleanupTasks = {}
State.isCleaningUp = false
State.toggleControllers = {}
State.jumpPowerOriginals = setmetatable({}, {__mode = "k"})
State.tpSlots = {nil, nil, nil, nil, nil}
State.espObjects = {}
State.espConnections = {}
State.originalHoldDurations = {}
State.OriginalCanCollide = {}
State.remotesAutoFireTasks = {}
State.remotesAutoFireLoops = {}
State.allServersCache = {}
State.allRemotes = {}
State.allPrompts = {}
State.searchWidgets = {}
State.glassSurfaces = {}
State.tabButtons = {}
State.pageGroups = {}

State.reduceTransparency = false
State.disableBlur = false
State.scaleFactor = 1
State.isOpen = false
State.activePageKey = "servers"
State.currentSort = "ascending"
State.serverPage = 1
State.totalServerPages = 1
State.currentSearchText = ""
State.remotesHeight = 0
State.notificationId = 0

State.settings = {
	aimbot = false, aimbotPart = "Head", aimbot360 = false, aimbotShortRange = false,
	fov = 120, fovVisible = true, fovColor = Color3.fromRGB(255, 255, 255),
	smoothness = 5, wallCheck = true, ignoreTeam = true, lockedTarget = nil,
	esp = false, espDistance = 1000, espShortRange = false, espShowHealth = false, espShowName = true, espShowDistance = true, espUseDisplayName = true, espUseHighlight = true,
	espTeamColor = Color3.fromRGB(0, 255, 0), espEnemyColor = Color3.fromRGB(255, 0, 0),
	friends = {}, teamColors = {},
	noclip = false, speedEnabled = false, speedValue = 50, defaultSpeed = 16,
	infiniteJump = false, instaInteract = false, jumpEnabled = false, jumpValue = 50,
	flyEnabled = false, flySpeed = 60,
	globalPromptDistance = nil, antiAfk = false, disableBlur = false,
	floatingEnabled = true, floatingSize = 56, floatingOpacity = 0.95,
	floatingQuick = {"tp1", "tp2", "noclip", "infjump", "esp", "speed", "fly", "jump"},
	fullbright = false, fullbrightValue = 2, watermarkEnabled = false, fpsHudEnabled = false,
	serverFilterMin = 1, serverFilterMax = 50, serverShowFull = true,
	remoteBlacklist = {}, scaleFactor = 1, palette = "Default",
}

State.COLORS = {}
for k, v in pairs(Config.PALETTES.Default) do State.COLORS[k] = v end
State.COLORS.Text = Color3.fromRGB(241, 243, 250)
State.COLORS.Muted = Color3.fromRGB(155, 162, 181)
State.COLORS.Subtle = Color3.fromRGB(105, 113, 134)

State.fullbrightOriginal = {}
State.resetPositionsEvent = Instance.new("BindableEvent")

function State.registerCleanup(fn)
	if type(fn) == "function" then table.insert(State.cleanupTasks, fn) end
end

function State.runCleanup()
	State.isCleaningUp = true
	local tasksToRun = State.cleanupTasks
	State.cleanupTasks = {}
	for i = #tasksToRun, 1, -1 do pcall(tasksToRun[i]) end
end

function State.applyPalette(name)
	local pal = Config.PALETTES[name] or Config.PALETTES.Default
	for k, v in pairs(pal) do State.COLORS[k] = v end
	State.settings.palette = name
end

function State.getSettingsSnapshot()
	return {
		fov = State.settings.fov, smoothness = State.settings.smoothness, wallCheck = State.settings.wallCheck,
		ignoreTeam = State.settings.ignoreTeam, aimbotPart = State.settings.aimbotPart, aimbot360 = State.settings.aimbot360,
		aimbotShortRange = State.settings.aimbotShortRange, fovVisible = State.settings.fovVisible,
		espDistance = State.settings.espDistance, espShortRange = State.settings.espShortRange, esp = State.settings.esp,
		espShowHealth = State.settings.espShowHealth, espShowName = State.settings.espShowName, espShowDistance = State.settings.espShowDistance, espUseDisplayName = State.settings.espUseDisplayName, espUseHighlight = State.settings.espUseHighlight,
		noclip = State.settings.noclip, infiniteJump = State.settings.infiniteJump, instaInteract = State.settings.instaInteract,
		globalPromptDistance = State.settings.globalPromptDistance, antiAfk = State.settings.antiAfk,
		speedValue = State.settings.speedValue, speedEnabled = State.settings.speedEnabled,
		jumpEnabled = State.settings.jumpEnabled, jumpValue = State.settings.jumpValue,
		flyEnabled = State.settings.flyEnabled, flySpeed = State.settings.flySpeed,
		floatingEnabled = State.settings.floatingEnabled, floatingSize = State.settings.floatingSize,
		floatingOpacity = State.settings.floatingOpacity, floatingQuick = State.settings.floatingQuick,
		fullbright = State.settings.fullbright, fullbrightValue = State.settings.fullbrightValue,
		watermarkEnabled = State.settings.watermarkEnabled, fpsHudEnabled = State.settings.fpsHudEnabled,
		serverFilterMin = State.settings.serverFilterMin, serverFilterMax = State.settings.serverFilterMax,
		serverShowFull = State.settings.serverShowFull, remoteBlacklist = State.settings.remoteBlacklist,
		reduceTransparency = State.reduceTransparency, disableBlur = State.disableBlur,
		scaleFactor = State.scaleFactor, palette = State.settings.palette,
		espTeamColor = {State.settings.espTeamColor.R, State.settings.espTeamColor.G, State.settings.espTeamColor.B},
		espEnemyColor = {State.settings.espEnemyColor.R, State.settings.espEnemyColor.G, State.settings.espEnemyColor.B},
		fovColor = {State.settings.fovColor.R, State.settings.fovColor.G, State.settings.fovColor.B},
	}
end

function State.persistConfig()
	Utils.saveConfig(State.getSettingsSnapshot())
end

local cachedConfig = Utils.loadConfig()
for k, v in pairs(cachedConfig) do
	if State.settings[k] ~= nil and type(State.settings[k]) == type(v) then
		State.settings[k] = v
	end
end
State.settings.espTeamColor = Utils.colorFromTable(cachedConfig.espTeamColor, State.settings.espTeamColor)
State.settings.espEnemyColor = Utils.colorFromTable(cachedConfig.espEnemyColor, State.settings.espEnemyColor)
State.settings.fovColor = Utils.colorFromTable(cachedConfig.fovColor, State.settings.fovColor)
if cachedConfig.reduceTransparency ~= nil then State.reduceTransparency = cachedConfig.reduceTransparency end
if cachedConfig.disableBlur ~= nil then State.disableBlur = cachedConfig.disableBlur end
if cachedConfig.scaleFactor then State.scaleFactor = cachedConfig.scaleFactor end
if cachedConfig.palette then State.applyPalette(cachedConfig.palette) end

function State.applyPreset(data)
	if type(data) ~= "table" then return end
	for k, v in pairs(data) do
		if State.settings[k] ~= nil and type(State.settings[k]) == type(v) then State.settings[k] = v end
	end
	State.settings.espTeamColor = Utils.colorFromTable(data.espTeamColor, State.settings.espTeamColor)
	State.settings.espEnemyColor = Utils.colorFromTable(data.espEnemyColor, State.settings.espEnemyColor)
	State.settings.fovColor = Utils.colorFromTable(data.fovColor, State.settings.fovColor)
	if data.reduceTransparency ~= nil then State.reduceTransparency = data.reduceTransparency end
	if data.disableBlur ~= nil then State.disableBlur = data.disableBlur end
	if data.scaleFactor then State.scaleFactor = data.scaleFactor end
	if data.palette then State.applyPalette(data.palette) end
end

State.characterAddedConnection = State.player.CharacterAdded:Connect(function(char)
	State.character = char
	State.humanoid = char:WaitForChild("Humanoid")
	task.wait(0.3)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if State.settings.speedEnabled and State.settings.speedValue then hum.WalkSpeed = State.settings.speedValue end
	if State.settings.jumpEnabled and State.settings.jumpValue then
		if State.jumpPowerOriginals[hum] == nil then State.jumpPowerOriginals[hum] = hum.JumpPower end
		hum.JumpPower = State.settings.jumpValue
	end
end)
State.registerCleanup(function() if State.characterAddedConnection then State.characterAddedConnection:Disconnect() end end)

return State
