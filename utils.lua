local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.config)

local Utils = {}

function Utils.create(className, properties, parent)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do object[property] = value end
	object.Parent = parent
	return object
end

function Utils.tween(object, duration, properties, style, direction)
	local a = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), properties)
	a:Play()
	return a
end

function Utils.addCorner(object, radius)
	return Utils.create("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end

function Utils.addStroke(object, color, transparency, thickness, useGradient, colors)
	local stroke = Utils.create("UIStroke", {Color = color or colors.Border, Transparency = transparency or 0.5, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
	if useGradient and colors then
		Utils.create("UIGradient", {Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colors.Accent),
			ColorSequenceKeypoint.new(0.48, colors.Blue),
			ColorSequenceKeypoint.new(1, colors.AccentLight)
		}), Rotation = 35}, stroke)
	end
	return stroke
end

function Utils.makeText(parent, text, position, size, textSize, color, font, alignment)
	return Utils.create("TextLabel", {
		Active = false, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = position, Size = size, Font = font or Config.FONT, Text = text,
		TextColor3 = color or Color3.fromRGB(241, 243, 250), TextSize = textSize or 13,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = false
	}, parent)
end

function Utils.addHover(button, normalColor, hoverColor, colors)
	button.AutoButtonColor = false
	button.MouseEnter:Connect(function() Utils.tween(button, 0.18, {BackgroundColor3 = hoverColor or colors.SurfaceHover}) end)
	button.MouseLeave:Connect(function() Utils.tween(button, 0.2, {BackgroundColor3 = normalColor}) end)
end

function Utils.colorFromTable(t, fallback)
	if type(t) == "table" and t[1] and t[2] and t[3] then
		return Color3.new(t[1], t[2], t[3])
	end
	return fallback
end

function Utils.getObjectPath(object)
	local path = {}
	local current = object
	while current and current ~= game do
		table.insert(path, 1, current.Name)
		current = current.Parent
	end
	return table.concat(path, ".")
end

function Utils.getTabPosition(index)
	return 52 + (index - 1) * 42
end

function Utils.getWindowSize(scaleFactor)
	local factor = math.clamp(scaleFactor, 0.7, 1.25)
	return Vector2.new(Config.BASE_SIZE.X * factor, Config.BASE_SIZE.Y * factor)
end

function Utils.ensureFolder()
	if typeof(isfolder) ~= "function" then return end
	pcall(function()
		if not isfolder(Config.CONFIG_FOLDER) then makefolder(Config.CONFIG_FOLDER) end
		if not isfolder(Config.PRESETS_FOLDER) then makefolder(Config.PRESETS_FOLDER) end
	end)
end

function Utils.saveConfig(data, name)
	if typeof(writefile) ~= "function" then return end
	pcall(function()
		Utils.ensureFolder()
		local path = name and (Config.PRESETS_FOLDER .. "/" .. name .. ".json") or Config.CONFIG_FILE
		writefile(path, HttpService:JSONEncode(data))
	end)
end

function Utils.loadConfig(name)
	if typeof(readfile) ~= "function" then return {} end
	local ok, data = pcall(function()
		local path = name and (Config.PRESETS_FOLDER .. "/" .. name .. ".json") or Config.CONFIG_FILE
		if isfile(path) then return HttpService:JSONDecode(readfile(path)) end
		return nil
	end)
	if ok and type(data) == "table" then return data end
	return {}
end

function Utils.listPresets()
	if typeof(getfolder) ~= "function" and typeof(listfiles) ~= "function" then return {} end
	local results = {}
	pcall(function()
		local files
		if typeof(listfiles) == "function" then
			files = listfiles(Config.PRESETS_FOLDER)
		else
			files = getfolder(Config.PRESETS_FOLDER)
		end
		if files then
			for _, f in ipairs(files) do
				local name = tostring(f):match("([^/\\]+)%.json$")
				if name then table.insert(results, name) end
			end
		end
	end)
	return results
end

return Utils
