local Config = require(script.Parent.Parent.config)
local Utils = require(script.Parent.Parent.utils)
local State = require(script.Parent.Parent.state)
local UI = require(script.Parent.Parent.ui)

local create = Utils.create
local addCorner = Utils.addCorner
local makeText = Utils.makeText
local addHover = Utils.addHover

local Remotes = {}

local pageRemotes
local scanButton, diagnosticButton
local remotesSearchInput, remotesScroller

local function fireRemoteObject(obj, isRemote)
	if not obj or not obj.Parent then return false end
	if isRemote then
		if obj:IsA("RemoteEvent") then
			return pcall(function() obj:FireServer() end)
		elseif obj:IsA("RemoteFunction") then
			return pcall(function() obj:InvokeServer() end)
		end
	else
		return pcall(function() fireproximityprompt(obj) end)
	end
	return false
end

function Remotes.populate()
	for _, child in ipairs(remotesScroller:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	State.remotesHeight = 0
	local searchText = (State.currentSearchText or ""):lower()
	local filteredRemotes, filteredPrompts = {}, {}
	for idx, remote in ipairs(State.allRemotes) do
		if remote and remote.Parent and (searchText == "" or remote.Name:lower():find(searchText, 1, true)) then
			if not (State.settings.remoteBlacklist and State.settings.remoteBlacklist[remote.Name]) then
				table.insert(filteredRemotes, {remote = remote, originalIdx = idx})
			end
		end
	end
	for idx, prompt in ipairs(State.allPrompts) do
		if prompt and prompt.Parent then
			local name = prompt.ObjectText or prompt.Name
			if searchText == "" or name:lower():find(searchText, 1, true) then
				if not (State.settings.remoteBlacklist and State.settings.remoteBlacklist[prompt.Name]) then
					table.insert(filteredPrompts, {prompt = prompt, originalIdx = idx})
				end
			end
		end
	end
	local function makeItemSection(title, color, items, isRemote)
		if #items == 0 then return end
		local titleFrame = create("Frame", {Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, State.remotesHeight), BackgroundColor3 = color, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 13}, remotesScroller)
		addCorner(titleFrame, 8)
		makeText(titleFrame, title, UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 12, color, Config.FONT_BOLD).ZIndex = 14
		local fireAllBtn = create("TextButton", {Size = UDim2.fromOffset(84, 22), Position = UDim2.new(1, -90, 0, 4), BackgroundColor3 = State.COLORS.Success, BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "🔥 Fire All", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 15}, titleFrame)
		addCorner(fireAllBtn, 6)
		addHover(fireAllBtn, State.COLORS.Success, State.COLORS.Success:Lerp(Color3.new(1, 1, 1), 0.15), State.COLORS)
		fireAllBtn.Activated:Connect(function()
			local fired = 0
			for _, d in ipairs(items) do
				local o = isRemote and d.remote or d.prompt
				if o and o.Parent then
					local ok = fireRemoteObject(o, isRemote)
					if ok then fired = fired + 1 end
				end
			end
			UI.showNotification("Fire All", string.format("%d/%d ejecutados.", fired, #items))
		end)
		State.remotesHeight = State.remotesHeight + 36
		for _, data in ipairs(items) do
			local obj = isRemote and data.remote or data.prompt
			if obj and obj.Parent then
				local name = obj.Name
				local location = Utils.getObjectPath(obj)
				local className = obj.ClassName
				local uniqueKey = tostring(data.originalIdx) .. (isRemote and "_r" or "_p")
				local container = create("Frame", {Size = UDim2.new(1, -10, 0, 158), Position = UDim2.new(0, 5, 0, State.remotesHeight), BackgroundColor3 = State.COLORS.SurfaceHover, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 13}, remotesScroller)
				addCorner(container, 10)
				makeText(container, "Nombre: " .. name, UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 19), 11, State.COLORS.Text, Config.FONT_BOLD).ZIndex = 14
				makeText(container, className .. " · " .. location, UDim2.fromOffset(10, 27), UDim2.new(1, -20, 0, 18), 8, State.COLORS.Muted, Config.FONT).ZIndex = 14
				local fireBtn = create("TextButton", {Size = UDim2.new(0.48, -8, 0, 30), Position = UDim2.new(0, 5, 0, 55), BackgroundColor3 = State.COLORS.Success, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "🔥 FIRE", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, container)
				addCorner(fireBtn, 7)
				addHover(fireBtn, State.COLORS.Success, State.COLORS.Success:Lerp(Color3.new(1, 1, 1), 0.15), State.COLORS)
				fireBtn.Activated:Connect(function()
					local ok = fireRemoteObject(obj, isRemote)
					UI.showNotification(ok and "Ejecutado" or "Error", name)
				end)
				local autoBtn = create("TextButton", {Size = UDim2.new(0.48, -8, 0, 30), Position = UDim2.new(0.52, 0, 0, 55), BackgroundColor3 = State.COLORS.Warning, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "🔁 AUTO-FIRE", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, container)
				addCorner(autoBtn, 7)
				addHover(autoBtn, State.COLORS.Warning, State.COLORS.Warning:Lerp(Color3.new(1, 1, 1), 0.15), State.COLORS)
				autoBtn.Activated:Connect(function()
					local existing = State.remotesAutoFireLoops[uniqueKey]
					if existing and existing.active then
						existing.active = false
						State.remotesAutoFireTasks[uniqueKey] = nil
						State.remotesAutoFireLoops[uniqueKey] = nil
						autoBtn.Text = "🔁 AUTO-FIRE"
						autoBtn.BackgroundColor3 = State.COLORS.Warning
						return
					end
					local taskData = {object = obj, isRemote = isRemote, interval = 0.1, count = 0}
					State.remotesAutoFireTasks[uniqueKey] = taskData
					local loopData = {active = true}
					State.remotesAutoFireLoops[uniqueKey] = loopData
					autoBtn.Text = "⏹ STOP"
					autoBtn.BackgroundColor3 = State.COLORS.Danger
					task.spawn(function()
						while loopData.active do
							local current = State.remotesAutoFireTasks[uniqueKey]
							if not current or not current.object or not current.object.Parent then break end
							fireRemoteObject(current.object, current.isRemote)
							current.count = current.count + 1
							task.wait(current.interval)
						end
						loopData.active = false
						State.remotesAutoFireLoops[uniqueKey] = nil
						State.remotesAutoFireTasks[uniqueKey] = nil
					end)
				end)
				local copyPathButton = create("TextButton", {Size = UDim2.new(0.48, -8, 0, 26), Position = UDim2.new(0, 5, 0, 91), BackgroundColor3 = State.COLORS.Blue, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Copiar ruta", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, container)
				addCorner(copyPathButton, 7)
				addHover(copyPathButton, State.COLORS.Blue, State.COLORS.Blue:Lerp(Color3.new(1, 1, 1), 0.15), State.COLORS)
				copyPathButton.Activated:Connect(function()
					if typeof(setclipboard) == "function" then
						local ok = pcall(setclipboard, location)
						UI.showNotification(ok and "Ruta copiada" or "Ruta del objeto", location)
					else
						UI.showNotification("Ruta del objeto", location)
					end
				end)
				local blacklistButton = create("TextButton", {Size = UDim2.new(0.48, -8, 0, 26), Position = UDim2.new(0.52, 0, 0, 91), BackgroundColor3 = State.COLORS.Danger, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Ocultar", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, container)
				addCorner(blacklistButton, 7)
				addHover(blacklistButton, State.COLORS.Danger, State.COLORS.Danger:Lerp(Color3.new(1, 1, 1), 0.15), State.COLORS)
				blacklistButton.Activated:Connect(function()
					State.settings.remoteBlacklist = State.settings.remoteBlacklist or {}
					State.settings.remoteBlacklist[name] = true
					State.persistConfig()
					Remotes.populate()
				end)
				local intervalLabel = makeText(container, "Intervalo (s):", UDim2.fromOffset(10, 125), UDim2.fromOffset(80, 22), 10, State.COLORS.Muted, Config.FONT_BOLD)
				intervalLabel.ZIndex = 14
				local intervalBox = create("TextBox", {Size = UDim2.new(0.48, -8, 0, 22), Position = UDim2.new(0.52, 0, 0, 125), BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0, Text = "0.1", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ClearTextOnFocus = false, ZIndex = 14, TextXAlignment = Enum.TextXAlignment.Center}, container)
				addCorner(intervalBox, 6)
				intervalBox.FocusLost:Connect(function()
					local num = tonumber(intervalBox.Text)
					if num and num > 0 then
						local current = State.remotesAutoFireTasks[uniqueKey]
						if current then current.interval = num end
					else
						intervalBox.Text = "0.1"
					end
				end)
				State.remotesHeight = State.remotesHeight + 164
			end
		end
	end
	makeItemSection(string.format("📡 REMOTES (%d)", #filteredRemotes), State.COLORS.Blue, filteredRemotes, true)
	makeItemSection(string.format("🔨 PROMPTS (%d)", #filteredPrompts), State.COLORS.Warning, filteredPrompts, false)
	remotesScroller.CanvasSize = UDim2.new(0, 0, 0, State.remotesHeight + 10)
end

function Remotes.scanData()
	State.allRemotes, State.allPrompts = {}, {}
	scanButton.Text = "⏳ Buscando..."
	scanButton.Active = false
	local BLACKLIST = {"CoreGui", "ContentProvider", "SoundService", State.player.Name}
	local function findObjects(object)
		for _, blacklistedName in ipairs(BLACKLIST) do
			if object.Name == blacklistedName then return end
		end
		for _, child in ipairs(object:GetChildren()) do
			if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
				table.insert(State.allRemotes, child)
			elseif child:IsA("ProximityPrompt") then
				table.insert(State.allPrompts, child)
			end
			pcall(findObjects, child)
		end
	end
	local ok, err = pcall(findObjects, game)
	Remotes.populate()
	scanButton.Text = "🔄 Escanear"
	scanButton.Active = true
	if not ok then UI.showNotification("Escaneo parcial", tostring(err)) else UI.showNotification("Diagnóstico", tostring(#State.allRemotes) .. " remotos y " .. tostring(#State.allPrompts) .. " prompts encontrados.") end
end

function Remotes.init()
	pageRemotes = UI.createPage("remotes")
	UI.pageHeading(pageRemotes, "Remotes", "Inspección de remotos y prompts accesibles.")

	local remotesSearchBox = UI.makeSurface(pageRemotes, "SearchBox", UDim2.fromOffset(6, 76), UDim2.new(1, -18, 0, 40), 0.22, 0.06, 10)
	remotesSearchInput = create("TextBox", {Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 40, 0, 0), BackgroundTransparency = 1, PlaceholderText = "Buscar remote por nombre...", PlaceholderColor3 = State.COLORS.Subtle, Text = "", Font = Config.FONT, TextSize = 13, TextColor3 = State.COLORS.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14}, remotesSearchBox)
	makeText(remotesSearchBox, "🔍", UDim2.fromOffset(8, 0), UDim2.new(0, 30, 1, 0), 16, State.COLORS.Muted, Config.FONT_MEDIUM, Enum.TextXAlignment.Center).ZIndex = 14

	local remotesControl = UI.makeSurface(pageRemotes, "RemotesControl", UDim2.fromOffset(6, 124), UDim2.new(1, -18, 0, 44), 0.22, 0.06, 10)
	scanButton = create("TextButton", {Name = "ScanButton", BackgroundColor3 = State.COLORS.Blue, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 5), Size = UDim2.new(0.48, -12, 0, 34), Text = "🔄 Escanear", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 12, ZIndex = 14}, remotesControl)
	addCorner(scanButton, 8)
	addHover(scanButton, State.COLORS.Blue, State.COLORS.Blue:Lerp(Color3.new(1,1,1), 0.15), State.COLORS)
	UI.registerSearchWidget(scanButton, "Escanear Remotes", "Busca todos los remotes del juego")

	diagnosticButton = create("TextButton", {Name = "ReadOnlyDiagnosticsButton", BackgroundColor3 = State.COLORS.Blue, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(0.52, 0, 0, 5), Size = UDim2.new(0.48, -12, 0, 34), Text = "↩ Restaurar ocultos", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, remotesControl)
	addCorner(diagnosticButton, 8)
	addHover(diagnosticButton, State.COLORS.Blue, State.COLORS.Blue:Lerp(Color3.new(1,1,1), 0.15), State.COLORS)
	UI.registerSearchWidget(diagnosticButton, "Restaurar remotes ocultos", "Quita la lista de exclusión local")

	remotesScroller = create("ScrollingFrame", {Name = "RemotesScroller", Size = UDim2.new(1, -18, 1, -186), Position = UDim2.fromOffset(6, 176), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = State.COLORS.Accent, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 13}, pageRemotes)
	addCorner(remotesScroller, 12)

	scanButton.Activated:Connect(Remotes.scanData)
	diagnosticButton.Activated:Connect(function()
		State.settings.remoteBlacklist = {}
		State.persistConfig()
		Remotes.populate()
		UI.showNotification("Lista restaurada", "Los remotes y prompts ocultos vuelven a mostrarse.")
	end)
	remotesSearchInput:GetPropertyChangedSignal("Text"):Connect(function()
		State.currentSearchText = remotesSearchInput.Text:lower()
		Remotes.populate()
	end)
end

return Remotes
