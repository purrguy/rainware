--[[
	RainWare Glass UI Library v3.0.0
	================================
	Liquid-glass blue theme with rain, puddles, Lucide icons, settings,
	a draggable window and a minimize pill.

	local RainWare = loadstring(game:HttpGet("https://raw.githubusercontent.com/purrguy/rainware/main/library_glass.lua"))()
	local win = RainWare:CreateWindow({
		Title = "RainWare",
		SubTitle = "Fisch",
		ToggleKey = Enum.KeyCode.RightShift,
		DefaultTab = "Autofarm",
	})
	local tab = win:CreateTab({ Title = "Autofarm", Icon = "droplet" })
	tab:CreateSection("Automation")
	tab:CreateToggle({ Title = "Auto Fish", Default = true, Flag = "af_auto" })
	tab:CreateSlider({ Title = "Power", Min = 0, Max = 100, Default = 95, Flag = "af_power" })
	tab:CreateDropdown({ Title = "Mode", Values = {"Slow", "Normal", "Instant"}, Default = "Normal", Flag = "af_mode" })
	tab:CreateButton({ Title = "Sell", Callback = function() end })
	RainWare:Notify({ Title = "RainWare", Content = "Loaded" })
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local RainWare = {}
RainWare.__index = RainWare
RainWare.Flags = {}
RainWare.Options = {}
RainWare.Version = "3.0.0"

-- Base64 PNG data for the logo and icon sheet is filled in at the bottom of this file.
local ASSET_DATA = {}

local SETTINGS_DIR = "RainWare"
local SETTINGS_FILE = SETTINGS_DIR .. "/settings.json"

local THEME = {
	white = Color3.fromRGB(255, 255, 255),
	panelTop = Color3.fromRGB(30, 84, 150),
	panelBottom = Color3.fromRGB(5, 18, 40),
	deep = Color3.fromRGB(4, 16, 34),
	card = Color3.fromRGB(22, 58, 104),
	edge = Color3.fromRGB(176, 222, 255),
	text = Color3.fromRGB(236, 246, 255),
	dim = Color3.fromRGB(150, 190, 230),
	faint = Color3.fromRGB(96, 138, 186),
	bad = Color3.fromRGB(255, 130, 140),
}

local PRESETS = {
	{ name = "Rain", a = Color3.fromRGB(72, 196, 240), b = Color3.fromRGB(38, 118, 230) },
	{ name = "Ice", a = Color3.fromRGB(150, 230, 255), b = Color3.fromRGB(70, 150, 236) },
	{ name = "Cobalt", a = Color3.fromRGB(120, 160, 255), b = Color3.fromRGB(52, 80, 222) },
	{ name = "Azure", a = Color3.fromRGB(86, 208, 255), b = Color3.fromRGB(28, 124, 226) },
	{ name = "Storm", a = Color3.fromRGB(150, 188, 236), b = Color3.fromRGB(62, 98, 156) },
}

local Settings = {
	ToggleKey = nil,
	Rain = true,
	Puddles = true,
	Performance = false,
	Accent = 1,
}

local ACC = { a = PRESETS[1].a, b = PRESETS[1].b }

----------------------------------------------------------------------------
-- Settings file
----------------------------------------------------------------------------

local function hasFiles()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureFolder()
	pcall(function()
		if type(makefolder) == "function" and not (type(isfolder) == "function" and isfolder(SETTINGS_DIR)) then
			makefolder(SETTINGS_DIR)
		end
	end)
end

local function loadSettings()
	if not hasFiles() then
		return
	end
	local ok, raw = pcall(function()
		if isfile(SETTINGS_FILE) then
			return readfile(SETTINGS_FILE)
		end
	end)
	if not ok or type(raw) ~= "string" then
		return
	end
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok2 or type(data) ~= "table" then
		return
	end
	if type(data.ToggleKey) == "string" then
		Settings.ToggleKey = data.ToggleKey
	end
	if type(data.Rain) == "boolean" then
		Settings.Rain = data.Rain
	end
	if type(data.Puddles) == "boolean" then
		Settings.Puddles = data.Puddles
	end
	if type(data.Performance) == "boolean" then
		Settings.Performance = data.Performance
	end
	if type(data.Accent) == "number" and PRESETS[data.Accent] then
		Settings.Accent = data.Accent
	end
	ACC.a = PRESETS[Settings.Accent].a
	ACC.b = PRESETS[Settings.Accent].b
end

local function saveSettings()
	if not hasFiles() then
		return
	end
	ensureFolder()
	pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings))
	end)
end

loadSettings()

----------------------------------------------------------------------------
-- Embedded image assets (base64 PNG -> executor workspace -> rbxasset URL)
----------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function decodeBase64(data)
	local map = {}
	for i = 1, 64 do
		map[string.byte(B64, i)] = i - 1
	end
	local out = {}
	local buffer, bits = 0, 0
	for i = 1, #data do
		local v = map[string.byte(data, i)]
		if v then
			buffer = buffer * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local byte = math.floor(buffer / 2 ^ bits)
				out[#out + 1] = string.char(byte % 256)
				buffer = buffer % 2 ^ bits
			end
		end
	end
	return table.concat(out)
end

local imageCache = {}

local function imageUrl(name)
	local cached = imageCache[name]
	if cached ~= nil then
		return cached or nil
	end
	imageCache[name] = false
	local getUrl = getcustomasset or getsynasset
	local b64 = ASSET_DATA[name]
	if not getUrl or not hasFiles() or type(b64) ~= "string" or #b64 < 100 then
		return nil
	end
	local path = SETTINGS_DIR .. "/" .. name .. "_v3.png"
	local ok, url = pcall(function()
		ensureFolder()
		if not isfile(path) then
			local bytes = decodeBase64(b64)
			if bytes:sub(2, 4) ~= "PNG" then
				error("invalid png data")
			end
			writefile(path, bytes)
		end
		return getUrl(path)
	end)
	if ok and type(url) == "string" then
		imageCache[name] = url
		return url
	end
	return nil
end

----------------------------------------------------------------------------
-- Instance helpers
----------------------------------------------------------------------------

local function new(class, props, parent)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or THEME.edge,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- UIGradient multiplies with BackgroundColor3, so gradient frames use a white base.
local function gradient(parent, c0, c1, rot, t0, t1)
	return new("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Transparency = NumberSequence.new(t0 or 0, t1 or t0 or 0),
		Rotation = rot or 90,
	}, parent)
end

local function fadeLine(parent, color, peak)
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, parent)
	new("UIGradient", {
		Color = ColorSequence.new(color, color),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, peak),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	return line
end

local function label(parent, text, font, size, color, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = font or Enum.Font.Gotham,
		TextSize = size or 13,
		TextColor3 = color or THEME.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text or "",
	}, parent)
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	return l
end

local function guiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	local ok2, pg = pcall(function()
		return LP:FindFirstChildOfClass("PlayerGui")
	end)
	if ok2 and pg then
		return pg
	end
	return CoreGui
end

local function viewportSize()
	local cam = workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function inRect(gui, p)
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end

local function toKeyCode(v)
	if typeof(v) == "EnumItem" then
		return v
	end
	if type(v) == "string" then
		local ok, key = pcall(function()
			return Enum.KeyCode[v]
		end)
		if ok then
			return key
		end
	end
	return nil
end

local function fmtNum(v, inc)
	inc = tonumber(inc) or 1
	if inc >= 1 then
		return tostring(math.floor(v + 0.5))
	end
	local places = 2
	if inc >= 0.1 then
		places = 1
	elseif inc < 0.01 then
		places = 3
	end
	return string.format("%." .. tostring(places) .. "f", v)
end

local function callSafe(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		RainWare:Notify({ Title = "Error", Content = tostring(err), Duration = 5 })
	end
end

----------------------------------------------------------------------------
-- Accent binding and tweening
----------------------------------------------------------------------------

local binds = {}

-- fn(a, b) receives the two accent colours. Re-applied when the accent changes.
local function live(obj, fn)
	binds[#binds + 1] = { obj = obj, fn = fn }
	pcall(fn, ACC.a, ACC.b)
end

local function applyAccent()
	for i = #binds, 1, -1 do
		local bind = binds[i]
		if bind.obj.Parent == nil then
			table.remove(binds, i)
		else
			pcall(bind.fn, ACC.a, ACC.b)
		end
	end
end

local liveTweens = setmetatable({}, { __mode = "k" })

local function anim(obj, props, dur, style)
	if Settings.Performance or (dur and dur <= 0) then
		for k, v in pairs(props) do
			obj[k] = v
		end
		return
	end
	local map = liveTweens[obj]
	if not map then
		map = {}
		liveTweens[obj] = map
	end
	local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	for k in pairs(props) do
		if map[k] then
			map[k]:Cancel()
		end
		map[k] = tw
	end
	tw:Play()
end

----------------------------------------------------------------------------
-- Icons: Lucide sprite sheet when available, drawn fallbacks otherwise
----------------------------------------------------------------------------

local ICON_NAMES = {
	"settings", "minus", "x", "chevron-down", "chevron-up", "chevron-right",
	"droplet", "cloud-rain", "waves-horizontal", "keyboard", "zap", "palette",
	"search", "sliders-horizontal", "rotate-ccw", "check", "power", "circle-dot",
}
local ICON_INDEX = {}
for i, name in ipairs(ICON_NAMES) do
	ICON_INDEX[name] = i
end
local ICON_CELL = 96
local ICON_COLS = 6

local function shape(parent, w, h, x, y, rot, color, round)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.5, y),
		Size = UDim2.fromOffset(w, h),
		BorderSizePixel = 0,
		Rotation = rot or 0,
	}, parent)
	if color then
		f.BackgroundColor3 = color
	else
		f.BackgroundTransparency = 1
	end
	if round then
		corner(f, 99)
	end
	return f
end

local FALLBACK = {
	x = function(h, k, c)
		shape(h, 17 * k, 2.4 * k, 0, 0, 45, c, true)
		shape(h, 17 * k, 2.4 * k, 0, 0, -45, c, true)
	end,
	minus = function(h, k, c)
		shape(h, 14 * k, 2.4 * k, 0, 0, 0, c, true)
	end,
	["chevron-down"] = function(h, k, c)
		shape(h, 8.5 * k, 2.4 * k, -3 * k, 0, 45, c, true)
		shape(h, 8.5 * k, 2.4 * k, 3 * k, 0, -45, c, true)
	end,
	["chevron-up"] = function(h, k, c)
		shape(h, 8.5 * k, 2.4 * k, -3 * k, 0, -45, c, true)
		shape(h, 8.5 * k, 2.4 * k, 3 * k, 0, 45, c, true)
	end,
	["chevron-right"] = function(h, k, c)
		shape(h, 8.5 * k, 2.4 * k, 0, -3 * k, 45, c, true)
		shape(h, 8.5 * k, 2.4 * k, 0, 3 * k, -45, c, true)
	end,
	droplet = function(h, k, c)
		shape(h, 6.4 * k, 6.4 * k, 0, -5.2 * k, 45, c, false)
		shape(h, 13.6 * k, 13.6 * k, 0, 3 * k, 0, c, true)
	end,
	settings = function(h, k, c)
		local ring = shape(h, 13 * k, 13 * k, 0, 0, 0, nil, true)
		stroke(ring, c, 2.2 * k, 0)
		for i = 0, 7 do
			local a = math.rad(i * 45)
			shape(h, 4.2 * k, 5.4 * k, 9.2 * k * math.sin(a), -9.2 * k * math.cos(a), i * 45, c, true)
		end
		shape(h, 4 * k, 4 * k, 0, 0, 0, c, true)
	end,
}

local function paintIcon(inst, color)
	if inst:IsA("ImageLabel") then
		inst.ImageColor3 = color
		return
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = color
		elseif d:IsA("UIStroke") then
			d.Color = color
		end
	end
end

local function makeIcon(parent, name, size, color)
	local url = imageUrl("sprite")
	local idx = ICON_INDEX[name]
	local inst
	if url and idx then
		inst = new("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = url,
			ImageColor3 = color or THEME.text,
			ImageRectOffset = Vector2.new(((idx - 1) % ICON_COLS) * ICON_CELL, math.floor((idx - 1) / ICON_COLS) * ICON_CELL),
			ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL),
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		inst = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 })
	end
	inst.AnchorPoint = Vector2.new(0.5, 0.5)
	inst.Position = UDim2.fromScale(0.5, 0.5)
	inst.Size = UDim2.fromOffset(size, size)
	inst.Parent = parent
	if not (url and idx) and FALLBACK[name] then
		FALLBACK[name](inst, size / 24, color or THEME.text)
	end
	return inst
end

----------------------------------------------------------------------------
-- Global drag handling (one connection for the whole library)
----------------------------------------------------------------------------

local drag = nil

local function beginDrag(move, stop)
	drag = { move = move, stop = stop }
end

UIS.InputChanged:Connect(function(input)
	if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		drag.move(input.Position)
	end
end)

UIS.InputEnded:Connect(function(input)
	if drag and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		local done = drag
		drag = nil
		if done.stop then
			done.stop()
		end
	end
end)

----------------------------------------------------------------------------
-- Weather: rain streaks and puddles, one shared Heartbeat loop
----------------------------------------------------------------------------

local SLANT = math.tan(math.rad(12))
local fxList = {}
local loopConn = nil

local function stepFx(fx, dt)
	if Settings.Performance then
		return
	end
	fx.time = fx.time + dt
	if Settings.Rain then
		local size = fx.rainLayer.AbsoluteSize
		local w, h = size.X, size.Y
		if w > 0 and h > 0 then
			for _, d in ipairs(fx.drops) do
				d.y = d.y + d.v * dt
				d.x = d.x - d.v * SLANT * dt
				if d.y > h + d.len then
					d.y = -d.len - math.random() * h * 0.5
					d.x = math.random() * (w + h * SLANT)
					d.v = 170 + math.random() * 170
				end
				d.frame.Position = UDim2.fromOffset(d.x, d.y)
			end
		end
	end
	if Settings.Puddles then
		for _, p in ipairs(fx.puddles) do
			for _, r in ipairs(p.rings) do
				local k = (fx.time / r.period + r.phase) % 1
				r.frame.Size = UDim2.fromOffset(p.w * (0.2 + 1.1 * k), 2 + 8 * k)
				r.stroke.Transparency = 0.25 + 0.75 * k
			end
		end
	end
end

local function startLoop()
	if loopConn then
		return
	end
	loopConn = RunService.Heartbeat:Connect(function(dt)
		for _, fx in ipairs(fxList) do
			if fx.win._state == "open" then
				stepFx(fx, dt)
			end
		end
	end)
end

----------------------------------------------------------------------------
-- Control builders (shared by tabs and the settings panel)
----------------------------------------------------------------------------

local function hasText(v)
	return v ~= nil and tostring(v) ~= ""
end

local function rowCard(parent, height)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.card,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
	}, parent)
	corner(frame, 12)
	stroke(frame, THEME.edge, 1, 0.8)
	return frame
end

local function rowHover(hit, frame)
	hit.MouseEnter:Connect(function()
		anim(frame, { BackgroundTransparency = 0.3 }, 0.15)
	end)
	hit.MouseLeave:Connect(function()
		anim(frame, { BackgroundTransparency = 0.42 }, 0.15)
	end)
end

local function rowContent(frame, cfg, hasDesc, rightPad)
	local h = frame.Size.Y.Offset
	local x = 14
	if cfg.Icon then
		local ic = makeIcon(frame, cfg.Icon, 16, THEME.dim)
		ic.Position = UDim2.new(0, 24, 0.5, 0)
		x = 42
	end
	local title = label(frame, tostring(cfg.Title or ""), Enum.Font.GothamSemibold, 13, THEME.text, {
		Position = UDim2.fromOffset(x, hasDesc and 7 or 0),
		Size = UDim2.new(1, -x - rightPad, 0, hasDesc and 18 or h),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local desc = nil
	if hasDesc then
		desc = label(frame, tostring(cfg.Description), Enum.Font.Gotham, 11, THEME.dim, {
			Position = UDim2.fromOffset(x, 25),
			Size = UDim2.new(1, -x - rightPad, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	return title, desc
end

local function makeButton(parent, cfg)
	local hasDesc = hasText(cfg.Description)
	local frame = rowCard(parent, hasDesc and 50 or 38)
	local title, desc = rowContent(frame, cfg, hasDesc, 44)
	local arrow = makeIcon(frame, "chevron-right", 14, THEME.dim)
	arrow.Position = UDim2.new(1, -20, 0.5, 0)

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, frame)
	rowHover(hit, frame)
	hit.MouseButton1Down:Connect(function()
		anim(frame, { BackgroundTransparency = 0.2 }, 0.08)
	end)
	hit.MouseButton1Up:Connect(function()
		anim(frame, { BackgroundTransparency = 0.3 }, 0.12)
	end)
	hit.Activated:Connect(function()
		callSafe(cfg.Callback)
	end)

	local api = { Frame = frame }
	function api:SetTitle(t)
		title.Text = tostring(t or "")
	end
	function api:SetDesc(t)
		if desc then
			desc.Text = tostring(t or "")
		end
	end
	return api
end

local function makeToggle(parent, cfg)
	local state = cfg.Default and true or false
	local hasDesc = hasText(cfg.Description)
	local frame = rowCard(parent, hasDesc and 50 or 38)
	rowContent(frame, cfg, hasDesc, 80)

	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, frame)
	corner(track, 11)
	local trackStroke = stroke(track, THEME.edge, 1, 0.7)

	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 11)
	local fillGrad = new("UIGradient", { Color = ColorSequence.new(ACC.a, ACC.b), Rotation = 0 }, fill)
	live(fillGrad, function(a, b)
		fillGrad.Color = ColorSequence.new(a, b)
	end)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = THEME.text,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 8)

	local function render(instant)
		local dur = instant and 0 or 0.2
		anim(knob, { Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, dur, Enum.EasingStyle.Quint)
		anim(fill, { BackgroundTransparency = state and 0 or 1 }, dur)
		anim(trackStroke, { Transparency = state and 0.3 or 0.7 }, dur)
	end

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, frame)
	rowHover(hit, frame)

	local api = { Frame = frame, Flag = cfg.Flag, Title = cfg.Title }
	function api:Get()
		return state
	end
	function api:Set(v)
		state = v and true or false
		render(false)
		if cfg.Flag then
			RainWare.Flags[cfg.Flag] = state
		end
		callSafe(cfg.Callback, state)
	end
	hit.Activated:Connect(function()
		api:Set(not state)
	end)

	render(true)
	if cfg.Flag then
		RainWare.Flags[cfg.Flag] = state
		RainWare.Options[cfg.Flag] = api
	end
	return api
end

local function makeSlider(parent, cfg)
	local minV = tonumber(cfg.Min) or 0
	local maxV = tonumber(cfg.Max) or 100
	if maxV <= minV then
		maxV = minV + 1
	end
	local inc = tonumber(cfg.Increment) or tonumber(cfg.Step) or 1
	if inc <= 0 then
		inc = 1
	end
	local suffix = tostring(cfg.Suffix or "")
	local value = tonumber(cfg.Default) or minV

	local frame = rowCard(parent, 56)
	label(frame, tostring(cfg.Title or "Slider"), Enum.Font.GothamSemibold, 13, THEME.text, {
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -110, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local valueL = label(frame, "", Enum.Font.GothamSemibold, 12, ACC.a, {
		Position = UDim2.new(1, -98, 0, 9),
		Size = UDim2.fromOffset(84, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	live(valueL, function(a)
		valueL.TextColor3 = a
	end)

	local track = new("Frame", {
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, frame)
	corner(track, 3)

	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 3)
	local fillGrad = new("UIGradient", { Color = ColorSequence.new(ACC.a, ACC.b) }, fill)
	live(fillGrad, function(a, b)
		fillGrad.Color = ColorSequence.new(a, b)
	end)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 7)
	local knobStroke = stroke(knob, ACC.a, 2, 0.3)
	live(knobStroke, function(a)
		knobStroke.Color = a
	end)

	local api = { Flag = cfg.Flag, Title = cfg.Title, Frame = frame }

	local function render()
		local a = math.clamp((value - minV) / (maxV - minV), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valueL.Text = fmtNum(value, inc) .. suffix
	end

	local function setValue(v, silent)
		v = math.clamp(tonumber(v) or minV, minV, maxV)
		v = math.floor(v / inc + 0.5) * inc
		value = tonumber(string.format("%.4f", math.clamp(v, minV, maxV)))
		render()
		if cfg.Flag then
			RainWare.Flags[cfg.Flag] = value
		end
		if not silent then
			callSafe(cfg.Callback, value)
		end
	end

	function api:Get()
		return value
	end
	function api:Set(v)
		setValue(v, false)
	end

	local hit = new("TextButton", {
		Position = UDim2.fromOffset(0, -9),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, track)

	local function setFromX(x)
		local w = math.max(1, track.AbsoluteSize.X)
		local a = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
		setValue(minV + (maxV - minV) * a, false)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
			beginDrag(function(p)
				setFromX(p.X)
			end)
		end
	end)

	setValue(value, true)
	if cfg.Flag then
		RainWare.Options[cfg.Flag] = api
	end
	return api
end

local function makeDropdown(parent, cfg, win)
	local flag = cfg.Flag
	local multi = cfg.Multi == true
	local searchable = cfg.Search == true or cfg.Searchable == true
	local values = {}
	for _, v in ipairs(cfg.Values or cfg.Content or {}) do
		values[#values + 1] = tostring(v)
	end
	local selected = {}
	local value = ""
	if multi then
		for _, v in ipairs(cfg.Default or {}) do
			selected[tostring(v)] = true
		end
	else
		value = cfg.Default
		if value == nil or value == "" then
			value = values[1]
		end
		value = tostring(value or "")
	end

	local HEAD = 38
	local frame = rowCard(parent, HEAD)
	label(frame, tostring(cfg.Title or "Dropdown"), Enum.Font.GothamSemibold, 13, THEME.text, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -170, 0, HEAD),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local valueL = label(frame, "", Enum.Font.GothamSemibold, 12, ACC.a, {
		Position = UDim2.new(1, -150, 0, 0),
		Size = UDim2.fromOffset(116, HEAD),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	live(valueL, function(a)
		valueL.TextColor3 = a
	end)
	local arrow = makeIcon(frame, "chevron-down", 14, THEME.dim)
	arrow.Position = UDim2.new(1, -20, 0, HEAD / 2)

	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, HEAD),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, frame)
	rowHover(header, frame)

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, HEAD + 6),
		Size = UDim2.new(1, -20, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACC.a,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, frame)
	live(list, function(a)
		list.ScrollBarImageColor3 = a
	end)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingBottom = UDim.new(0, 4) }, list)

	local search = nil
	if searchable then
		search = new("TextBox", {
			Size = UDim2.new(1, -4, 0, 26),
			BackgroundColor3 = THEME.deep,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Search...",
			PlaceholderColor3 = THEME.faint,
			TextColor3 = THEME.text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			LayoutOrder = 0,
		}, list)
		corner(search, 8)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, search)
	end

	local open = false
	local listHeight = 0
	local rebuild
	local setOpen

	local function selectedNames()
		local out = {}
		for _, v in ipairs(values) do
			if selected[v] then
				out[#out + 1] = v
			end
		end
		return out
	end

	local function currentOut()
		if multi then
			return selectedNames()
		end
		return value
	end

	local function summarize()
		if not multi then
			return value
		end
		local names = selectedNames()
		if #names == 0 then
			return "None"
		elseif #names == 1 then
			return names[1]
		end
		return tostring(#names) .. " selected"
	end

	local function visibleValues()
		local q = search and string.lower(search.Text) or ""
		local out = {}
		for _, v in ipairs(values) do
			if q == "" or string.find(string.lower(v), q, 1, true) then
				out[#out + 1] = v
			end
		end
		return out
	end

	local function updateHeight()
		local rows = math.clamp(#visibleValues(), 1, 6)
		listHeight = rows * 29 + (search and 32 or 0) + 4
		if open then
			list.Size = UDim2.new(1, -20, 0, listHeight)
			frame.Size = UDim2.new(1, 0, 0, HEAD + 6 + listHeight + 6)
		end
	end

	local function commit()
		valueL.Text = summarize()
		if flag then
			RainWare.Flags[flag] = currentOut()
		end
		callSafe(cfg.Callback, currentOut())
	end

	rebuild = function()
		for _, c in ipairs(list:GetChildren()) do
			if c.Name == "Item" then
				c:Destroy()
			end
		end
		for i, v in ipairs(visibleValues()) do
			local picked = (multi and selected[v] == true) or (not multi and v == value)
			local item = new("TextButton", {
				Name = "Item",
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = THEME.white,
				BackgroundTransparency = picked and 0.35 or 0.75,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
			}, list)
			corner(item, 8)
			label(item, v, Enum.Font.Gotham, 12, picked and ACC.a or THEME.text, {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -28, 1, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			if multi then
				local dot = new("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -9, 0.5, 0),
					Size = UDim2.fromOffset(8, 8),
					BackgroundColor3 = picked and ACC.a or THEME.faint,
					BorderSizePixel = 0,
				}, item)
				corner(dot, 4)
			end
			item.MouseEnter:Connect(function()
				anim(item, { BackgroundTransparency = 0.5 }, 0.12)
			end)
			item.MouseLeave:Connect(function()
				anim(item, { BackgroundTransparency = picked and 0.35 or 0.75 }, 0.12)
			end)
			item.Activated:Connect(function()
				if multi then
					selected[v] = (not selected[v]) or nil
					rebuild()
					commit()
				else
					value = v
					commit()
					setOpen(false)
				end
			end)
		end
	end

	local entry = { frame = frame }

	setOpen = function(v)
		open = v and true or false
		list.Visible = open
		if open then
			rebuild()
			updateHeight()
			table.insert(win._dropdowns, entry)
		else
			frame.Size = UDim2.new(1, 0, 0, HEAD)
			local i = table.find(win._dropdowns, entry)
			if i then
				table.remove(win._dropdowns, i)
			end
		end
		anim(arrow, { Rotation = open and 180 or 0 }, 0.18)
	end
	entry.close = function()
		setOpen(false)
	end

	header.Activated:Connect(function()
		setOpen(not open)
	end)
	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			rebuild()
			updateHeight()
		end)
	end

	local api = { Flag = flag, Title = cfg.Title, Multi = multi, Frame = frame }
	function api:Get()
		return currentOut()
	end
	function api:Set(v)
		if multi then
			selected = {}
			if type(v) == "table" then
				for _, item in ipairs(v) do
					selected[tostring(item)] = true
				end
			end
		else
			value = tostring(v)
		end
		rebuild()
		commit()
	end
	function api:Toggle(v)
		if not multi then
			return api:Set(v)
		end
		v = tostring(v)
		selected[v] = (not selected[v]) or nil
		rebuild()
		commit()
	end
	function api:SetValues(newValues)
		values = {}
		for _, v in ipairs(newValues or {}) do
			values[#values + 1] = tostring(v)
		end
		if not multi then
			local found = false
			for _, v in ipairs(values) do
				if v == value then
					found = true
					break
				end
			end
			if not found then
				value = values[1] or ""
			end
		end
		updateHeight()
		rebuild()
		valueL.Text = summarize()
		if flag then
			RainWare.Flags[flag] = currentOut()
		end
	end
	function api:Open()
		setOpen(true)
	end
	function api:Close()
		setOpen(false)
	end
	function api:GetValues()
		local copy = {}
		for i, v in ipairs(values) do
			copy[i] = v
		end
		return copy
	end

	valueL.Text = summarize()
	if flag then
		RainWare.Flags[flag] = currentOut()
		RainWare.Options[flag] = api
	end
	return api
end

local function makeParagraph(parent, p)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.card,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
	}, parent)
	corner(frame, 12)
	stroke(frame, THEME.edge, 1, 0.8)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
	}, frame)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, frame)

	local titleL = nil
	if p.Title then
		titleL = label(frame, tostring(p.Title), Enum.Font.GothamSemibold, 13, THEME.text, {
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
		})
	end
	local bodyL = label(frame, tostring(p.Content or ""), Enum.Font.Gotham, 12, THEME.dim, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
	})

	local api = { Frame = frame }
	function api:SetContent(text)
		bodyL.Text = tostring(text or "")
	end
	function api:SetTitle(text)
		if titleL then
			titleL.Text = tostring(text or "")
		end
	end
	return api
end

local function makeDivider(parent)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	fadeLine(holder, THEME.edge, 0.35)
	return holder
end

----------------------------------------------------------------------------
-- Window shell
----------------------------------------------------------------------------

function RainWare:CreateWindow(cfg)
	cfg = cfg or {}
	startLoop()

	local vp = viewportSize()
	local W = cfg.Size and cfg.Size.X.Offset or 0
	if W <= 0 then
		W = math.clamp(math.floor(vp.X * 0.4), 560, 680)
	end
	local H = cfg.Size and cfg.Size.Y.Offset or 0
	if H <= 0 then
		H = math.clamp(math.floor(vp.Y * 0.5), 360, 400)
	end
	W = math.min(W, vp.X - 24)
	H = math.min(H, vp.Y - 24)

	local screen = new("ScreenGui", {
		Name = "RainWareUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	}, guiParent())

	local win = setmetatable({
		Title = cfg.Title or "RainWare",
		SubTitle = cfg.SubTitle or "",
		_tabs = {},
		_current = nil,
		_conns = {},
		_state = "open",
		_dropdowns = {},
		_capturing = false,
		_settingsOpen = false,
		_started = os.clock(),
		_gui = screen,
		_W = W,
		_H = H,
		_x = math.floor((vp.X - W) / 2),
		_y = math.floor((vp.Y - H) / 2),
		_defaultKey = toKeyCode(cfg.ToggleKey) or Enum.KeyCode.RightShift,
	}, { __index = self })

	-- Wrap holds glow, shadow and panel so one UIScale animates the whole window.
	local wrap = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, screen)
	win._scale = new("UIScale", { Scale = 1 }, wrap)
	win._wrap = wrap

	local glow = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 26, 1, 26),
		BackgroundColor3 = ACC.a,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
	}, wrap)
	corner(glow, 32)
	live(glow, function(a)
		glow.BackgroundColor3 = a
	end)
	win._glow = glow

	local shadow = new("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1, -8, 1, 6),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
	}, wrap)
	corner(shadow, 24)

	local panel = new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, wrap)
	corner(panel, 20)
	gradient(panel, THEME.panelTop, THEME.panelBottom, 90, 0.12, 0.3)
	stroke(panel, THEME.edge, 1.2, 0.5)
	win._panel = panel

	local sheen = new("Frame", {
		Name = "Sheen",
		Size = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, panel)
	corner(sheen, 20)
	gradient(sheen, THEME.white, THEME.white, 90, 0.84, 1)

	local rim = new("Frame", {
		Name = "Rim",
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -44, 0, 1),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, panel)
	new("UIGradient", {
		Color = ColorSequence.new(THEME.white, THEME.white),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, rim)

	local floorGlow = new("Frame", {
		Name = "FloorGlow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
	}, panel)
	local floorGrad = new("UIGradient", {
		Color = ColorSequence.new(ACC.a, ACC.a),
		Transparency = NumberSequence.new(1, 0.78),
		Rotation = 90,
	}, floorGlow)
	live(floorGrad, function(a)
		floorGrad.Color = ColorSequence.new(a, a)
	end)

	-- Rain and puddles sit above the glass and below every control.
	local rainLayer = new("Frame", {
		Name = "Rain",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, panel)
	local puddleLayer = new("Frame", {
		Name = "Puddles",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, panel)

	local fx = { win = win, time = 0, drops = {}, puddles = {}, rainLayer = rainLayer }
	for i = 1, 30 do
		local len = 10 + math.random() * 16
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.random() < 0.3 and 2 or 1, len),
			Rotation = 12,
			BackgroundColor3 = THEME.white,
			BackgroundTransparency = 0.4 + math.random() * 0.3,
			BorderSizePixel = 0,
		}, rainLayer)
		new("UIGradient", {
			Color = ColorSequence.new(THEME.edge, THEME.edge),
			Transparency = NumberSequence.new(1, 0.1),
			Rotation = 90,
		}, f)
		local drop = {
			frame = f,
			len = len,
			x = math.random() * (W + H * SLANT),
			y = math.random() * H,
			v = 170 + math.random() * 170,
		}
		f.Position = UDim2.fromOffset(drop.x, drop.y)
		fx.drops[i] = drop
	end

	for i, s in ipairs({ 0.16, 0.4, 0.64, 0.86 }) do
		local x = W * s + (math.random() - 0.5) * 24
		local y = H - 8
		local w = 70 + math.random() * 40
		local body = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, 5),
			BackgroundColor3 = ACC.a,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
		}, puddleLayer)
		corner(body, 99)
		live(body, function(a)
			body.BackgroundColor3 = a
		end)
		local rings = {}
		for r = 1, 2 do
			local ring = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w * 0.3, 2),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, puddleLayer)
			corner(ring, 99)
			rings[r] = {
				frame = ring,
				stroke = stroke(ring, THEME.edge, 1, 0.4),
				period = 3.2,
				phase = (r - 1) * 0.5,
			}
		end
		fx.puddles[i] = { w = w, rings = rings, body = body }
	end
	fxList[#fxList + 1] = fx
	win._fx = fx

	-- Top bar: logo, title, and the window buttons. Dragging it moves the window.
	local top = new("TextButton", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, panel)
	win._top = top
	local topLine = fadeLine(panel, THEME.edge, 0.55)
	topLine.Position = UDim2.new(0, 16, 0, 52)
	topLine.Size = UDim2.new(1, -32, 0, 1)

	local logoUrl = imageUrl("logo")
	local logo
	if logoUrl then
		logo = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(31, 26),
			Size = UDim2.fromOffset(32, 32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = logoUrl,
			ScaleType = Enum.ScaleType.Fit,
		}, top)
		corner(logo, 9)
	else
		logo = makeIcon(top, "droplet", 26, ACC.a)
		logo.Position = UDim2.fromOffset(31, 26)
		live(logo, function(a)
			paintIcon(logo, a)
		end)
	end

	local titleL = label(top, win.Title, Enum.Font.GothamBold, 17, THEME.white, {
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -170, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local titleGrad = new("UIGradient", { Color = ColorSequence.new(THEME.white, ACC.a), Rotation = 0 }, titleL)
	live(titleGrad, function(a)
		titleGrad.Color = ColorSequence.new(THEME.white, a)
	end)
	win._titleL = titleL

	win._subL = label(top, win.SubTitle, Enum.Font.Gotham, 11, THEME.dim, {
		Position = UDim2.fromOffset(56, 29),
		Size = UDim2.new(1, -170, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local function chip(icon, offsetX, onClick)
		local btn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offsetX, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = THEME.deep,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, top)
		corner(btn, 9)
		local st = stroke(btn, THEME.edge, 1, 0.75)
		local ic = makeIcon(btn, icon, 14, THEME.dim)
		btn.MouseEnter:Connect(function()
			anim(btn, { BackgroundTransparency = 0.15 }, 0.15)
			anim(st, { Transparency = 0.35 }, 0.15)
			paintIcon(ic, THEME.text)
		end)
		btn.MouseLeave:Connect(function()
			anim(btn, { BackgroundTransparency = 0.45 }, 0.15)
			anim(st, { Transparency = 0.75 }, 0.15)
			paintIcon(ic, THEME.dim)
		end)
		btn.Activated:Connect(onClick)
		return btn
	end

	chip("x", -12, function()
		win:Toggle(false)
	end)
	chip("minus", -46, function()
		win:Minimize()
	end)
	chip("settings", -80, function()
		win:OpenSettings(not win._settingsOpen)
	end)

	-- Body: tab sidebar, content area, settings overlay, footer.
	local sidebar = new("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(0, 140, 1, -110),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, panel)
	corner(sidebar, 16)
	stroke(sidebar, THEME.edge, 1, 0.82)
	local tabScroll = new("ScrollingFrame", {
		Name = "TabScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACC.a,
		ScrollBarImageTransparency = 0.35,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, sidebar)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabScroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 8),
	}, tabScroll)
	win._sidebar = tabScroll

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(164, 64),
		Size = UDim2.new(1, -176, 1, -110),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, panel)
	corner(content, 16)
	stroke(content, THEME.edge, 1, 0.82)
	win._content = content

	local overlay = new("Frame", {
		Name = "Settings",
		Position = UDim2.fromOffset(164, 64),
		Size = UDim2.new(1, -176, 1, -110),
		BackgroundColor3 = THEME.deep,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
	}, panel)
	corner(overlay, 16)
	stroke(overlay, THEME.edge, 1, 0.78)
	win._overlay = overlay

	local footLine = fadeLine(panel, THEME.edge, 0.3)
	footLine.Position = UDim2.new(0, 16, 1, -40)
	footLine.Size = UDim2.new(1, -32, 0, 1)

	local footer = new("Frame", {
		Name = "Footer",
		Position = UDim2.new(0, 16, 1, -36),
		Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, panel)
	win._statusL = label(footer, "RainWare v" .. RainWare.Version, Enum.Font.Code, 11, THEME.faint, {
		Size = UDim2.new(0.5, 0, 1, 0),
	})
	win._hintL = label(footer, "", Enum.Font.Gotham, 11, THEME.faint, {
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Minimized state: a small glass pill that can be dragged or clicked to restore.
	local pill = new("TextButton", {
		Name = "Pill",
		Position = UDim2.fromOffset(win._x, win._y),
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = THEME.white,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, screen)
	corner(pill, 19)
	gradient(pill, THEME.panelTop, THEME.panelBottom, 90, 0.05, 0.2)
	local pillStroke = stroke(pill, ACC.a, 1.2, 0.2)
	live(pillStroke, function(a)
		pillStroke.Color = a
	end)
	local pillIcon = makeIcon(pill, "droplet", 18, ACC.a)
	pillIcon.Position = UDim2.fromOffset(22, 19)
	live(pillIcon, function(a)
		paintIcon(pillIcon, a)
	end)
	label(pill, "RainWare", Enum.Font.GothamSemibold, 13, THEME.text, {
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -60, 1, 0),
	})
	local pillChev = makeIcon(pill, "chevron-up", 12, THEME.dim)
	pillChev.Position = UDim2.new(1, -18, 0.5, 0)
	win._pill = pill
	win._pillScale = new("UIScale", { Scale = 1 }, pill)

	-- Notifications stack bottom-right and stay visible while the window is hidden.
	local notifHolder = new("Frame", {
		Name = "Notifs",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, screen)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, notifHolder)
	win._notifs = notifHolder
	RainWare._notifHolder = notifHolder

	win._gui = screen
	win._hintL.Text = (toKeyCode(Settings.ToggleKey) or win._defaultKey).Name .. " to hide"

	-- Drag the window by its top bar.
	top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			win:CloseDropdowns()
			local startMouse = input.Position
			local startX, startY = win._x, win._y
			beginDrag(function(p)
				local d = p - startMouse
				win._x = startX + d.X
				win._y = startY + d.Y
				win:_place()
			end)
		end
	end)

	table.insert(win._conns, UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			for i = #win._dropdowns, 1, -1 do
				local dd = win._dropdowns[i]
				if not inRect(dd.frame, input.Position) then
					dd.close()
				end
			end
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if win._capturing then
			win._capturing = false
			if input.KeyCode == Enum.KeyCode.Escape then
				win:_setToggleKey(nil)
			else
				win:_setToggleKey(input.KeyCode)
			end
			return
		end
		local key = toKeyCode(Settings.ToggleKey) or win._defaultKey
		if input.KeyCode == key and not UIS:GetFocusedTextBox() then
			win:Toggle()
		end
	end))

	table.insert(win._conns, screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		win:_place()
	end))

	win:_place()
	win:_applyEffects()
	RainWare._buildSettings(win)

	-- The pill restores on a click and moves when dragged.
	pill.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local startMouse = input.Position
			local startX, startY = win._px, win._py
			local moved = 0
			beginDrag(function(p)
				local d = p - startMouse
				moved = math.max(moved, math.abs(d.X) + math.abs(d.Y))
				win._px = startX + d.X
				win._py = startY + d.Y
				win:_place()
			end, function()
				if moved < 6 then
					win:Restore()
				end
			end)
		end
	end)
	RainWare._activeWindow = win

	if cfg.DefaultTab then
		task.defer(function()
			if type(cfg.DefaultTab) == "number" then
				win:SelectTab(cfg.DefaultTab)
			else
				win:SelectTabByTitle(cfg.DefaultTab)
			end
		end)
	end

	return win
end

----------------------------------------------------------------------------
-- Window behaviour
----------------------------------------------------------------------------

function RainWare:_place()
	local vp = viewportSize()
	self._x = math.clamp(self._x, 0, math.max(0, vp.X - self._W))
	self._y = math.clamp(self._y, 0, math.max(0, vp.Y - self._H))
	self._wrap.Position = UDim2.fromOffset(math.floor(self._x + self._W / 2), math.floor(self._y + self._H / 2))
	if self._px then
		self._px = math.clamp(self._px, 0, math.max(0, vp.X - 150))
		self._py = math.clamp(self._py, 0, math.max(0, vp.Y - 38))
		self._pill.Position = UDim2.fromOffset(math.floor(self._px), math.floor(self._py))
	end
end

function RainWare:_applyEffects()
	local fx = self._fx
	local showRain = Settings.Rain and not Settings.Performance
	local showPuddles = Settings.Puddles and not Settings.Performance
	for _, d in ipairs(fx.drops) do
		d.frame.Visible = showRain
	end
	for _, p in ipairs(fx.puddles) do
		p.body.Visible = showPuddles
		for _, r in ipairs(p.rings) do
			r.frame.Visible = showPuddles
		end
	end
	self._glow.Visible = not Settings.Performance
	self._panel:FindFirstChild("Sheen").Visible = not Settings.Performance
	self._panel:FindFirstChild("FloorGlow").Visible = not Settings.Performance
end

function RainWare:CloseDropdowns()
	for i = #self._dropdowns, 1, -1 do
		local dd = self._dropdowns[i]
		if dd.close then
			dd.close()
		end
	end
end

function RainWare:Toggle(visible)
	if visible == nil then
		visible = self._state == "hidden"
	end
	if visible then
		self._state = "open"
		self._pill.Visible = false
		self._wrap.Visible = true
		if Settings.Performance then
			self._scale.Scale = 1
		else
			self._scale.Scale = 0.92
			anim(self._scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		end
	else
		self._state = "hidden"
		self:CloseDropdowns()
		self._pill.Visible = false
		self._wrap.Visible = false
	end
end

function RainWare:Minimize()
	if self._state ~= "open" then
		return
	end
	self._state = "minimized"
	self:CloseDropdowns()
	self._px = self._x
	self._py = self._y
	self._wrap.Visible = false
	self._pill.Position = UDim2.fromOffset(math.floor(self._px), math.floor(self._py))
	self._pill.Visible = true
	if Settings.Performance then
		self._pillScale.Scale = 1
	else
		self._pillScale.Scale = 0.8
		anim(self._pillScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	end
end

function RainWare:Restore()
	self:Toggle(true)
end

function RainWare:OpenSettings(open)
	self._settingsOpen = open and true or false
	self:CloseDropdowns()
	self._overlay.Visible = self._settingsOpen
	if self._settingsOpen then
		self._overlay.Position = UDim2.fromOffset(176, 64)
		anim(self._overlay, { Position = UDim2.fromOffset(164, 64) }, 0.22, Enum.EasingStyle.Quint)
	end
end

function RainWare:_setToggleKey(key)
	if key then
		Settings.ToggleKey = key.Name
		saveSettings()
	end
	local current = toKeyCode(Settings.ToggleKey) or self._defaultKey
	self._hintL.Text = current.Name .. " to hide"
	if self._keyRow then
		self._keyRow:SetDesc("Current: " .. current.Name .. "  (click, then press a key)")
	end
end

function RainWare:_setAccent(index)
	if not PRESETS[index] then
		return
	end
	Settings.Accent = index
	ACC.a = PRESETS[index].a
	ACC.b = PRESETS[index].b
	applyAccent()
	saveSettings()
	for i, ring in ipairs(self._swatches or {}) do
		ring.Transparency = i == index and 0 or 1
	end
end

function RainWare:SetStatus(text)
	self._statusL.Text = tostring(text or "")
end

function RainWare:SetTitle(t, sub)
	self.Title = tostring(t or self.Title)
	self.SubTitle = tostring(sub or self.SubTitle or "")
	self._titleL.Text = self.Title
	self._subL.Text = self.SubTitle
end

function RainWare:Destroy()
	for _, c in ipairs(self._conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self._conns = {}
	for i = #fxList, 1, -1 do
		if fxList[i] == self._fx then
			table.remove(fxList, i)
		end
	end
	pcall(function()
		self._gui:Destroy()
	end)
end

----------------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------------

function RainWare:CreateTab(tabCfg)
	tabCfg = tabCfg or {}
	local index = #self._tabs + 1
	local name = tabCfg.Title or ("Tab " .. index)

	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
		LayoutOrder = tabCfg.Order or index,
	}, self._sidebar)
	corner(btn, 11)

	local glowBg = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, btn)
	corner(glowBg, 11)
	local glowGrad = new("UIGradient", {
		Color = ColorSequence.new(ACC.a, ACC.b),
		Transparency = NumberSequence.new(0.45, 0.7),
		Rotation = 0,
	}, glowBg)
	live(glowGrad, function(a, b)
		glowGrad.Color = ColorSequence.new(a, b)
	end)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		BackgroundColor3 = ACC.a,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, btn)
	corner(bar, 2)
	live(bar, function(a)
		bar.BackgroundColor3 = a
	end)

	local icon = nil
	local labelX = 14
	if tabCfg.Icon then
		icon = makeIcon(btn, tabCfg.Icon, 16, THEME.dim)
		icon.Position = UDim2.new(0, 24, 0.5, 0)
		labelX = 40
	end
	local nameL = label(btn, tostring(name), Enum.Font.GothamSemibold, 13, THEME.dim, {
		Position = UDim2.fromOffset(labelX, 0),
		Size = UDim2.new(1, -labelX - 8, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACC.a,
		ScrollBarImageTransparency = 0.25,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	}, self._content)
	live(scroll, function(a)
		scroll.ScrollBarImageColor3 = a
	end)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
	}, scroll)

	local tab = {
		Title = tostring(name),
		Index = index,
		_frame = scroll,
		_button = btn,
		_window = self,
		_target = nil,
		_orders = {},
		_glow = glowBg,
		_bar = bar,
		_label = nameL,
		_icon = icon,
		_active = false,
	}

	if icon then
		live(icon, function(a)
			paintIcon(icon, tab._active and a or THEME.dim)
		end)
	end

	btn.MouseEnter:Connect(function()
		if self._current ~= tab.Index then
			anim(glowBg, { BackgroundTransparency = 0.85 }, 0.15)
		end
	end)
	btn.MouseLeave:Connect(function()
		if self._current ~= tab.Index then
			anim(glowBg, { BackgroundTransparency = 1 }, 0.15)
		end
	end)
	btn.Activated:Connect(function()
		self:SelectTab(tab.Index)
	end)

	function tab:_parent()
		return self._target or self._frame
	end

	function tab:_next()
		local parent = self:_parent()
		local n = (self._orders[parent] or 0) + 1
		self._orders[parent] = n
		return n
	end

	function tab:_nextRoot()
		local n = (self._orders[self._frame] or 0) + 1
		self._orders[self._frame] = n
		return n
	end

	function tab:Select()
		self._window:SelectTab(self.Index)
	end

	function tab:CreateSection(text)
		local section = new("Frame", {
			Name = "Section",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = self:_nextRoot(),
		}, self._frame)
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, section)

		local header = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = THEME.deep,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = 1,
		}, section)
		corner(header, 10)
		stroke(header, THEME.edge, 1, 0.85)
		local chev = makeIcon(header, "chevron-down", 12, ACC.a)
		chev.Position = UDim2.new(0, 16, 0.5, 0)
		live(chev, function(a)
			paintIcon(chev, a)
		end)
		label(header, tostring(text or "Section"), Enum.Font.GothamSemibold, 12, THEME.text, {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -40, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local body = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, section)
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) }, body)

		local open = true
		header.Activated:Connect(function()
			open = not open
			body.Visible = open
			anim(chev, { Rotation = open and 0 or -90 }, 0.18)
		end)

		self._target = body
		self._orders[body] = 0
		return section
	end

	function tab:CreateDivider()
		local holder = makeDivider(self:_parent())
		holder.LayoutOrder = self:_next()
		return holder
	end

	function tab:CreateParagraph(p)
		local api = makeParagraph(self:_parent(), p or {})
		api.Frame.LayoutOrder = self:_next()
		return api
	end

	function tab:CreateButton(b)
		local api = makeButton(self:_parent(), b or {})
		api.Frame.LayoutOrder = self:_next()
		return api.Frame
	end

	function tab:CreateToggle(t)
		t = t or {}
		local api = makeToggle(self:_parent(), t)
		api.Frame.LayoutOrder = self:_next()
		if type(t.Callback) == "function" and t.Default then
			task.defer(function()
				callSafe(t.Callback, api:Get())
			end)
		end
		return api
	end

	function tab:CreateSlider(s)
		local api = makeSlider(self:_parent(), s or {})
		api.Frame.LayoutOrder = self:_next()
		return api
	end

	function tab:CreateDropdown(d)
		local api = makeDropdown(self:_parent(), d or {}, self._window)
		api.Frame.LayoutOrder = self:_next()
		return api
	end

	table.insert(self._tabs, tab)
	if index == 1 then
		self:SelectTab(1)
	end
	return tab
end

function RainWare:SelectTab(index)
	index = tonumber(index) or 1
	self:CloseDropdowns()
	for i, tab in ipairs(self._tabs) do
		local active = i == index
		tab._active = active
		tab._frame.Visible = active
		anim(tab._glow, { BackgroundTransparency = active and 0 or 1 }, 0.2)
		anim(tab._bar, { BackgroundTransparency = active and 0 or 1 }, 0.2)
		tab._label.TextColor3 = active and THEME.text or THEME.dim
		if tab._icon then
			paintIcon(tab._icon, active and ACC.a or THEME.dim)
		end
	end
	self._current = index
end

function RainWare:SelectTabByTitle(title)
	title = tostring(title or ""):lower()
	for i, tab in ipairs(self._tabs) do
		if tostring(tab.Title):lower() == title then
			self:SelectTab(i)
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------
-- Settings panel
----------------------------------------------------------------------------

RainWare._buildSettings = function(win)
	local overlay = win._overlay
	label(overlay, "Settings", Enum.Font.GothamBold, 15, THEME.text, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -60, 0, 24),
	})

	local closeBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = THEME.card,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, overlay)
	corner(closeBtn, 9)
	makeIcon(closeBtn, "x", 12, THEME.dim)
	closeBtn.Activated:Connect(function()
		win:OpenSettings(false)
	end)

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACC.a,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, overlay)
	live(list, function(a)
		list.ScrollBarImageColor3 = a
	end)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 10),
	}, list)

	local order = 0
	local function nextOrder()
		order = order + 1
		return order
	end
	local function heading(text)
		label(list, text, Enum.Font.GothamSemibold, 11, THEME.faint, {
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = nextOrder(),
		})
	end

	heading("CONTROLS")
	win._keyRow = makeButton(list, {
		Title = "Toggle key",
		Description = "Current key",
		Icon = "keyboard",
		Callback = function()
			win._capturing = true
			win._keyRow:SetDesc("Press any key...  (Esc to cancel)")
		end,
	})
	win._keyRow.Frame.LayoutOrder = nextOrder()

	heading("WEATHER")
	local rain = makeToggle(list, {
		Title = "Rain",
		Description = "Falling streaks behind the glass",
		Icon = "cloud-rain",
		Default = Settings.Rain,
		Callback = function(v)
			Settings.Rain = v
			win:_applyEffects()
			saveSettings()
		end,
	})
	rain.Frame.LayoutOrder = nextOrder()
	local puddles = makeToggle(list, {
		Title = "Puddles",
		Description = "Ripples along the bottom edge",
		Icon = "waves-horizontal",
		Default = Settings.Puddles,
		Callback = function(v)
			Settings.Puddles = v
			win:_applyEffects()
			saveSettings()
		end,
	})
	puddles.Frame.LayoutOrder = nextOrder()

	heading("PERFORMANCE")
	local perf = makeToggle(list, {
		Title = "Performance mode",
		Description = "Turns off rain, puddles and glow",
		Icon = "zap",
		Default = Settings.Performance,
		Callback = function(v)
			Settings.Performance = v
			win:_applyEffects()
			saveSettings()
		end,
	})
	perf.Frame.LayoutOrder = nextOrder()

	heading("LOOK")
	local accentRow = rowCard(list, 50)
	accentRow.LayoutOrder = nextOrder()
	label(accentRow, "Accent", Enum.Font.GothamSemibold, 13, THEME.text, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
	})
	win._swatches = {}
	for i, preset in ipairs(PRESETS) do
		local sw = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14 - (#PRESETS - i) * 26, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = THEME.white,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, accentRow)
		corner(sw, 10)
		gradient(sw, preset.a, preset.b, 135, 0, 0)
		win._swatches[i] = stroke(sw, THEME.white, 2, i == Settings.Accent and 0 or 1)
		sw.Activated:Connect(function()
			win:_setAccent(i)
		end)
	end

	local center = makeButton(list, {
		Title = "Center window",
		Description = "Move the window back to the middle of the screen",
		Icon = "rotate-ccw",
		Callback = function()
			local vp = viewportSize()
			win._x = math.floor((vp.X - win._W) / 2)
			win._y = math.floor((vp.Y - win._H) / 2)
			win:_place()
		end,
	})
	center.Frame.LayoutOrder = nextOrder()

	label(list, "Settings are saved to the RainWare folder when your executor supports files.", Enum.Font.Gotham, 10, THEME.faint, {
		Size = UDim2.new(1, 0, 0, 28),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = nextOrder(),
	})

	win:_setToggleKey(nil)
end

----------------------------------------------------------------------------
-- Notifications and module API
----------------------------------------------------------------------------

local notifCounter = 0
local notifQueue = {}

function RainWare:Notify(cfg)
	cfg = cfg or {}
	local holder = RainWare._notifHolder
	if not holder or not holder.Parent then
		return nil
	end

	local title = tostring(cfg.Title or "RainWare")
	local content = tostring(cfg.Content or cfg.Text or "")
	if #content > 170 then
		content = content:sub(1, 167) .. "..."
	end
	if #title > 34 then
		title = title:sub(1, 31) .. "..."
	end
	local duration = tonumber(cfg.Duration) or 3.5

	notifCounter = notifCounter + 1
	local card = new("Frame", {
		Name = "NotifCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.card,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = notifCounter,
	}, holder)
	corner(card, 12)
	local cardStroke = stroke(card, THEME.edge, 1, 1)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
	}, card)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, card)

	local titleL = label(card, title, Enum.Font.GothamSemibold, 13, ACC.a, {
		Size = UDim2.new(1, 0, 0, 18),
		TextTransparency = 1,
		LayoutOrder = 1,
	})
	live(titleL, function(a)
		titleL.TextColor3 = a
	end)
	local bodyL = label(card, content, Enum.Font.Gotham, 12, THEME.dim, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = 1,
		LayoutOrder = 2,
	})

	anim(card, { BackgroundTransparency = 0.12 }, 0.2)
	anim(cardStroke, { Transparency = 0.6 }, 0.2)
	anim(titleL, { TextTransparency = 0 }, 0.2)
	anim(bodyL, { TextTransparency = 0 }, 0.2)

	notifQueue[#notifQueue + 1] = card
	while #notifQueue > 5 do
		local old = table.remove(notifQueue, 1)
		if old and old.Parent then
			old:Destroy()
		end
	end

	task.delay(duration, function()
		if not card.Parent then
			return
		end
		anim(card, { BackgroundTransparency = 1 }, 0.25)
		anim(cardStroke, { Transparency = 1 }, 0.25)
		anim(titleL, { TextTransparency = 1 }, 0.25)
		anim(bodyL, { TextTransparency = 1 }, 0.25)
		task.delay(0.3, function()
			for i, c in ipairs(notifQueue) do
				if c == card then
					table.remove(notifQueue, i)
					break
				end
			end
			if card.Parent then
				card:Destroy()
			end
		end)
	end)
	return card
end

function RainWare:GetFlag(name, fallback)
	local v = self.Flags[name]
	if v == nil then
		return fallback
	end
	return v
end

function RainWare:GetOption(name)
	return self.Options[name]
end

function RainWare:Unload()
	for _, gui in ipairs(guiParent():GetChildren()) do
		if gui.Name == "RainWareUI" then
			pcall(function()
				gui:Destroy()
			end)
		end
	end
	if loopConn then
		loopConn:Disconnect()
		loopConn = nil
	end
	for i = #fxList, 1, -1 do
		fxList[i] = nil
	end
	for i = #binds, 1, -1 do
		binds[i] = nil
	end
	self.Flags = {}
	self.Options = {}
	self._activeWindow = nil
	self._notifHolder = nil
end

ASSET_DATA.sprite = "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"
ASSET_DATA.logo = "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"

return RainWare
