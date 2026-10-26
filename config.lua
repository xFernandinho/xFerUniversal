local Config = {}

Config.SCRIPT_NAME = "xFer Fusion V1.1"
Config.SCRIPT_SUBTITLE = "Multi Tool Script"
Config.CONFIG_FOLDER = "xFerFusion"
Config.PRESETS_FOLDER = Config.CONFIG_FOLDER .. "/presets"
Config.CONFIG_FILE = Config.CONFIG_FOLDER .. "/config.json"
Config.BASE_SIZE = Vector2.new(760, 500)
Config.SERVERS_PER_PAGE = 10

Config.PALETTES = {
	Default = {
		Background = Color3.fromRGB(15, 17, 24),
		Surface = Color3.fromRGB(22, 25, 35),
		SurfaceLight = Color3.fromRGB(29, 33, 45),
		SurfaceHover = Color3.fromRGB(40, 45, 61),
		Border = Color3.fromRGB(75, 83, 108),
		Accent = Color3.fromRGB(139, 125, 255),
		AccentLight = Color3.fromRGB(180, 157, 255),
		Blue = Color3.fromRGB(105, 170, 255),
		Success = Color3.fromRGB(111, 221, 177),
		Warning = Color3.fromRGB(255, 195, 117),
		Danger = Color3.fromRGB(255, 105, 105),
	},
	Midnight = {
		Background = Color3.fromRGB(8, 10, 20),
		Surface = Color3.fromRGB(15, 18, 32),
		SurfaceLight = Color3.fromRGB(22, 27, 45),
		SurfaceHover = Color3.fromRGB(35, 42, 66),
		Border = Color3.fromRGB(60, 70, 100),
		Accent = Color3.fromRGB(80, 140, 255),
		AccentLight = Color3.fromRGB(130, 180, 255),
		Blue = Color3.fromRGB(80, 180, 255),
		Success = Color3.fromRGB(80, 220, 160),
		Warning = Color3.fromRGB(255, 200, 100),
		Danger = Color3.fromRGB(255, 90, 110),
	},
	Forest = {
		Background = Color3.fromRGB(12, 20, 15),
		Surface = Color3.fromRGB(20, 32, 25),
		SurfaceLight = Color3.fromRGB(28, 44, 34),
		SurfaceHover = Color3.fromRGB(40, 60, 48),
		Border = Color3.fromRGB(70, 100, 80),
		Accent = Color3.fromRGB(80, 200, 120),
		AccentLight = Color3.fromRGB(140, 230, 170),
		Blue = Color3.fromRGB(100, 200, 180),
		Success = Color3.fromRGB(120, 230, 150),
		Warning = Color3.fromRGB(240, 210, 120),
		Danger = Color3.fromRGB(230, 100, 90),
	},
	Crimson = {
		Background = Color3.fromRGB(20, 10, 12),
		Surface = Color3.fromRGB(32, 18, 22),
		SurfaceLight = Color3.fromRGB(45, 25, 30),
		SurfaceHover = Color3.fromRGB(62, 35, 42),
		Border = Color3.fromRGB(110, 60, 70),
		Accent = Color3.fromRGB(230, 70, 100),
		AccentLight = Color3.fromRGB(255, 130, 150),
		Blue = Color3.fromRGB(255, 120, 100),
		Success = Color3.fromRGB(200, 220, 120),
		Warning = Color3.fromRGB(255, 190, 100),
		Danger = Color3.fromRGB(255, 80, 80),
	},
	Ocean = {
		Background = Color3.fromRGB(10, 18, 24),
		Surface = Color3.fromRGB(18, 28, 38),
		SurfaceLight = Color3.fromRGB(26, 40, 54),
		SurfaceHover = Color3.fromRGB(38, 56, 74),
		Border = Color3.fromRGB(70, 100, 130),
		Accent = Color3.fromRGB(70, 180, 240),
		AccentLight = Color3.fromRGB(130, 210, 255),
		Blue = Color3.fromRGB(100, 200, 255),
		Success = Color3.fromRGB(110, 230, 200),
		Warning = Color3.fromRGB(255, 210, 130),
		Danger = Color3.fromRGB(255, 110, 130),
	},
}

Config.FONT = Enum.Font.Gotham
Config.FONT_MEDIUM = Enum.Font.GothamMedium
Config.FONT_BOLD = Enum.Font.GothamSemibold

Config.navDefinitions = {
	{Key = "servers", Title = "Servidores", Icon = "🌐"},
	{Key = "remotes", Title = "Remotes", Icon = "📡"},
	{Key = "teleport", Title = "Teleport", Icon = "🎯"},
	{Key = "movement", Title = "Movimiento", Icon = "🏃"},
	{Key = "combat", Title = "Combat", Icon = "⚔️"},
	{Key = "esp", Title = "ESP", Icon = "👁️"},
	{Key = "players", Title = "Jugadores", Icon = "👥"},
}

Config.partsList = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
Config.partsDisplay = {Head = "Cabeza", Torso = "Torso", LeftArm = "Brazo Izq", RightArm = "Brazo Der", LeftLeg = "Pierna Izq", RightLeg = "Pierna Der"}

Config.quickDefs = {
	tp1 = {label = "TP1", color = "Accent"},
	tp2 = {label = "TP2", color = "AccentLight"},
	noclip = {label = "NC", color = "Blue"},
	infjump = {label = "JUMP", color = "Success"},
	esp = {label = "ESP", color = "Warning"},
	speed = {label = "SPD", color = "Danger"},
	fly = {label = "FLY", color = "Blue"},
	jump = {label = "J+", color = "Success"},
}

return Config
