--[[
	RainWare UI Library v2.1.0
	==========================
	Everveil-styled UI library for RainWare scripts.

	local RainWare = loadstring(game:HttpGet("https://raw.githubusercontent.com/purrguy/rainware/main/library.lua"))()
	local win = RainWare:CreateWindow({
		Title = "RainWare : Fisch",
		Size = UDim2.fromOffset(620, 560),
		ToggleKey = Enum.KeyCode.RightShift,
		DefaultTab = "Autofarm",
	})
	local tab = win:CreateTab({ Title = "Autofarm" })
	tab:CreateSection("Automation")
	tab:CreateToggle({ Title = "Auto Fish", Default = true, Flag = "af_auto" })
	tab:CreateSlider({ Title = "Power", Min = 0, Max = 100, Default = 95, Flag = "af_power" })
	tab:CreateDropdown({ Title = "Mode", Values = {"Slow","Normal","Instant"}, Default = "Normal", Flag = "af_mode" })
	tab:CreateButton({ Title = "Sell", Callback = function() end })
	RainWare:Notify({ Title = "RainWare", Content = "Loaded" })
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local RainWare = {}
RainWare.__index = RainWare
RainWare.Flags = {}
RainWare.Options = {}
RainWare.Version = "2.1.0"

local COL = {
	bg = Color3.fromRGB(10, 18, 30),
	panel = Color3.fromRGB(18, 34, 54),
	card = Color3.fromRGB(24, 44, 68),
	cardHi = Color3.fromRGB(30, 54, 82),
	stroke = Color3.fromRGB(40, 66, 96),
	text = Color3.fromRGB(225, 240, 255),
	dim = Color3.fromRGB(135, 165, 195),
	accent = Color3.fromRGB(90, 170, 255),
	good = Color3.fromRGB(96, 220, 150),
	bad = Color3.fromRGB(255, 110, 120),
}

local FONT = Enum.Font.Gotham
local FONTB = Enum.Font.GothamBold
local FONTS = Enum.Font.GothamSemibold
local FONTC = Enum.Font.Code

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(inst, r)
	mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, inst)
	return inst
end

local function stroke(inst, color, transparency, thickness)
	mk("UIStroke", {
		Color = color or COL.stroke,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
	return inst
end

local function pad(inst, l, r, t, b)
	mk("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
	}, inst)
	return inst
end

local function label(parent, text, size, color, font, textSize)
	return mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Font = font or FONT,
		TextSize = textSize or 12,
		TextColor3 = color or COL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text or "",
		Parent = parent,
	})
end

local function guiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end
	local ok2, pg = pcall(function()
		return LP:FindFirstChildOfClass("PlayerGui")
	end)
	return ok2 and pg or CoreGui
end

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

-- Value formatting used by sliders and paragraphs.
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

local function tweenColor(obj, prop, value, dur)
	pcall(function()
		TweenService:Create(obj, TweenInfo.new(dur or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [prop] = value }):Play()
	end)
end

local function hover(btn, base, hot)
	btn.MouseEnter:Connect(function()
		tweenColor(btn, "BackgroundColor3", hot)
	end)
	btn.MouseLeave:Connect(function()
		tweenColor(btn, "BackgroundColor3", base)
	end)
end

----------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------

function RainWare:CreateWindow(cfg)
	cfg = cfg or {}
	local win = setmetatable({
		Title = cfg.Title or "RainWare",
		SubTitle = cfg.SubTitle or "",
		_tabs = {},
		_current = nil,
		_conns = {},
		_started = os.clock(),
	}, { __index = self })

	local screen = mk("ScreenGui", {
		Name = "RainWareUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = guiParent(),
	})
	win._gui = screen

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local autoSize = UDim2.fromOffset(
		math.clamp(math.floor(viewport.X * 0.32), 520, 600),
		math.clamp(math.floor(viewport.Y * 0.46), 380, 470)
	)

	local panel = mk("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = cfg.Size or autoSize,
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = screen,
	})
	corner(panel, 8)
	stroke(panel, COL.stroke, 0.25, 1)
	local panelScale = mk("UIScale", { Scale = 1 }, panel)
	win._panel = panel

	-- Everveil header: 34px bar, thin divider, title left.
	local top = mk("TextButton", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = panel,
	})
	local title = label(top, cfg.Title or "RainWare", UDim2.new(1, -60, 1, 0), COL.text, FONTB, 14)
	title.Position = UDim2.fromOffset(12, 0)

	local close = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = COL.bg,
		Text = "x",
		Font = FONTB,
		TextSize = 12,
		TextColor3 = COL.dim,
		AutoButtonColor = false,
		Parent = top,
	})
	corner(close, 5)
	close.Activated:Connect(function()
		win:Toggle(false)
	end)
	close.MouseEnter:Connect(function()
		close.BackgroundColor3 = COL.cardHi
		close.TextColor3 = COL.text
	end)
	close.MouseLeave:Connect(function()
		close.BackgroundColor3 = COL.bg
		close.TextColor3 = COL.dim
	end)

	mk("Frame", {
		Size = UDim2.new(1, -16, 0, 1),
		Position = UDim2.new(0, 8, 1, -1),
		BackgroundColor3 = COL.dim,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Parent = top,
	})

	-- Sidebar (114px) + content panel, exactly like Everveil.
	local sidebar = mk("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 114, 1, -74),
		Position = UDim2.new(0, 8, 0, 40),
		BackgroundColor3 = COL.bg,
		BorderSizePixel = 0,
		Parent = panel,
	})
	corner(sidebar, 6)
	mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
	pad(sidebar, 8, 8, 8, 8)

	local content = mk("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -138, 1, -74),
		Position = UDim2.new(0, 130, 0, 40),
		BackgroundColor3 = COL.bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})
	corner(content, 6)
	win._content = content

	local footer = mk("Frame", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = panel,
	})
	local statusBar = label(footer, "RainWare v" .. RainWare.Version, UDim2.new(1, -16, 1, 0), COL.dim, FONTC, 11)
	statusBar.Position = UDim2.fromOffset(4, 0)
	local hint = label(footer, "", UDim2.new(0, 180, 1, 0), COL.dim, FONTC, 11)
	hint.Position = UDim2.new(1, -184, 0, 0)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.Text = tostring((cfg.ToggleKey or Enum.KeyCode.RightShift).Name) .. " to toggle"
	win._status = statusBar

	-- Notifications column: pinned bottom-right, so it never covers the window.
	local notifHolder = mk("Frame", {
		Name = "Notifs",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(248, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	})
	notifHolder:SetAttribute("RainWareNotifs", true)
	mk("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, notifHolder)
	win._notifs = notifHolder
	RainWare._activeNotifHolder = notifHolder

	-- Dragging by the header.
	do
		local dragging, startInput, startPos = false, nil, nil
		top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startInput = input.Position
				startPos = panel.Position
				for _, list in ipairs(win._dropdownLists or {}) do
					list.Visible = false
				end
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = input.Position - startInput
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end)
		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- Toggle key. Ignore only while a TextBox has focus; the game marks most
	-- keypresses as gameProcessed, so requiring gp == false breaks this.
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	table.insert(win._conns, UIS.InputBegan:Connect(function(input)
		if input.KeyCode ~= toggleKey then
			return
		end
		if UIS:GetFocusedTextBox() then
			return
		end
		win:Toggle()
	end))

	win._dropdownLists = {}

	function win:CreateTab(tabCfg)
		tabCfg = tabCfg or {}
		local name = tabCfg.Title or ("Tab " .. (#self._tabs + 1))
		local index = #self._tabs + 1

		local btn = mk("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = COL.panel,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = tabCfg.Order or index,
			Parent = sidebar,
		})
		corner(btn, 5)
		pad(btn, 10, 6, 0, 0)
		local bar = mk("Frame", {
			Size = UDim2.new(0, 2, 1, -10),
			Position = UDim2.new(0, 0, 0, 5),
			BackgroundColor3 = COL.accent,
			BorderSizePixel = 0,
			Visible = false,
			Parent = btn,
		})
		corner(bar, 1)
		local nameLbl = label(btn, name, UDim2.new(1, -12, 1, 0), COL.dim, FONT, 12)
		nameLbl.Position = UDim2.fromOffset(4, 0)

		local scroll = mk("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = COL.accent,
			ScrollBarImageTransparency = 0.2,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			Parent = content,
		})
		mk("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, scroll)
		pad(scroll, 8, 12, 8, 16)

		local tab = {
			Title = name,
			Index = index,
			_frame = scroll,
			_button = btn,
			_window = self,
			_target = scroll,
			_orders = {},
		}

		function tab:_next()
			local target = self._target or self._frame
			local n = (self._orders[target] or 0) + 1
			self._orders[target] = n
			return n
		end

		function tab:_parent()
			return self._target or self._frame
		end

		function tab:Select()
			self._window:SelectTab(self.Index)
		end

		function tab:CreateSection(text)
			local section = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = COL.bg,
				BorderSizePixel = 0,
				LayoutOrder = self:_next(),
				Parent = self:_parent(),
			})
			corner(section, 6)
			mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, section)
			pad(section, 4, 4, 4, 4)

			local header = mk("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = 1,
				Parent = section,
			})
			corner(header, 5)
			local arrow = label(header, "v", UDim2.fromOffset(16, 28), COL.accent, FONTB, 12)
			arrow.Position = UDim2.fromOffset(8, 0)
			arrow.TextXAlignment = Enum.TextXAlignment.Center
			local titleLbl = label(header, tostring(text or "Section"), UDim2.new(1, -32, 1, 0), COL.text, FONTS, 12)
			titleLbl.Position = UDim2.fromOffset(26, 0)

			local body = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Parent = section,
			})
			mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
			pad(body, 2, 2, 2, 2)

			local sectionObj = {
				Frame = section,
				Body = body,
				Header = header,
				Orders = {},
			}
			local function setExpanded(v)
				body.Visible = v and true or false
				arrow.Text = body.Visible and "v" or ">"
				arrow.TextColor3 = body.Visible and COL.accent or COL.dim
			end
			setExpanded(true)
			header.Activated:Connect(function()
				setExpanded(not body.Visible)
			end)
			hover(header, COL.panel, COL.card)

			self._target = body
			self._orders[body] = 0
			if self._sections then
				table.insert(self._sections, sectionObj)
			else
				self._sections = { sectionObj }
			end
			return section
		end

		function tab:CreateDivider()
			local holder = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 9),
				BackgroundTransparency = 1,
				LayoutOrder = self:_next(),
				Parent = self:_parent(),
			})
			mk("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = COL.stroke,
				BorderSizePixel = 0,
				Parent = holder,
			})
			return holder
		end

		function tab:CreateParagraph(p)
			p = p or {}
			local card = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				LayoutOrder = self:_next(),
				Parent = self:_parent(),
			})
			corner(card, 5)
			pad(card, 9, 9, 7, 7)
			mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, card)
			local titleLbl = nil
			if p.Title then
				titleLbl = label(card, tostring(p.Title), UDim2.new(1, 0, 0, 16), COL.text, FONTS, 12)
			end
			local bodyLbl = label(card, tostring(p.Content or ""), UDim2.new(1, 0, 0, 0), COL.dim, FONT, 11)
			bodyLbl.TextWrapped = true
			bodyLbl.AutomaticSize = Enum.AutomaticSize.Y

			local api = { Frame = card }
			function api:SetContent(text)
				bodyLbl.Text = tostring(text or "")
			end
			function api:SetTitle(text)
				if titleLbl then
					titleLbl.Text = tostring(text or "")
				end
			end
			return api
		end

		-- Shared row builder: rounded panel with title + optional description.
		local function rowCard(titleText, descText, height, descHeight)
			local card = mk("Frame", {
				Size = UDim2.new(1, 0, 0, height),
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				LayoutOrder = tab:_next(),
				Parent = tab:_parent(),
			})
			corner(card, 5)
			local hit = mk("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = card,
			})
			local t = label(card, tostring(titleText), UDim2.new(1, -20, 0, descText and 18 or height), COL.text, FONT, 12)
			t.Position = UDim2.fromOffset(10, descText and 5 or 0)
			if descText and descText ~= "" then
				local d = label(card, tostring(descText), UDim2.new(1, -20, 0, 15), COL.dim, FONT, 10)
				d.Position = UDim2.fromOffset(10, descHeight or 23)
				d.TextTruncate = Enum.TextTruncate.AtEnd
			end
			return card, hit, t
		end

		function tab:CreateButton(b)
			b = b or {}
			local hasDesc = b.Description ~= nil and tostring(b.Description) ~= ""
			local card, hit = rowCard(b.Title or "Button", b.Description or "", hasDesc and 42 or 28, hasDesc and 21 or 20)
			hover(hit, Color3.new(), Color3.new())
			hit.MouseEnter:Connect(function()
				card.BackgroundColor3 = COL.card
			end)
			hit.MouseLeave:Connect(function()
				card.BackgroundColor3 = COL.panel
			end)
			hit.Activated:Connect(function()
				if type(b.Callback) == "function" then
					local ok, err = pcall(b.Callback)
					if not ok then
						RainWare:Notify({ Title = "Error", Content = tostring(err), Duration = 5 })
					end
				end
			end)
			return card
		end

		function tab:CreateToggle(t)
			t = t or {}
			local flag = t.Flag
			local state = t.Default and true or false
			local hasDesc = t.Description ~= nil and tostring(t.Description) ~= ""
			local card, hit, titleLbl = rowCard(t.Title or "Toggle", t.Description or "", hasDesc and 42 or 28, hasDesc and 21 or 20)
			titleLbl.Size = UDim2.new(1, -56, 0, hasDesc and 17 or card.Size.Y.Offset)

			local pill = mk("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0, hasDesc and 12 or 14),
				Size = UDim2.fromOffset(30, 15),
				BackgroundColor3 = COL.cardHi,
				BorderSizePixel = 0,
				Parent = card,
			})
			corner(pill, 8)
			local knob = mk("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(11, 11),
				BackgroundColor3 = COL.dim,
				BorderSizePixel = 0,
				Parent = pill,
			})
			corner(knob, 6)

			local function render()
				pill.BackgroundColor3 = state and COL.accent or COL.cardHi
				knob.BackgroundColor3 = state and COL.text or COL.dim
				knob.Position = UDim2.new(0, state and 17 or 2, 0.5, 0)
			end

			local api = { Flag = flag, Title = t.Title }
			function api:Get()
				return state
			end
			function api:Set(v)
				v = v and true or false
				state = v
				render()
				if flag then RainWare.Flags[flag] = v end
				if type(t.Callback) == "function" then pcall(t.Callback, v) end
			end

			hit.Activated:Connect(function()
				api:Set(not state)
			end)
			render()

			if flag then
				RainWare.Flags[flag] = state
				RainWare.Options[flag] = api
			end
			if type(t.Callback) == "function" and t.Default then
				task.defer(function() pcall(t.Callback, state) end)
			end
			return api
		end

		function tab:CreateSlider(s)
			s = s or {}
			local flag = s.Flag
			local minV = tonumber(s.Min) or 0
			local maxV = tonumber(s.Max) or 100
			local inc = tonumber(s.Increment) or tonumber(s.Step) or 1
			if inc <= 0 then inc = 1 end
			local value = tonumber(s.Default) or minV
			local suffix = tostring(s.Suffix or "")

			local row = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				LayoutOrder = self:_next(),
				Parent = self:_parent(),
			})
			local nameL = label(row, tostring(s.Title or "Slider"), UDim2.new(1, -70, 0, 15), COL.dim, FONT, 11)
			local valueL = label(row, "", UDim2.new(0, 64, 0, 15), COL.accent, FONTS, 11)
			valueL.Position = UDim2.new(1, -64, 0, 0)
			valueL.TextXAlignment = Enum.TextXAlignment.Right

			local track = mk("Frame", {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				Parent = row,
			})
			corner(track, 4)
			local fill = mk("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = COL.accent,
				BorderSizePixel = 0,
				Parent = track,
			})
			corner(fill, 4)
			local grab = mk("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = COL.text,
				BorderSizePixel = 0,
				Parent = track,
			})
			corner(grab, 5)
			local hit = mk("TextButton", {
				Position = UDim2.fromOffset(0, -4),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = track,
			})

			local api = { Flag = flag, Title = s.Title }
			local function render()
				local a = (value - minV) / math.max(0.0001, maxV - minV)
				a = math.clamp(a, 0, 1)
				fill.Size = UDim2.fromScale(a, 1)
				grab.Position = UDim2.new(a, 0, 0.5, 0)
				valueL.Text = fmtNum(value, inc) .. suffix
			end
			function api:Get()
				return value
			end
			function api:Set(v)
				v = math.clamp(tonumber(v) or minV, minV, maxV)
				v = math.floor(v / inc + 0.5) * inc
				value = math.clamp(v, minV, maxV)
				render()
				if flag then RainWare.Flags[flag] = value end
				if type(s.Callback) == "function" then pcall(s.Callback, value) end
			end

			local dragging = false
			local function applyFromX(x)
				local abs = track.AbsolutePosition.X
				local width = math.max(1, track.AbsoluteSize.X)
				local a = math.clamp((x - abs) / width, 0, 1)
				api:Set(minV + (maxV - minV) * a)
			end
			hit.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					applyFromX(input.Position.X)
				end
			end)
			UIS.InputChanged:Connect(function(input)
				if not dragging then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					applyFromX(input.Position.X)
				end
			end)
			UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			render()
			if flag then
				RainWare.Flags[flag] = value
				RainWare.Options[flag] = api
			end
			return api
		end

		function tab:CreateDropdown(d)
			d = d or {}
			local flag = d.Flag
			local values = {}
			for _, v in ipairs(d.Values or d.Content or {}) do
				table.insert(values, tostring(v))
			end
			local value = d.Default
			if value == nil or value == "" then
				value = values[1]
			end
			value = tostring(value or "")

			local card = mk("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				LayoutOrder = self:_next(),
				Parent = self:_parent(),
			})
			corner(card, 5)
			local pick = mk("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = card,
			})
			local titleLbl = label(card, tostring(d.Title or "Dropdown"), UDim2.new(1, -120, 0, 28), COL.text, FONT, 11)
			titleLbl.Position = UDim2.fromOffset(10, 0)
			local valueLbl = label(card, value, UDim2.new(0, 96, 0, 28), COL.accent, FONTS, 10)
			valueLbl.Position = UDim2.new(1, -112, 0, 0)
			valueLbl.TextXAlignment = Enum.TextXAlignment.Right
			valueLbl.TextTruncate = Enum.TextTruncate.AtEnd
			local arrow = label(card, "v", UDim2.fromOffset(14, 28), COL.dim, FONTB, 10)
			arrow.Position = UDim2.new(1, -18, 0, 0)
			arrow.TextXAlignment = Enum.TextXAlignment.Center

			local list = mk("ScrollingFrame", {
				Name = "DropdownList",
				Position = UDim2.fromOffset(0, 31),
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = COL.panel,
				BorderSizePixel = 0,
				Visible = false,
				ClipsDescendants = true,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = COL.accent,
				ScrollBarImageTransparency = 0.2,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = card,
			})
			corner(list, 5)
			stroke(list, COL.stroke, 0.2, 1)
			mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			pad(list, 4, 4, 4, 4)

			win._dropdownLists = win._dropdownLists or {}
			table.insert(win._dropdownLists, list)

			local api = { Flag = flag, Title = d.Title }
			api._list = list
			api._place = function() end

			local function rebuild()
				for _, c in ipairs(list:GetChildren()) do
					if c:IsA("TextButton") then c:Destroy() end
				end
				for i, v in ipairs(values) do
					local b = mk("TextButton", {
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundColor3 = COL.bg,
						Text = v,
						Font = FONT,
						TextSize = 10,
						TextColor3 = v == value and COL.accent or COL.dim,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = false,
						LayoutOrder = i,
						Parent = list,
					})
					corner(b, 3)
					pad(b, 8, 6, 0, 0)
					b.MouseEnter:Connect(function()
						b.BackgroundColor3 = COL.card
					end)
					b.MouseLeave:Connect(function()
						b.BackgroundColor3 = COL.bg
					end)
					b.Activated:Connect(function()
						api:Set(v)
						api:Close()
					end)
				end
			end

			local function setOpen(open)
				local rows = math.min(math.max(#values, 1), 6)
				local height = rows * 22 + 8
				list.Visible = open
				arrow.Text = open and "^" or "v"
				arrow.TextColor3 = open and COL.accent or COL.dim
				list.Size = UDim2.new(1, 0, 0, open and height or 0)
				card.Size = UDim2.new(1, 0, 0, open and (31 + height) or 28)
			end

			function api:Get()
				return value
			end
			function api:Set(v)
				value = tostring(v)
				valueLbl.Text = value
				if flag then RainWare.Flags[flag] = value end
				if type(d.Callback) == "function" then pcall(d.Callback, value) end
				rebuild()
			end
			function api:SetValues(newValues)
				values = {}
				for _, v in ipairs(newValues or {}) do
					table.insert(values, tostring(v))
				end
				if #values > 0 then
					local found = false
					for _, v in ipairs(values) do
						if v == value then
							found = true
							break
						end
					end
					if not found then
						api:Set(values[1])
					else
						rebuild()
					end
				else
					rebuild()
				end
				if list.Visible then
					setOpen(true)
				end
			end
			function api:Open()
				setOpen(true)
			end
			function api:Close()
				setOpen(false)
			end

			pick.Activated:Connect(function()
				setOpen(not list.Visible)
			end)

			UIS.InputBegan:Connect(function(input)
				if not list.Visible then return end
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				local p = input.Position
				local lap, las = list.AbsolutePosition, list.AbsoluteSize
				local inList = p.X >= lap.X and p.X <= lap.X + las.X and p.Y >= lap.Y and p.Y <= lap.Y + las.Y
				local pap, pas = pick.AbsolutePosition, pick.AbsoluteSize
				local inPick = p.X >= pap.X and p.X <= pap.X + pas.X and p.Y >= pap.Y and p.Y <= pap.Y + pas.Y
				if not inList and not inPick then
					setOpen(false)
				end
			end)

			scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				if list.Visible then
					setOpen(false)
				end
			end)

			rebuild()
			setOpen(false)
			if flag then
				RainWare.Flags[flag] = value
				RainWare.Options[flag] = api
			end
			return api
		end

		btn.Activated:Connect(function()
			self:SelectTab(tab.Index)
		end)
		btn.MouseEnter:Connect(function()
			if self._current ~= tab.Index then
				btn.BackgroundColor3 = COL.card
			end
		end)
		btn.MouseLeave:Connect(function()
			if self._current ~= tab.Index then
				btn.BackgroundColor3 = COL.panel
			end
		end)

		table.insert(self._tabs, tab)
		if index == 1 then
			self:SelectTab(1)
		end
		return tab
	end

	function win:SelectTab(index)
		index = tonumber(index) or 1
		for _, list in ipairs(self._dropdownLists or {}) do
			list.Visible = false
		end
		for i, tab in ipairs(self._tabs) do
			local active = i == index
			tab._frame.Visible = active
			tab._button.BackgroundColor3 = active and COL.card or COL.panel
			local nameLbl = tab._button:FindFirstChildWhichIsA("TextLabel")
			if nameLbl then
				nameLbl.TextColor3 = active and COL.accent or COL.dim
			end
			local bar = tab._button:FindFirstChild("Frame")
			if bar then
				bar.Visible = active
			end
		end
		self._current = index
	end

	function win:SelectTabByTitle(title)
		title = tostring(title or ""):lower()
		for i, tab in ipairs(self._tabs) do
			if tostring(tab.Title):lower() == title then
				self:SelectTab(i)
				return true
			end
		end
		return false
	end

	function win:Toggle(visible)
		if visible == nil then
			visible = not panel.Visible
		end
		for _, list in ipairs(self._dropdownLists or {}) do
			list.Visible = false
		end
		if visible then
			panel.Visible = true
			panelScale.Scale = 0.94
			pcall(function()
				TweenService:Create(panelScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		elseif panel.Visible then
			local ok = pcall(function()
				local tween = TweenService:Create(panelScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 })
				tween:Play()
				tween.Completed:Once(function()
					panel.Visible = false
					panelScale.Scale = 1
				end)
			end)
			if not ok then
				panel.Visible = false
			end
		end
	end

	function win:SetStatus(text)
		if self._status then
			self._status.Text = tostring(text or "")
		end
	end

	function win:Destroy()
		for _, c in ipairs(self._conns) do
			pcall(function() c:Disconnect() end)
		end
		self._conns = {}
		pcall(function() screen:Destroy() end)
	end

	function win:Notify(ncfg)
		return RainWare:Notify(ncfg)
	end

	function win:SetTitle(t, sub)
		self.Title = tostring(t or self.Title)
		self.SubTitle = tostring(sub or self.SubTitle or "")
		title.Text = self.Title
	end

	win:SelectTab(1)
	RainWare._activeWindow = win
	RainWare._activeNotifHolder = notifHolder

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
-- Notifications
----------------------------------------------------------------------------

function RainWare:Notify(cfg)
	cfg = cfg or {}
	local holder = self._activeNotifHolder
	if not holder or not holder.Parent then
		for _, gui in ipairs(guiParent():GetChildren()) do
			if gui.Name == "RainWareUI" then
				for _, sib in ipairs(gui:GetChildren()) do
					if sib:IsA("Frame") and sib:GetAttribute("RainWareNotifs") then
						holder = sib
						self._activeNotifHolder = holder
						break
					end
				end
			end
		end
	end
	if not holder then
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

	local card = mk("Frame", {
		Name = "NotifCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	corner(card, 6)
	local str = stroke(card, COL.stroke, 1, 1)

	local accent = mk("Frame", {
		Name = "AccentBar",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = COL.accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = card,
	})
	corner(accent, 2)

	local contentHolder = mk("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	pad(contentHolder, 4, 4, 8, 8)
	mk("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, contentHolder)

	local tl = label(contentHolder, title, UDim2.new(1, 0, 0, 16), COL.text, FONTS, 12)
	tl.TextTransparency = 1
	local cl = label(contentHolder, content, UDim2.new(1, 0, 0, 0), COL.dim, FONT, 11)
	cl.TextTransparency = 1
	cl.TextWrapped = true
	cl.AutomaticSize = Enum.AutomaticSize.Y

	-- Fade-in
	pcall(function()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(str, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.25 }):Play()
		TweenService:Create(accent, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(tl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
		TweenService:Create(cl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	end)

	task.delay(duration, function()
		if card and card.Parent then
			pcall(function()
				local t = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
				TweenService:Create(str, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
				TweenService:Create(accent, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(tl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
				TweenService:Create(cl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
				t:Play()
				t.Completed:Connect(function()
					pcall(function() card:Destroy() end)
				end)
			end)
		end
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
		if gui.Name == "RainWareUI" or gui.Name == "RainWareNotifs" then
			pcall(function() gui:Destroy() end)
		end
	end
	self.Flags = {}
	self.Options = {}
	self._activeWindow = nil
	self._activeNotifHolder = nil
end

return RainWare
