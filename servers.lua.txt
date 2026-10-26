local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local Config = require(script.Parent.Parent.config)
local Utils = require(script.Parent.Parent.utils)
local State = require(script.Parent.Parent.state)
local UI = require(script.Parent.Parent.ui)

local create = Utils.create
local tween = Utils.tween
local addCorner = Utils.addCorner
local makeText = Utils.makeText
local addHover = Utils.addHover

local Servers = {}

local pageServers
local refreshButton, sortButton, antiAfkButton
local jobIdBox, joinJobButton, copyJobButton, rejoinButton
local serverMinBox, serverMaxBox, serverFullToggle
local prevPageBtn, nextPageBtn, pageLabel
local serverListFrame, serverListLayout, serverCanvasConnection

local antiAfkConnection = nil

local function getServers(placeId, cursor)
	local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", placeId)
	if cursor then url = url .. "&cursor=" .. cursor end
	local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
	return success and result or nil
end

local function sortServers()
	if State.currentSort == "ascending" then
		table.sort(State.allServersCache, function(a, b) return a.playing < b.playing end)
		sortButton.Text = "↑ Menor"
	else
		table.sort(State.allServersCache, function(a, b) return a.playing > b.playing end)
		sortButton.Text = "↓ Mayor"
	end
end

function Servers.renderServersPage()
	for _, child in pairs(serverListFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local filteredServers = {}
	local minPlayers = math.clamp(tonumber(State.settings.serverFilterMin) or 0, 0, 100)
	local maxPlayers = math.clamp(tonumber(State.settings.serverFilterMax) or 100, 0, 100)
	if minPlayers > maxPlayers then minPlayers, maxPlayers = maxPlayers, minPlayers end
	for _, server in ipairs(State.allServersCache) do
		local playing = tonumber(server.playing) or 0
		local capacity = tonumber(server.maxPlayers) or 0
		local isFull = capacity > 0 and playing >= capacity
		if playing >= minPlayers and playing <= maxPlayers and (State.settings.serverShowFull ~= false or not isFull) then
			table.insert(filteredServers, server)
		end
	end
	State.totalServerPages = math.max(1, math.ceil(#filteredServers / Config.SERVERS_PER_PAGE))
	if State.serverPage > State.totalServerPages then State.serverPage = State.totalServerPages end
	pageLabel.Text = string.format("Página %d/%d · %d", State.serverPage, State.totalServerPages, #filteredServers)
	local startIdx = (State.serverPage - 1) * Config.SERVERS_PER_PAGE + 1
	local endIdx = math.min(startIdx + Config.SERVERS_PER_PAGE - 1, #filteredServers)
	for i = startIdx, endIdx do
		local serverData = filteredServers[i]
		local Entry = create("Frame", {Name = "Entry_" .. i, Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = State.COLORS.SurfaceHover, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 13}, serverListFrame)
		addCorner(Entry, 9)
		makeText(Entry, string.format("%d/%d", serverData.playing, serverData.maxPlayers), UDim2.fromOffset(12, 0), UDim2.new(0, 70, 1, 0), 15, State.COLORS.Success, Config.FONT_BOLD)
		local infoText = "Jugadores"
		local infoColor = State.COLORS.Muted
		if serverData.playing == serverData.maxPlayers then infoText = "Servidor Lleno ⛔" infoColor = State.COLORS.Danger
		elseif serverData.maxPlayers < 10 then infoText = "Servidor Disponible" infoColor = State.COLORS.Warning end
		makeText(Entry, infoText, UDim2.fromOffset(12, 4), UDim2.new(1, -180, 0.45, 0), 10, infoColor, Config.FONT)
		makeText(Entry, "ID: " .. tostring(serverData.id):sub(1, 10), UDim2.fromOffset(12, 30), UDim2.new(1, -210, 0, 18), 8, State.COLORS.Muted, Config.FONT)
		local copyIdBtn = create("TextButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -122, 0.5, -15), BackgroundColor3 = State.COLORS.Surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "📋", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 14, ZIndex = 14}, Entry)
		addCorner(copyIdBtn, 6)
		copyIdBtn.MouseButton1Click:Connect(function()
			if typeof(setclipboard) == "function" then
				setclipboard(serverData.id)
				UI.showNotification("Copiado", "Job ID copiado al portapapeles.")
			end
		end)
		local JoinButton = create("TextButton", {Size = UDim2.new(0, 78, 0, 36), Position = UDim2.new(1, -86, 0.5, -18), Font = Config.FONT_BOLD, TextSize = 12, BorderSizePixel = 0, ZIndex = 14}, Entry)
		addCorner(JoinButton, 8)
		if serverData.playing == serverData.maxPlayers then
			JoinButton.BackgroundColor3 = State.COLORS.Danger
			JoinButton.Text = "Lleno"
			JoinButton.Active = false
			JoinButton.Selectable = false
			JoinButton.AutoButtonColor = false
			JoinButton.TextColor3 = Color3.fromRGB(220, 220, 220)
		else
			JoinButton.BackgroundColor3 = State.COLORS.Success
			JoinButton.Text = "Unirse"
			JoinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			JoinButton.MouseButton1Click:Connect(function()
				UI.showNotification("Teleport", "Teletransportando al servidor...")
				local ok, err = pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, serverData.id, State.player)
				end)
				if not ok then
					UI.showNotification("Error de teleport", tostring(err))
				end
			end)
		end
		addHover(JoinButton, JoinButton.BackgroundColor3, JoinButton.BackgroundColor3:Lerp(Color3.new(1,1,1), 0.15), State.COLORS)
	end
	serverListFrame.CanvasSize = UDim2.new(0, 0, 0, serverListLayout.AbsoluteContentSize.Y + 16)
end

function Servers.loadServers()
	for _, child in pairs(serverListFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	State.allServersCache = {}
	UI.showNotification("Cargando", "Obteniendo lista de servidores...")
	local cursor = nil
	local totalServers = 0
	for i = 1, 8 do
		if State.isCleaningUp or not UI.screenGui.Parent then break end
		local data = getServers(game.PlaceId, cursor)
		if State.isCleaningUp or not UI.screenGui.Parent then break end
		if not data or not data.data then break end
		for _, server in pairs(data.data) do
			if server.id ~= game.JobId then
				table.insert(State.allServersCache, server)
				totalServers = totalServers + 1
			end
		end
		if not data.nextPageCursor then break end
		cursor = data.nextPageCursor
		task.wait(0.05)
	end
	if #State.allServersCache > 0 then
		sortServers()
		State.serverPage = 1
		Servers.renderServersPage()
		UI.showNotification("Completado", string.format("%d servidores encontrados.", totalServers))
	else
		State.serverPage = 1
		Servers.renderServersPage()
		UI.showNotification("Aviso", "No se encontraron servidores o la consulta no está disponible en este entorno.")
	end
end

local function applyServerFilters()
	local minValue = tonumber(serverMinBox.Text) or 0
	local maxValue = tonumber(serverMaxBox.Text) or 100
	State.settings.serverFilterMin = math.clamp(math.floor(minValue), 0, 100)
	State.settings.serverFilterMax = math.clamp(math.floor(maxValue), 0, 100)
	if State.settings.serverFilterMin > State.settings.serverFilterMax then
		State.settings.serverFilterMin, State.settings.serverFilterMax = State.settings.serverFilterMax, State.settings.serverFilterMin
	end
	serverMinBox.Text = tostring(State.settings.serverFilterMin)
	serverMaxBox.Text = tostring(State.settings.serverFilterMax)
	State.serverPage = 1
	State.persistConfig()
	Servers.renderServersPage()
end

function Servers.setAntiAfkEnabled(state, notify)
	State.settings.antiAfk = state == true
	if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection = nil end
	if State.settings.antiAfk then
		antiAfkConnection = State.player.Idled:Connect(function()
			pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
		end)
	end
	if antiAfkButton then
		antiAfkButton.Text = State.settings.antiAfk and "💤 Anti-AFK ON" or "💤 Anti-AFK OFF"
		antiAfkButton.BackgroundColor3 = State.settings.antiAfk and State.COLORS.Success or State.COLORS.Danger
	end
	if notify then UI.showNotification("Anti-AFK", State.settings.antiAfk and "Activado." or "Desactivado.") end
end

function Servers.init()
	pageServers = UI.createPage("servers")
	UI.pageHeading(pageServers, "Servidores", "Explora, filtra y únete a servidores públicos.")

	local yServers = 76

	local serversControl = UI.makeSurface(pageServers, "ServersControl", UDim2.fromOffset(6, yServers), UDim2.new(1, -18, 0, 120), 0.22, 0.06, 12)

	refreshButton = create("TextButton", {Name = "RefreshButton", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.26, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0.32, -10, 0, 32), Text = "🔄 Refresh", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, serversControl)
	addCorner(refreshButton, 8)
	addHover(refreshButton, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)
	UI.registerSearchWidget(refreshButton, "Refresh Servidores", "Recargar lista de servidores")

	sortButton = create("TextButton", {Name = "SortButton", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.26, BorderSizePixel = 0, Position = UDim2.new(0.34, 0, 0, 8), Size = UDim2.new(0.32, -10, 0, 32), Text = "↑ Menor", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, serversControl)
	addCorner(sortButton, 8)
	addHover(sortButton, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)
	UI.registerSearchWidget(sortButton, "Ordenar Servidores", "Ordenar por cantidad de jugadores")

	antiAfkButton = create("TextButton", {Name = "AntiAfkButton", BackgroundColor3 = State.settings.antiAfk and State.COLORS.Success or State.COLORS.Danger, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.new(0.66, 0, 0, 8), Size = UDim2.new(0.32, -8, 0, 32), Text = State.settings.antiAfk and "💤 Anti-AFK ON" or "💤 Anti-AFK OFF", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, serversControl)
	addCorner(antiAfkButton, 8)
	addHover(antiAfkButton, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)
	UI.registerSearchWidget(antiAfkButton, "Anti-AFK", "Evita expulsión por inactividad")

	jobIdBox = create("TextBox", {Name = "JobIdBox", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.26, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 48), Size = UDim2.new(0.64, -10, 0, 32), Text = "", PlaceholderText = "Pegar Job ID...", PlaceholderColor3 = State.COLORS.Subtle, TextColor3 = State.COLORS.Text, Font = Config.FONT, TextSize = 10, ClearTextOnFocus = false, ZIndex = 14, TextXAlignment = Enum.TextXAlignment.Left}, serversControl)
	addCorner(jobIdBox, 8)
	create("UIPadding", {PaddingLeft = UDim.new(0, 10)}, jobIdBox)
	UI.registerSearchWidget(jobIdBox, "Job ID", "Unirse a servidor por Job ID")

	joinJobButton = create("TextButton", {Name = "JoinJobButton", BackgroundColor3 = State.COLORS.Accent, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.new(0.66, 0, 0, 48), Size = UDim2.new(0.32, -8, 0, 32), Text = "🎯 Join", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, serversControl)
	addCorner(joinJobButton, 8)
	addHover(joinJobButton, State.COLORS.Accent, State.COLORS.AccentLight, State.COLORS)
	UI.registerSearchWidget(joinJobButton, "Join ID", "Unirse al Job ID")

	copyJobButton = create("TextButton", {Name = "CopyJobButton", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.26, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, 86), Size = UDim2.new(0.32, -10, 0, 28), Text = "📋 Copy ID", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, serversControl)
	addCorner(copyJobButton, 8)
	addHover(copyJobButton, State.COLORS.SurfaceLight, State.COLORS.SurfaceHover, State.COLORS)
	UI.registerSearchWidget(copyJobButton, "Copiar Job ID", "Copiar el Job ID actual")

	rejoinButton = create("TextButton", {Name = "RejoinButton", BackgroundColor3 = State.COLORS.Warning, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(0.34, 0, 0, 86), Size = UDim2.new(0.32, -10, 0, 28), Text = "🔁 Rejoin", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, serversControl)
	addCorner(rejoinButton, 8)
	addHover(rejoinButton, State.COLORS.Warning, State.COLORS.Warning:Lerp(Color3.new(1,1,1), 0.15), State.COLORS)
	UI.registerSearchWidget(rejoinButton, "Rejoin", "Reconectar al mismo servidor")

	yServers = yServers + 128

	local serverFilterFrame = create("Frame", {Name = "ServerFilters", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(6, yServers), Size = UDim2.new(1, -18, 0, 34), ZIndex = 13}, pageServers)
	addCorner(serverFilterFrame, 9)
	serverMinBox = create("TextBox", {Name = "MinPlayers", BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 3), Size = UDim2.new(0.22, -6, 0, 28), Text = tostring(State.settings.serverFilterMin or 1), PlaceholderText = "Min", TextColor3 = State.COLORS.Text, PlaceholderColor3 = State.COLORS.Subtle, Font = Config.FONT, TextSize = 10, ClearTextOnFocus = false, ZIndex = 14}, serverFilterFrame)
	addCorner(serverMinBox, 6)
	serverMaxBox = create("TextBox", {Name = "MaxPlayers", BackgroundColor3 = State.COLORS.Background, BackgroundTransparency = 0.2, BorderSizePixel = 0, Position = UDim2.new(0.24, 0, 0, 3), Size = UDim2.new(0.22, -6, 0, 28), Text = tostring(State.settings.serverFilterMax or 50), PlaceholderText = "Max", TextColor3 = State.COLORS.Text, PlaceholderColor3 = State.COLORS.Subtle, Font = Config.FONT, TextSize = 10, ClearTextOnFocus = false, ZIndex = 14}, serverFilterFrame)
	addCorner(serverMaxBox, 6)
	serverFullToggle = create("TextButton", {Name = "ShowFullToggle", BackgroundColor3 = State.settings.serverShowFull and State.COLORS.Success or State.COLORS.Danger, BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.new(0.48, 0, 0, 3), Size = UDim2.new(0.5, -6, 0, 28), Text = State.settings.serverShowFull and "Llenos: sí" or "Llenos: no", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 10, ZIndex = 14}, serverFilterFrame)
	addCorner(serverFullToggle, 6)

	serverMinBox.FocusLost:Connect(applyServerFilters)
	serverMaxBox.FocusLost:Connect(applyServerFilters)
	serverFullToggle.Activated:Connect(function()
		State.settings.serverShowFull = not State.settings.serverShowFull
		serverFullToggle.Text = State.settings.serverShowFull and "Llenos: sí" or "Llenos: no"
		serverFullToggle.BackgroundColor3 = State.settings.serverShowFull and State.COLORS.Success or State.COLORS.Danger
		State.serverPage = 1
		State.persistConfig()
		Servers.renderServersPage()
	end)
	yServers = yServers + 42

	local pageNav = create("Frame", {Name = "PageNav", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, yServers), Size = UDim2.new(1, -18, 0, 32), ZIndex = 13}, pageServers)
	prevPageBtn = create("TextButton", {Size = UDim2.new(0.3, -6, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "◀ Anterior", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, pageNav)
	addCorner(prevPageBtn, 8)
	pageLabel = create("TextLabel", {Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.3, 0, 0, 0), BackgroundTransparency = 1, Text = "Página 1/1", TextColor3 = State.COLORS.Muted, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, pageNav)
	nextPageBtn = create("TextButton", {Size = UDim2.new(0.3, -6, 1, 0), Position = UDim2.new(0.7, 0, 0, 0), BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "Siguiente ▶", TextColor3 = State.COLORS.Text, Font = Config.FONT_BOLD, TextSize = 11, ZIndex = 14}, pageNav)
	addCorner(nextPageBtn, 8)

	yServers = yServers + 40
	serverListFrame = create("ScrollingFrame", {Name = "ServerList", BackgroundColor3 = State.COLORS.SurfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, Position = UDim2.fromOffset(6, yServers), Size = UDim2.new(1, -18, 1, -(yServers + 16)), CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 3, ScrollBarImageColor3 = State.COLORS.Accent, ZIndex = 13}, pageServers)
	addCorner(serverListFrame, 12)
	serverListLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, serverListFrame)
	create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, serverListFrame)
	serverCanvasConnection = serverListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if serverListFrame.Parent then
			serverListFrame.CanvasSize = UDim2.new(0, 0, 0, serverListLayout.AbsoluteContentSize.Y + 16)
		end
	end)
	State.registerCleanup(function() if serverCanvasConnection then serverCanvasConnection:Disconnect() end end)

	refreshButton.MouseButton1Click:Connect(Servers.loadServers)
	sortButton.MouseButton1Click:Connect(function()
		State.currentSort = State.currentSort == "ascending" and "descending" or "ascending"
		sortServers()
		State.serverPage = 1
		Servers.renderServersPage()
	end)
	prevPageBtn.MouseButton1Click:Connect(function()
		if State.serverPage > 1 then State.serverPage = State.serverPage - 1 Servers.renderServersPage() end
	end)
	nextPageBtn.MouseButton1Click:Connect(function()
		if State.serverPage < State.totalServerPages then State.serverPage = State.serverPage + 1 Servers.renderServersPage() end
	end)
	joinJobButton.MouseButton1Click:Connect(function()
		local id = jobIdBox.Text
		if id and #id > 0 then
			UI.showNotification("Teleport", "Uniendo a Job ID...")
			local ok, err = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, id, State.player)
			end)
			if not ok then
				UI.showNotification("Error de teleport", tostring(err))
			end
		end
	end)
	copyJobButton.MouseButton1Click:Connect(function()
		if typeof(setclipboard) == "function" then
			setclipboard(game.JobId)
			UI.showNotification("Copiado", "Job ID actual copiado.")
		end
	end)
	rejoinButton.MouseButton1Click:Connect(function()
		UI.showNotification("Rejoin", "Reconectando al servidor...")
		pcall(function() TeleportService:Teleport(game.PlaceId, State.player) end)
	end)
	antiAfkButton.Activated:Connect(function()
		Servers.setAntiAfkEnabled(not State.settings.antiAfk, true)
		State.persistConfig()
	end)

	State.registerCleanup(function()
		if antiAfkConnection then antiAfkConnection:Disconnect(); antiAfkConnection = nil end
		if serverCanvasConnection then serverCanvasConnection:Disconnect(); serverCanvasConnection = nil end
	end)

	Servers.setAntiAfkEnabled(State.settings.antiAfk, false)

	task.spawn(function()
		task.wait(0.5)
		if State.isCleaningUp or not UI.screenGui.Parent then return end
		Servers.loadServers()
	end)
end

return Servers
