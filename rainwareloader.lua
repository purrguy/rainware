--[[
  Rainware Loader v5.2.2
  - Async WindUI load
  - Ban/kick poll + validate user_id
  - Hub only after key OK
]]

print("[Loader] === v5.2.2 ===")

local type_ = type
local pcall_ = pcall
local tostring_ = tostring
local tonumber_ = tonumber

local str_sub = string.sub
local str_lower = string.lower
local str_find = string.find
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local task_wait = task.wait
local task_spawn = task.spawn
local os_clock = os.clock
local os_time = os.time

local game_ = game
local Instance_ = Instance
local UDim2_ = UDim2
local UDim_ = UDim
local Color3_ = Color3
local Enum_ = Enum

local function isFn(x)
	return type_(x) == "function"
end

local function join(list, sep)
	sep = sep or ""
	if #list == 0 then return "" end
	local s = tostring_(list[1])
	for i = 2, #list do s = s .. sep .. tostring_(list[i]) end
	return s
end

local HttpService = game_:GetService("HttpService")
local Players = game_:GetService("Players")
local player = Players.LocalPlayer

local GENV = _G
pcall_(function()
	if isFn(getgenv) then GENV = getgenv() end
end)

if GENV.RainLinkLoader_Running then
	print("[Loader] already running - skip")
	return
end
GENV.RainLinkLoader_Running = true

local VALIDATE = "https://rainware.rainware.xyz/validate"
local SCRIPT_URL = "https://rainware.rainware.xyz/script.lua"
local DISCORD = "https://discord.gg/rainware"
local PROFILE_API = "https://rainware.rainware.xyz/api/discord/profile"
local KICK_CHECK = "https://rainware.rainware.xyz/api/session/kick-check"
local SESS = "rainware_session.dat"
local VERSION = "v1.0.0"
local BUILD_ID = "RW1"

local function httpRequest(opts)
	local candidates = {}
	local function add(fn)
		if isFn(fn) then candidates[#candidates + 1] = fn end
	end
	pcall_(function() if type_(syn) == "table" then add(syn.request) end end)
	pcall_(function() if type_(http) == "table" then add(http.request) end end)
	pcall_(function() add(http_request) end)
	pcall_(function() add(request) end)
	local last = "no_request"
	for i = 1, #candidates do
		local ok, res = pcall_(candidates[i], opts)
		if ok and res ~= nil then
			if type_(res) == "table" then
				if res.Body == nil and res.body ~= nil then res.Body = res.body end
				return res
			elseif type_(res) == "string" then
				return { Body = res, StatusCode = 200 }
			end
		else
			last = tostring_(res)
		end
	end
	return nil, last
end

local function httpGet(url, timeout)
	timeout = timeout or 16
	local done, body, err = false, nil, nil
	task_spawn(function()
		local ok, res = pcall_(function() return game_:HttpGet(url) end)
		if ok and type_(res) == "string" and #res > 0 then
			body = res
		else
			local r, e = httpRequest({ Url = url, Method = "GET" })
			if r and type_(r.Body) == "string" then body = r.Body else err = e or tostring_(res) end
		end
		done = true
	end)
	local t0 = os_clock()
	while not done and (os_clock() - t0) < timeout do task_wait(0.05) end
	if not done then return nil, "timeout" end
	if type_(body) ~= "string" then return nil, err or "empty" end
	return body
end

local function readSession()
	if not isFn(readfile) or not isFn(isfile) then return nil end
	local ok, exists = pcall_(isfile, SESS)
	if not ok or not exists then return nil end
	local ok2, raw = pcall_(readfile, SESS)
	if not ok2 or type_(raw) ~= "string" then return nil end
	local parts = {}
	for part in string.gmatch(raw, "[^|]+") do parts[#parts + 1] = part end
	if #parts < 3 or parts[1] ~= player.Name then return nil end
	local exp = tonumber_(parts[3]) or 0
	if exp > 0 and exp < os_time() then return nil end
	local entered = tonumber_(parts[4]) or 0
	return { key = parts[2], expires = exp, plan = parts[5], discord = parts[6], entered = entered }
end

local function writeSession(key, exp, plan, discord)
	if not isFn(writefile) then return end
	pcall_(writefile, SESS, join({
		player.Name, tostring_(key), tostring_(exp or 0), tostring_(os_time()),
		tostring_(plan or "day"), tostring_(discord or ""),
	}, "|"))
end

local KICK_MSG = "Incorrect key/caught bypassing"
local function getHwid()
	local hwid = nil
	pcall_(function() if isFn(gethwid) then hwid = gethwid() end end)
	return hwid
end

-- 5.2.1: no keyring. Gate shows every execute; session only prefills <24h.
local function readKeyring() return {} end
local function writeKeyring(keys) end

-- keys: array with the entered license key. Server picks highest valid plan.
-- server picks the highest valid plan. Returns ok, reason, data, msg.
-- ok=false means: keys were given but none usable -> caller must kick.
local function validateKeyOnline(keys)
	local bodyJson = HttpService:JSONEncode({
		keys = keys,
		username = player.Name,
		user_id = tostring_(player.UserId),
		roblox_id = tostring_(player.UserId),
		discord_id = GENV.RainLinkDiscordId,
		hwid = getHwid(),
	})
	local res, err = httpRequest({
		Url = VALIDATE, Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = bodyJson,
	})
	if not res then return false, err or "connection_failed", nil end
	local data
	local ok = pcall_(function() data = HttpService:JSONDecode(tostring_(res.Body or "")) end)
	if not ok or type_(data) ~= "table" then return false, "invalid_response", nil end
	if data.valid == true then return true, nil, data end
	local reason = tostring_(data.reason or "invalid_key")
	local msg = data.message
	if reason == "banned" then msg = msg or "You are banned from Rainware"
	elseif reason == "username_mismatch" then msg = msg or "Key bound to another Roblox account"
	elseif reason == "expired" then msg = msg or "Key expired"
	elseif reason == "revoked" then msg = msg or "Key revoked"
	elseif reason == "hwid_mismatch" then msg = msg or "Key bound to another machine (/reset-hwid)"
	end
	return false, reason, data, msg
end

local function kickBadKey()
	pcall_(function() player:Kick(KICK_MSG) end)
	error("[Loader] " .. KICK_MSG, 0)
end

local function parentGui(sg)
	local ok = pcall_(function() sg.Parent = game_:GetService("CoreGui") end)
	if not ok then sg.Parent = player:WaitForChild("PlayerGui") end
end

local function startBanPoll(key)
	task_spawn(function()
		local function poll()
			local hw = getHwid() or ""
			local qs = "?userId=" .. tostring_(player.UserId)
				.. "&username=" .. HttpService:UrlEncode(player.Name)
				.. "&key=" .. HttpService:UrlEncode(tostring_(key or ""))
				.. "&hwid=" .. HttpService:UrlEncode(tostring_(hw))
			local res = httpRequest({ Url = KICK_CHECK .. qs, Method = "GET" })
			if not res or not res.Body then return end
			local data
			pcall_(function() data = HttpService:JSONDecode(tostring_(res.Body)) end)
			if type_(data) == "table" and (data.kick or data.banned) then
				pcall_(function() player:Kick(tostring_(data.reason or "Banned / kicked from Rainware")) end)
			end
		end
		poll()
		while task_wait(6) do pcall_(poll) end
	end)
end

local GH_LOGO_URL = "https://raw.githubusercontent.com/purrguy/rainware/main/logo.png"
local GH_LOGO_FILE = "gh_logo.png"

local function ensureGreedyLogo()
	if _G.__ghLogoAsset and type_(_G.__ghLogoAsset) == "string" then return _G.__ghLogoAsset end
	local asset = nil
	pcall_(function()
		if isFn(readfile) and isFn(isfile) and isfile(GH_LOGO_FILE) then
			if isFn(getcustomasset) then asset = getcustomasset(GH_LOGO_FILE) end
		end
	end)
	if (not asset) and isFn(writefile) then
		pcall_(function()
			local res = httpRequest({ Url = GH_LOGO_URL, Method = "GET" })
			local bytes = res and (res.Body or res.body)
			if type_(bytes) == "string" and #bytes > 200 then
				writefile(GH_LOGO_FILE, bytes)
				if isFn(getcustomasset) then asset = getcustomasset(GH_LOGO_FILE) end
			end
		end)
	end
	if type_(asset) == "string" then _G.__ghLogoAsset = asset end
	return asset
end

local function showKeyGate(prefill)
	local resultKey, resultData = nil, nil
	local done, closed = false, false
	local sg = Instance_.new("ScreenGui")
	sg.Name = "CL_KeyGate"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 1000
	parentGui(sg)

	local dim = Instance_.new("Frame")
	dim.Size = UDim2_.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3_.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = sg

	local card = Instance_.new("Frame")
	card.Size = UDim2_.new(0, 360, 0, 236)
	card.Position = UDim2_.new(0.5, -180, 0.5, -118)
	card.BackgroundColor3 = Color3_.fromRGB(12, 14, 18)
	card.BorderSizePixel = 0
	card.Active = true
	card.Parent = dim
	Instance_.new("UICorner", card).CornerRadius = UDim_.new(0, 12)
	local stroke = Instance_.new("UIStroke")
	stroke.Color = Color3_.fromRGB(66, 165, 245)
	stroke.Thickness = 1
	stroke.Parent = card

	-- draggable by the title bar
	local dragBar = Instance_.new("Frame")
	dragBar.BackgroundTransparency = 1
	dragBar.Size = UDim2_.new(1, -40, 0, 52)
	dragBar.Position = UDim2_.new(0, 0, 0, 0)
	dragBar.Parent = card
	do
		local dragging, dragStart, origin = false, nil, nil
		dragBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum_.UserInputType.MouseButton1 or input.UserInputType == Enum_.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				origin = card.Position
			end
		end)
		local uis = game_:GetService("UserInputService")
		uis.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum_.UserInputType.MouseMovement and input.UserInputType ~= Enum_.UserInputType.Touch then return end
			local delta = input.Position - dragStart
			card.Position = UDim2_.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end)
		uis.InputEnded:Connect(function(input)
			if input.UserInputType == Enum_.UserInputType.MouseButton1 or input.UserInputType == Enum_.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- logo (downloaded + cached)
	local logo = Instance_.new("ImageLabel")
	logo.BackgroundTransparency = 1
	logo.Size = UDim2_.new(0, 30, 0, 30)
	logo.Position = UDim2_.new(0, 12, 0, 12)
	logo.Image = ""
	logo.Parent = card
	Instance_.new("UICorner", logo).CornerRadius = UDim_.new(0, 8)
	task_spawn(function()
		local a = ensureGreedyLogo()
		if type_(a) == "string" then logo.Image = a end
	end)

	local title = Instance_.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2_.new(1, -100, 0, 24)
	title.Position = UDim2_.new(0, 48, 0, 12)
	title.Font = Enum_.Font.GothamBold
	title.TextSize = 17
	title.TextColor3 = Color3_.fromRGB(200, 225, 255)
	title.TextXAlignment = Enum_.TextXAlignment.Left
	title.Text = "Rainware"
	title.Parent = card

	local ver = Instance_.new("TextLabel")
	ver.BackgroundTransparency = 1
	ver.Size = UDim2_.new(1, -100, 0, 14)
	ver.Position = UDim2_.new(0, 48, 0, 36)
	ver.Font = Enum_.Font.Gotham
	ver.TextSize = 11
	ver.TextColor3 = Color3_.fromRGB(120, 150, 190)
	ver.TextXAlignment = Enum_.TextXAlignment.Left
	ver.Text = "v1.0.0"
	ver.Parent = card

	-- close button: closes the gate (loader aborts, no key set)
	local close = Instance_.new("TextButton")
	close.Size = UDim2_.new(0, 26, 0, 26)
	close.Position = UDim2_.new(1, -32, 0, 6)
	close.BackgroundColor3 = Color3_.fromRGB(30, 36, 48)
	close.Text = "X"
	close.TextColor3 = Color3_.fromRGB(150, 200, 245)
	close.Font = Enum_.Font.GothamBold
	close.TextSize = 13
	close.Parent = card
	Instance_.new("UICorner", close).CornerRadius = UDim_.new(0, 6)
	close.Activated:Connect(function()
		closed = true
		done = true
		pcall_(function() sg:Destroy() end)
	end)

	local hint = Instance_.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2_.new(1, -24, 0, 32)
	hint.Position = UDim2_.new(0, 12, 0, 56)
	hint.Font = Enum_.Font.Gotham
	hint.TextSize = 12
	hint.TextColor3 = Color3_.fromRGB(140, 170, 200)
	hint.TextXAlignment = Enum_.TextXAlignment.Left
	hint.TextYAlignment = Enum_.TextYAlignment.Top
	hint.TextWrapped = true
	hint.Text = "Activate key in Discord, then enter it here."
	hint.Parent = card

	local box = Instance_.new("TextBox")
	box.Size = UDim2_.new(1, -24, 0, 36)
	box.Position = UDim2_.new(0, 12, 0, 96)
	box.BackgroundColor3 = Color3_.fromRGB(20, 26, 34)
	box.TextColor3 = Color3_.fromRGB(235, 245, 255)
	box.PlaceholderText = "RW-XXXX-XXXX-XXXX"
	box.PlaceholderColor3 = Color3_.fromRGB(110, 140, 170)
	box.Font = Enum_.Font.Gotham
	box.TextSize = 14
	box.ClearTextOnFocus = false
	-- prefill with the latest known key (24h re-entry = press LOAD, or paste a testing key over it)
	box.Text = tostring_(prefill or "")
	box.Parent = card
	Instance_.new("UICorner", box).CornerRadius = UDim_.new(0, 8)

	local status = Instance_.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Size = UDim2_.new(1, -24, 0, 20)
	status.Position = UDim2_.new(0, 12, 0, 136)
	status.Font = Enum_.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3_.fromRGB(220, 100, 100)
	status.TextXAlignment = Enum_.TextXAlignment.Left
	status.Text = ""
	status.Parent = card

	local go = Instance_.new("TextButton")
	go.Size = UDim2_.new(0.48, -8, 0, 34)
	go.Position = UDim2_.new(0, 12, 1, -48)
	go.BackgroundColor3 = Color3_.fromRGB(66, 165, 245)
	go.Text = "UNLOCK"
	go.TextColor3 = Color3_.fromRGB(8, 14, 22)
	go.Font = Enum_.Font.GothamBold
	go.TextSize = 14
	go.Parent = card
	Instance_.new("UICorner", go).CornerRadius = UDim_.new(0, 8)

	local get = Instance_.new("TextButton")
	get.Size = UDim2_.new(0.48, -8, 0, 34)
	get.Position = UDim2_.new(0.52, 0, 1, -48)
	get.BackgroundColor3 = Color3_.fromRGB(28, 36, 48)
	get.Text = "Get key / Discord"
	get.TextColor3 = Color3_.fromRGB(200, 225, 255)
	get.Font = Enum_.Font.Gotham
	get.TextSize = 12
	get.Parent = card
	Instance_.new("UICorner", get).CornerRadius = UDim_.new(0, 8)

	local busy = false
	local badTries = 0
	go.Activated:Connect(function()
		if busy then return end
		local key = box.Text:gsub("%s+", "")
		if key == "" then status.Text = "Enter a key" return end
		busy = true
		go.Text = "..."
		status.Text = "Checking..."
		status.TextColor3 = Color3_.fromRGB(150, 200, 245)
		task_spawn(function()
			-- gate always submits an array (server expects a list)
			local ok, reason, data, msg = validateKeyOnline({ key })
			if ok then
				resultKey, resultData = key, data
				done = true
				sg:Destroy()
			else
				badTries = badTries + 1
				if badTries >= 3 then
					sg:Destroy()
					kickBadKey()
					return
				end
				status.TextColor3 = Color3_.fromRGB(220, 100, 100)
				status.Text = tostring_(msg or reason or "failed") .. " (" .. badTries .. "/3)"
				go.Text = "UNLOCK"
				busy = false
			end
		end)
	end)
	get.Activated:Connect(function()
		pcall_(function() if isFn(setclipboard) then setclipboard(DISCORD) end end)
		status.TextColor3 = Color3_.fromRGB(110, 220, 160)
		status.Text = "Discord invite copied"
	end)
	while not done do task_wait(0.05) end
	if closed then return nil, nil end
	return resultKey, resultData
end
-- ==================== END 5.2.0 KEY GATE ====================

local LoadUI = { gui = nil, bar = nil, pct = nil, stage = nil }

local function createLoadGui()
	local sg = Instance_.new("ScreenGui")
	sg.Name = "CL_Load"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 999
	parentGui(sg)
	local dim = Instance_.new("Frame")
	dim.Size = UDim2_.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3_.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Parent = sg
	local card = Instance_.new("Frame")
	card.Size = UDim2_.new(0, 300, 0, 110)
	card.Position = UDim2_.new(0.5, -150, 0.5, -55)
	card.BackgroundColor3 = Color3_.fromRGB(12, 14, 18)
	card.BorderSizePixel = 0
	card.Parent = dim
	Instance_.new("UICorner", card).CornerRadius = UDim_.new(0, 12)
	local stage = Instance_.new("TextLabel")
	stage.BackgroundTransparency = 1
	stage.Size = UDim2_.new(1, -20, 0, 22)
	stage.Position = UDim2_.new(0, 10, 0, 14)
	stage.Font = Enum_.Font.Gotham
	stage.TextSize = 13
	stage.TextColor3 = Color3_.fromRGB(200, 225, 255)
	stage.TextXAlignment = Enum_.TextXAlignment.Left
	stage.Text = "Starting..."
	stage.Parent = card
	local track = Instance_.new("Frame")
	track.Size = UDim2_.new(1, -20, 0, 10)
	track.Position = UDim2_.new(0, 10, 0, 50)
	track.BackgroundColor3 = Color3_.fromRGB(24, 30, 40)
	track.BorderSizePixel = 0
	track.Parent = card
	Instance_.new("UICorner", track).CornerRadius = UDim_.new(0, 6)
	local bar = Instance_.new("Frame")
	bar.Size = UDim2_.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3_.fromRGB(66, 165, 245)
	bar.BorderSizePixel = 0
	bar.Parent = track
	Instance_.new("UICorner", bar).CornerRadius = UDim_.new(0, 6)
	local pct = Instance_.new("TextLabel")
	pct.BackgroundTransparency = 1
	pct.Size = UDim2_.new(1, -20, 0, 20)
	pct.Position = UDim2_.new(0, 10, 0, 72)
	pct.Font = Enum_.Font.GothamBold
	pct.TextSize = 12
	pct.TextColor3 = Color3_.fromRGB(140, 170, 200)
	pct.TextXAlignment = Enum_.TextXAlignment.Left
	pct.Text = "0%"
	pct.Parent = card
	LoadUI.gui, LoadUI.bar, LoadUI.pct, LoadUI.stage = sg, bar, pct, stage
end

local function setProgress(p, text)
	p = math_min(1, math_max(0, p))
	if LoadUI.bar then LoadUI.bar.Size = UDim2_.new(p, 0, 1, 0) end
	if LoadUI.pct then LoadUI.pct.Text = tostring_(math_floor(p * 100)) .. "%" end
	if text and LoadUI.stage then LoadUI.stage.Text = text end
end

local function fail(stage, err)
	warn("[Loader] FAIL:", stage, err)
	if LoadUI.stage then LoadUI.stage.Text = "Failed: " .. tostring_(stage) end
	if LoadUI.pct then LoadUI.pct.Text = tostring_(err or "") end
	pcall_(function() if isFn(setclipboard) then setclipboard(DISCORD) end end)
	GENV.RainLinkLoader_Running = false
end

print("[Loader] boot")

-- 5.2.1: gate shows EVERY execute. Session only prefills the box <24h after
-- entry; after 24h the user types the key again. No free mode, no offline mode.
local prefill = ""
do
	local sess = readSession()
	-- prefill only <24h after entry; older = type it again
	if sess and sess.key and sess.key ~= "" and sess.entered > 0
		and (os_time() - sess.entered) < 24 * 60 * 60 then
		prefill = sess.key
		print("[Loader] session key found, prefilling gate")
	end
end
print("[Loader] key gate")
local gateKey, gateData = showKeyGate(prefill)
if not gateKey or not gateData then
	fail("key", "closed")
	return
end
local data = gateData
local keys = { gateKey }
print("[Loader] key OK (" .. tostring_(data.plan or "?") .. ")")

print("[Loader] publish session")
local activeKey = data.key or ""
GENV.RainLinkKey = activeKey
GENV.RainwareKey = activeKey
GENV.RainLinkKeys = keys
GENV.RainLinkPlan = data.plan or "free"
GENV.RainLinkExpires = data.expires_at or data.expiresAt
GENV.RainLinkDiscordId = data.discord_id
GENV.RainLinkPaid = data.paid == true or data.rewire_allowed == true
GENV.RainLinkHwidFree = data.hwid_free == true
GENV.RainLinkVerified = data.member_verified == true
GENV.RainLinkTesting = data.testing == true
GENV.RainLinkFromLoader = true
GENV.RainLinkLoader_Done = true
GENV.RainLinkBuild = BUILD_ID
GENV.RainLinkVersion = VERSION
GENV.RainwareLoaderBuild = "RW-1.0.0"
GENV.RainwareOfficial = true
GENV.RainwareLoader_Done = true
GENV.RainwareFromLoader = true
GENV.RainwareSkipStrictAuth = true
GENV.RainwareKeyPlan = GENV.RainLinkPlan
GENV.RainwareKeyExpires = GENV.RainLinkExpires
GENV.RainwareHwid = getHwid()
-- one-time handshake for the hub
GENV.RainwareNonce = tostring_(math_floor(os_clock() * 1000)) .. "-" .. tostring_(math_floor(math.random() * 1e9))
GENV.RainwareHandshakeAt = os_clock()
if activeKey ~= "" then
	pcall_(writeSession, activeKey, GENV.RainLinkExpires, GENV.RainLinkPlan, GENV.RainLinkDiscordId)
end
task_spawn(function()
	pcall_(function()
		httpRequest({
			Url = "https://rainware.rainware.xyz/api/session/exec", Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({ key = tostring_(activeKey), username = player.Name, user_id = tostring_(player.UserId) }),
		})
	end)
end)
startBanPoll(activeKey)
task_wait()

if data.discord_id and tostring_(data.discord_id) ~= "" then
	task_spawn(function()
		pcall_(function()
			local res = httpRequest({
				Url = PROFILE_API, Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({ discord_id = tostring_(data.discord_id) }),
			})
			if res and res.Body then
				local prof = HttpService:JSONDecode(res.Body)
				if type_(prof) == "table" and prof.ok then
					GENV.RainLinkDiscordName = prof.username or prof.global_name
					GENV.RainLinkAvatarUrl = prof.avatar_url
				end
			end
		end)
	end)
end

createLoadGui()
setProgress(0.05, "Key OK")
task_wait(0.1)

setProgress(0.12, "UI library...")
local okLib = true

setProgress(0.35, "Fetching hub...")
if type_(data) == "table" and data.testing == true then
	setProgress(0.35, "Testing build...")
end
-- 5.2.0: hub source ships inside the /validate response (private repo,
-- fetched server-side). Nothing to download, nothing to leak.
local src = type_(data) == "table" and data.script or nil
if type_(src) ~= "string" or #src < 40 then
	fail("download", (type_(data) == "table" and data.script_error) or "hub not published yet")
	return
end
setProgress(0.55, "Received (" .. tostring_(#src) .. ")")
local headchk = str_lower(str_sub(src, 1, 40))
if str_find(headchk, "<!doctype", 1, true) or str_find(headchk, "<html", 1, true) then
	fail("download", "not lua (html)")
	return
end

setProgress(0.62, "Compiling hub...")
local fn, cerr = loadstring(src)
if not fn then
	fail("compile", tostring_(cerr))
	return
end
setProgress(0.75, "Compile OK")
task_wait(0.1)

_G.rainwareAlive = true
pcall(function() if getgenv then getgenv().rainwareAlive = true end end)
setProgress(0.8, "Starting hub...")
local hubDone, hubErr = false, nil
task_spawn(function()
	task_wait(0.05)
	local okRun, runErr = pcall_(fn)
	if not okRun then hubErr = runErr end
	hubDone = true
end)
local t0 = os_clock()
local spin = 0.8
while not hubDone and (os_clock() - t0) < 90 do
	spin = math_min(0.97, spin + 0.004)
	setProgress(spin, "Starting hub...")
	task_wait(0.1)
end
if not hubDone then fail("runtime", "hub start timeout 90s") return end
if hubErr then fail("runtime", hubErr) return end

setProgress(1, "Ready")
task_wait(0.35)
if LoadUI.gui then pcall_(function() LoadUI.gui:Destroy() end) end
GENV.RainLinkLoader_Running = false
print("[Loader] done")
