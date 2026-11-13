--[[
    Usage:
        local UI = require(script.RainWareUI)
        local ui = UI:Create(Players.LocalPlayer.PlayerGui)
        local gui = ui:gethui()
        ui:showNotification("Hello", "World")
]]
local RainWareUI = {
    Version = "1.0.0",
    Builder = {},
}
RainWareUI.__index = RainWareUI

-------------------------------------------------
--  Helpers
-------------------------------------------------

local function createRounded(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 4)
    corner.Parent = instance
    return instance
end

local function connect(key, instance, event, callback)
    if instance and instance[event] then
        local conn = instance[event]:Connect(callback)
        RainWareUI._connections[key] = conn
        return conn
    end
end

local function destroyAll(self)
    for conn in pairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}

    if self._gui and self._gui.Parent then
        pcall(function() self._gui:Destroy() end)
    end
    self._gui = nil
    self._panel = nil
end

-------------------------------------------------
--  Main construction
-------------------------------------------------

function RainWareUI:Create(parent)

    -- ---- Drag support ----
    local dragging, dragOffset = false, Vector2.new(0, 0)

    connect("drag_began",     self._panel, "InputBegan", function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragOffset = UserInputService:GetMouseLocation() - Vector2.new(self._panel.AbsolutePosition.X, self._panel.AbsolutePosition.Y)
        end
    end)

    connect("drag_ended",     UserInputService, "InputEnded", function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    connect("drag_moved",     UserInputService, "InputChanged", function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = UserInputService:GetMouseLocation() - dragOffset
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        pos = Vector2.new(
            math.clamp(pos.X, 0, viewport.X - self._panel.AbsoluteSize.X),
            math.clamp(pos.Y, 0, viewport.Y - self._panel.AbsoluteSize.Y)
        )
        self._panel.Position = UDim2.fromOffset(pos.X, pos.Y)
    end)

    -- ---- Header ----
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, -20, 0, 46)
    header.Position = UDim2.new(0, 10, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = self._panel

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, 0, 1, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = "RainWare"
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 20
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.TextColor3 = self.COLORS.primary
    headerLabel.Parent = header


    -- ---- Mobile toggle button ----
    local mobileToggleBtn = nil
    if isMobile then
        mobileToggleBtn = Instance.new("TextButton")
        mobileToggleBtn.Size = UDim2.new(0, 50, 0, 50)
        mobileToggleBtn.Position = UDim2.new(1, -60, 1, -60)
        mobileToggleBtn.BackgroundColor3 = self.COLORS.primary
        mobileToggleBtn.BackgroundTransparency = 0.3
        mobileToggleBtn.Text = "RW"
        mobileToggleBtn.Font = Enum.Font.GothamBold
        mobileToggleBtn.TextSize = 14
        mobileToggleBtn.TextColor3 = self.COLORS.text
        mobileToggleBtn.AutoButtonColor = false
        mobileToggleBtn.ZIndex = 100
        mobileToggleBtn.Parent = self._gui
        createRounded(mobileToggleBtn, 25)

        local mtStroke = Instance.new("UIStroke")
        mtStroke.Color = self.COLORS.divider
        mtStroke.Thickness = 1
        mtStroke.Transparency = 0.5
        mtStroke.Parent = mobileToggleBtn

        connect("mobile_toggle", mobileToggleBtn, "Activated", function()
            RainWareUI.uiHidden = not RainWareUI.uiHidden
            if RainWareUI.uiHidden then
                local t = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = uiScale.Scale * 0.9 })
                t:Play()
                t.Completed:Once(function()
                    self._panel.Visible = false
                    uiScale.Scale = isMobile and math.clamp((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)).X / 720, 0.45, 0.85) or 1
                end)
            else
                self._panel.Visible = true
                local targetScale = isMobile and math.clamp((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)).X / 720, 0.45, 0.85) or 1
                uiScale.Scale = targetScale * 0.9
                local t = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = targetScale })
                t:Play()
            end
        end)
    end

    self._uiScale = uiScale
    self._mobileToggleBtn = mobileToggleBtn

    ---------------------------------------------------------------
    --  Tabs  --------------------------------------------------------
    ---------------------------------------------------------------

    local tabs = {}
    local tabBarH = isMobile and 38 or 34
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, tabBarH)
    tabBar.Position = UDim2.new(0, 10, 0, 58)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = self._panel

    local tabNames = { "Home", "Combat", "Tools", "Extras", "Teleport", "Automation" }
    local tabButtons = {}

    local function switchTab(name)
        for _, child in ipairs(self._gui:GetChildren()) do
            if child:IsA("Frame") and child.ZIndex == 50 then
                child.Visible = false
                child.Parent = self._gui
            end
        end
        for tabName, frame in pairs(tabs) do
            frame.Visible = (tabName == name)
            frame.CanvasPosition = Vector2.new(0, 0)
        end
        for tabName, button in pairs(tabButtons) do
            button.TextColor3 = tabName == name and self.COLORS.primary or self.COLORS.muted
        end
    end

    local function buildTab(name)
        local frame = Instance.new("ScrollingFrame")
        frame.Size = UDim2.new(1, -20, 1, -(58 + tabBarH + 14))
        frame.Position = UDim2.new(0, 10, 0, 58 + tabBarH + 4)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ScrollBarThickness = 3
        frame.ScrollBarImageColor3 = self.COLORS.divider
        frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        frame.ClipsDescendants = true

    ---------------------------------------------------------------
    --  Search box + dropdown  ---------------------------------------
    ---------------------------------------------------------------

    local searchBoxH = isMobile and 32 or 28
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(0, 300, 0, searchBoxH)
    searchBox.Position = UDim2.new(0.5, -150, 0, 10)
    searchBox.BackgroundColor3 = self.COLORS.track
    searchBox.BackgroundTransparency = 0.05
    searchBox.BorderSizePixel = 0
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search features..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.TextColor3 = self.COLORS.text
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 100
    searchBox.Parent = self._gui
    createRounded(searchBox, searchBoxH / 2)

    local searchStroke = Instance.new("UIStroke")
    searchStroke.Color = self.COLORS.divider
    searchStroke.Thickness = 1
    searchStroke.Transparency = 0.3
    searchStroke.Parent = searchBox

    local searchDropdown = Instance.new("Frame")
    searchDropdown.Name = "SearchDropdown"
    searchDropdown.Size = UDim2.new(0, 300, 0, 0)
    searchDropdown.Position = UDim2.new(0.5, -150, 0, 10 + searchBoxH + 4)
    searchDropdown.BackgroundColor3 = self.COLORS.surface
    searchDropdown.BorderSizePixel = 0
    searchDropdown.ClipsDescendants = true
    searchDropdown.ZIndex = 101
    searchDropdown.Visible = false
    searchDropdown.Parent = self._gui
    createRounded(searchDropdown, 10)

    local searchDropdownStroke = Instance.new("UIStroke")
    searchDropdownStroke.Color = self.COLORS.divider
    searchDropdownStroke.Thickness = 1
    searchDropdownStroke.Parent = searchDropdown

    local searchDropdownScroll = Instance.new("ScrollingFrame")
    searchDropdownScroll.Size = UDim2.new(1, 0, 1, 0)
    searchDropdownScroll.BackgroundTransparency = 1
    searchDropdownScroll.BorderSizePixel = 0
    searchDropdownScroll.ScrollBarThickness = 3
    searchDropdownScroll.ScrollBarImageColor3 = self.COLORS.divider
    searchDropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    searchDropdownScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    searchDropdownScroll.ZIndex = 102
    searchDropdownScroll.Parent = searchDropdown

    local searchDropdownLayout = Instance.new("UIListLayout")
    searchDropdownLayout.Padding = UDim.new(0, 2)
    searchDropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
    searchDropdownLayout.Parent = searchDropdownScroll

    local searchDropdownPadding = Instance.new("UIPadding")
    searchDropdownPadding.PaddingTop = UDim.new(0, 4)
    searchDropdownPadding.PaddingBottom = UDim.new(0, 4)

    ---------------------------------------------------------------
    --  Reusable UI builders  ----------------------------------------
    ---------------------------------------------------------------

    local function createToggle(parent, label, y, default, onChange)
        local toggleH = isMobile and 44 or 34
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, toggleH)
        button.BackgroundColor3 = self.COLORS.surfaceAlt
        button.BorderSizePixel = 0
        button.Text = ""
        button.LayoutOrder = y or 0
        button.Parent = parent
        createRounded(button, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Color = self.COLORS.divider
        stroke.Thickness = 1
        stroke.Parent = button

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, -40, 1, 0)
        textLabel.Position = UDim2.new(0, 12, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = label
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 14
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextColor3 = self.COLORS.text
        textLabel.Parent = button
        createRounded(textLabel, 8)

        local checkedMark = Instance.new("TextLabel")
        checkedMark.Size = UDim2.new(0, 20, 0, 20)
        checkedMark.Position = UDim2.new(1, -36, 0, (toggleH - 20) / 2)
        checkedMark.BackgroundTransparency = 1
        checkedMark.Text = "\251"

    local function createSlider(parent, key, label, y, min, max, defaultValue, onChange)
        local barH = 28
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 64)
        holder.BackgroundTransparency = 1
        holder.LayoutOrder = y or 0
        holder.Parent = parent

        local labelLabel = Instance.new("TextLabel")
        labelLabel.Size = UDim2.new(1, 0, 0, 22)
        labelLabel.Position = UDim2.new(0, 12, 0, 0)
        labelLabel.BackgroundTransparency = 1
        labelLabel.Text = label
        labelLabel.Font = Enum.Font.Gotham
        labelLabel.TextSize = 14
        labelLabel.TextXAlignment = Enum.TextXAlignment.Left
        labelLabel.TextColor3 = self.COLORS.text
        labelLabel.Parent = holder

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0, 70, 0, 22)
        valueLabel.Position = UDim2.new(1, -80, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 14
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextColor3 = self.COLORS.text
        valueLabel.Parent = holder

        local bar = Instance.new("Frame")
        bar.Name = "SliderBar"
        bar.Size = UDim2.new(1, -24, 0, 6)
        bar.Position = UDim2.new(0, 12, 0, 30)
        bar.BackgroundColor3 = self.COLORS.track
        bar.BorderSizePixel = 0
        bar.Parent = holder
        createRounded(bar, 3)

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = UDim2.new(0, 0, 0.5, -8)
        knob.BackgroundColor3 = self.COLORS.primary
        knob.BorderSizePixel = 0
        knob.Parent = bar
        createRounded(knob, 8)

        local dragging = false


        local function openList()
            open = true
            local absPos = button.AbsolutePosition
            local absSize = button.AbsoluteSize
            listFrame.Size = UDim2.new(0, absSize.X, 0, #options * 26 + 4)
            listFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
            listFrame.Parent = self._gui
            listFrame.Visible = true
            arrow.Text = "^"
            btnStroke.Color = self.COLORS.primary
        end

        local function closeList()
            open = false
            listFrame.Visible = false
            listFrame.Parent = holder
            listFrame.Position = UDim2.new(0, 12, 0, 46)
            arrow.Text = "v"
            btnStroke.Color = self.COLORS.divider
        end

        for i, option in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 26)
            item.Position = UDim2.new(0, 0, 0, (i - 1) * 26 + 2)
            item.BackgroundColor3 = i == selectedIndex and self.COLORS.surfaceAlt or self.COLORS.track
            item.BorderSizePixel = 0
            item.Text = "  " .. option
            item.Font = Enum.Font.Gotham
            item.TextSize = 13
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextColor3 = i == selectedIndex and self.COLORS.primary or self.COLORS.text
            item.ZIndex = 51
            item.Parent = listFrame
            createRounded(item, 4)

            connect("dropdown_" .. key .. "_" .. i, item, "Activated", function()
                selectedIndex = i
                btnLabel.Text = option
                refreshList()
                item.BackgroundColor3 = self.COLORS.surfaceAlt
                item.TextColor3 = self.COLORS.primary
                closeList()
                pcall(onChange, option, i)
            end)
        end

        connect("dropdown_" .. key .. "_toggle", button, "Activated", function()
            if open then
                closeList()
            else
                openList()
            end
        end)

        pcall(onChange, options[selectedIndex], selectedIndex)

        return {
            getSelectedIndex = function() return selectedIndex end,
            setSelectedIndex = function(i)
                if i >= 1 and #options > 0 and i <= #options then

    ---------------------------------------------------------------
    --  Notifications  -----------------------------------------------
    ---------------------------------------------------------------

    local function showNotification(title, body, color, duration)
        color = color or self.COLORS.primary
        duration = duration or 5

        local notifCount = 0
        for _, child in ipairs(self._gui:GetChildren()) do
            if child:IsA("Frame") and child.Name == self.ID_NOTIF then
                notifCount = notifCount + 1
            end
        end

        local notif = Instance.new("Frame")
        notif.Name = self.ID_NOTIF
        notif.Size = UDim2.new(0, 300, 0, 70)
        notif.Position = UDim2.new(1, 10, 0, 20 + notifCount * 80)
        notif.BackgroundColor3 = self.COLORS.surface
        notif.BorderSizePixel = 0
        notif.ZIndex = 90
        notif.Parent = self._gui
        createRounded(notif, 10)

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 5, 1, 0)
        accent.BackgroundColor3 = color
        accent.BorderSizePixel = 0
        accent.ZIndex = 91
        accent.Parent = notif
        createRounded(accent, 10)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -20, 0, 30)
        titleLabel.Position = UDim2.new(0, 14, 0, 8)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 14
        titleLabel.TextColor3 = color
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 91
        titleLabel.Parent = notif

        local bodyLabel = Instance.new("TextLabel")
        bodyLabel.Size = UDim2.new(1, -20, 0, 20)
        bodyLabel.Position = UDim2.new(0, 14, 0, 38)
        bodyLabel.BackgroundTransparency = 1

    ---------------------------------------------------------------
    --  Joystick (mobile only)  --------------------------------------
    ---------------------------------------------------------------

    local joystickGui = nil

    local function createJoystick()
        if joystickGui then return end
        if not isMobile then return end

        joystickGui = Instance.new("ScreenGui")
        joystickGui.ResetOnSpawn = false
        joystickGui.IgnoreGuiInset = true
        joystickGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        joystickGui.Parent = playerGui

        local base = Instance.new("Frame")
        base.Name = "Base"
        base.Size = UDim2.new(0, 120, 0, 120)
        base.Position = UDim2.new(0, 30, 1, -150)
        base.BackgroundColor3 = self.COLORS.track
        base.BackgroundTransparency = 0.5
        base.BorderSizePixel = 0
        base.Parent = joystickGui
        createRounded(base, 60)

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Size = UDim2.new(0, 50, 0, 50)
        knob.Position = UDim2.new(0.5, -25, 0.5, -25)
        knob.BackgroundColor3 = self.COLORS.primary
        knob.BackgroundTransparency = 0.3
        knob.BorderSizePixel = 0
        knob.Parent = base
        createRounded(knob, 25)

        local upBtn = Instance.new("TextButton")
        upBtn.Name = "UpBtn"
        upBtn.Size = UDim2.new(0, 40, 0, 40)
        upBtn.Position = UDim2.new(0, 130, 1, -150)
        upBtn.BackgroundColor3 = self.COLORS.track
        upBtn.BackgroundTransparency = 0.4
        upBtn.Text = "^"
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextSize = 18
        upBtn.TextColor3 = self.COLORS.primary
        upBtn.AutoButtonColor = false
        upBtn.BorderSizePixel = 0
        upBtn.Parent = joystickGui
        createRounded(upBtn, 20)

        local downBtn = Instance.new("TextButton")
        downBtn.Name = "DownBtn"
        downBtn.Size = UDim2.new(0, 40, 0, 40)
        downBtn.Position = UDim2.new(0, 130, 1, -100)
        downBtn.BackgroundColor3 = self.COLORS.track
        downBtn.BackgroundTransparency = 0.4
        downBtn.Text = "v"
        downBtn.Font = Enum.Font.GothamBold

    ---------------------------------------------------------------
    --  Public API  --------------------------------------------------
    ---------------------------------------------------------------

    function self:gethui()
        return self._gui
    end

    function self:switchTab(name)
        switchTab(name)
    end

    function self:showNotification(title, body, color, duration)
        showNotification(self, title, body, color, duration)
    end

    function self:destroyAll()
        destroyAll(self)
        RainWareUI = nil
    end

    self.Builder = {
        createRounded = createRounded,
        connect       = connect,
        switchTab     = switchTab,
        buildTab      = buildTab,
        createToggle  = createToggle,
        createSlider  = createSlider,
        createDropdown = createDropdown,
        createJoystick = createJoystick,
    }

    return self
end

-------------------------------------------------
--  Module export
-------------------------------------------------

return RainWareUI

        downBtn.TextSize = 18
        downBtn.TextColor3 = self.COLORS.primary
        downBtn.AutoButtonColor = false
        downBtn.BorderSizePixel = 0
        downBtn.Parent = joystickGui
        createRounded(downBtn, 20)
    end

    local function destroyJoystick()
        if joystickGui then
            pcall(function() joystickGui:Destroy() end)
            joystickGui = nil
        end
        for _, key in ipairs({ "joystick_began", "joystick_ended", "joystick_moved", "joystick_up_btn", "joystick_up_btn_end", "joystick_down_btn", "joystick_down_btn_end" }) do
            if RainWareUI._connections[key] then
                pcall(function() RainWareUI._connections[key]:Disconnect() end)
                RainWareUI._connections[key] = nil
            end
        end
    end

        bodyLabel.Text = body or ""
        bodyLabel.Font = Enum.Font.Gotham
        bodyLabel.TextSize = 12
        bodyLabel.TextColor3 = self.COLORS.muted
        bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
        bodyLabel.ZIndex = 91
        bodyLabel.Parent = notif

        local slideIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -320, 0, 20 + notifCount * 80) })
        slideIn:Play()

        task.delay(duration, function()
            if not notif.Parent then return end
            local slideOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 10, 0, notif.Position.Y.Offset) })
            slideOut:Play()
            slideOut.Completed:Once(function()
                pcall(function() notif:Destroy() end)
            end)
        end)
    end

                    selectedIndex = i
                    btnLabel.Text = options[i]
                    refreshList()
                    pcall(onChange, options[i], i)
                end
            end,
            getOptions = function() return options end,
            setOptions = function(newOptions)
                options = newOptions
                if #options == 0 then
                    table.insert(options, "No options")
                end
                selectedIndex = 1
                btnLabel.Text = options[1]
                for _, child in ipairs(listFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                for i, option in ipairs(options) do
                    local item = Instance.new("TextButton")
                    item.Size = UDim2.new(1, 0, 0, 26)
                    item.Position = UDim2.new(0, 0, 0, (i - 1) * 26 + 2)
                    item.BackgroundColor3 = i == selectedIndex and self.COLORS.surfaceAlt or self.COLORS.track
                    item.BorderSizePixel = 0
                    item.Text = "  " .. option
                    item.Font = Enum.Font.Gotham
                    item.TextSize = 13
                    item.TextXAlignment = Enum.TextXAlignment.Left
                    item.TextColor3 = i == selectedIndex and self.COLORS.primary or self.COLORS.text
                    item.ZIndex = 51
                    item.Parent = listFrame
                    createRounded(item, 4)

                    connect("dropdown_" .. key .. "_" .. i, item, "Activated", function()
                        selectedIndex = i
                        btnLabel.Text = option
                        refreshList()
                        item.BackgroundColor3 = self.COLORS.surfaceAlt
                        item.TextColor3 = self.COLORS.primary
                        closeList()
                        pcall(onChange, option, i)
                    end)
                end
            end
        }
    end

        local function setPercent(percent)
            local width = math.max(bar.AbsoluteSize.X - knob.AbsoluteSize.X, 1)
            local target = UDim2.new(percent, 0, 0.5, -8)
            knob.Position = target
            valueLabel.Text = tostring(math.floor(value + 0.5))
            pcall(onChange, value)
        end

        local function positionToPercent(x)
            local barAbs = bar.AbsolutePosition
            local barWidth = math.max(bar.AbsoluteSize.X, 1)
            return (x - barAbs.X) / barWidth
        end

        connect("slider_" .. key .. "_began", bar, "InputBegan", function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setPercent(positionToPercent(UserInputService:GetMouseLocation().X))
            end
        end)

        connect("slider_" .. key .. "_moved", bar, "InputChanged", function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                setPercent(positionToPercent(UserInputService:GetMouseLocation().X))
            end
        end)

        connect("slider_" .. key .. "_ended",  bar, "InputEnded", function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        local value = defaultValue or min
        setPercent((value - min) / (max - min))

        return {
            getValue  = function() return value end,
            setValue  = function(v) value = math.clamp(v, min, max); setPercent((value - min) / (max - min)) end,
        }
    end

        checkedMark.Font = Enum.Font.GothamBold
        checkedMark.TextSize = 14
        checkedMark.TextColor3 = self.COLORS.primary
        checkedMark.TextXAlignment = Enum.TextXAlignment.Right
        checkedMark.Parent = button

        local value = default or false

        local function refresh()
            checkedMark.Visible = value
            button.BackgroundColor3 = value and self.COLORS.primary or self.COLORS.surfaceAlt
        end

        connect("toggle_" .. label, button, "Activated", function()
            value = not value
            refresh()
            pcall(onChange, value)
        end)

        refresh()

        return {
            getValue = function() return value end,
            setValue = function(v)
                value = v
                refresh()
            end,
        }
    end

    searchDropdownPadding.Parent = searchDropdownScroll

        frame.Visible = false
        frame.Parent = self._panel

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = frame

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 2)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.Parent = frame

        tabs[name] = frame
        return frame
    end

    for index, name in ipairs(tabNames) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 100, 0, isMobile and 38 or 30)
        button.Position = UDim2.new(0, (index - 1) * 110, 0, 2)
        button.BackgroundColor3 = self.COLORS.surfaceAlt
        button.BorderSizePixel = 0
        button.Text = name
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.TextColor3 = self.COLORS.muted
        button.Parent = tabBar
        createRounded(button, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Color = self.COLORS.divider
        stroke.Thickness = 1
        stroke.Parent = button

        connect("tab_" .. name, button, "Activated", function()
            switchTab(name)
        end)

        tabButtons[name] = button
    end

    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, -20, 0, 1)
    headerLine.Position = UDim2.new(0, 10, 0, 54)
    headerLine.BackgroundColor3 = self.COLORS.divider
    headerLine.BorderSizePixel = 0
    headerLine.Parent = self._panel

    local self = setmetatable({ _connections = {} }, self)

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    self.ID_GUI = tostring(math.random(100000, 999999))
    self.ID_NOTIF = tostring(math.random(100000, 999999))

    self.COLORS = {
        primary    = Color3.fromRGB(66, 165, 245),
        dark       = Color3.fromRGB(18, 18, 18),
        surface    = Color3.fromRGB(40, 40, 40),
        surfaceAlt = Color3.fromRGB(30, 30, 30),
        track      = Color3.fromRGB(24, 24, 24),
        text       = Color3.fromRGB(255, 255, 255),
        muted      = Color3.fromRGB(150, 150, 150),
        error      = Color3.fromRGB(244, 67, 54),
        divider    = Color3.fromRGB(60, 60, 60),
    }

    self._gui = Instance.new("ScreenGui")
    self._gui.Name = self.ID_GUI
    self._gui.ResetOnSpawn = false
    self._gui.IgnoreGuiInset = true
    self._gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self._gui.Parent = parent or playerGui

    self._panel = Instance.new("Frame")
    self._panel.Size = UDim2.new(0, 720, 0, 400)
    self._panel.Position = UDim2.new(0.5, -360, 0.5, -200)
    self._panel.BackgroundColor3 = self.COLORS.surface
    self._panel.BorderSizePixel = 0
    self._panel.Visible = true
    self._panel.Parent = self._gui
    createRounded(self._panel, 12)

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = self.COLORS.divider
    panelStroke.Thickness = 1
    panelStroke.Parent = self._panel

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1
    uiScale.Parent = self._panel

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    if isMobile then
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        uiScale.Scale = math.clamp(vp.X / 720, 0.45, 0.85)
    end
