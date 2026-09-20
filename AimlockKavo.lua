-- AimlockKavo.lua
-- Kavo-style minimal UI for SimpleAim (Roblox executor)
-- made by puppydog
-- v2: lag-fixed (label throttle, part cache, BindToRenderStep)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ─── THEME (Kavo) ───
local Theme = {
    Bg          = Color3.fromRGB(18, 18, 18),
    BgAlt       = Color3.fromRGB(24, 24, 24),
    Card        = Color3.fromRGB(26, 26, 26),
    CardHover   = Color3.fromRGB(32, 32, 32),
    Divider     = Color3.fromRGB(38, 38, 38),
    Border      = Color3.fromRGB(45, 45, 45),
    On          = Color3.fromRGB(90, 200, 120),
    Off         = Color3.fromRGB(60, 60, 60),
    Text        = Color3.fromRGB(235, 235, 235),
    TextDim     = Color3.fromRGB(140, 140, 140),
    TextSub     = Color3.fromRGB(95, 95, 95),
    Warn        = Color3.fromRGB(230, 170, 60),
    Danger      = Color3.fromRGB(220, 80, 80),
    Font        = Enum.Font.Gotham,
    FontMed     = Enum.Font.GothamMedium,
    FontBold    = Enum.Font.GothamBold,
}

local function new(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    return i
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r or 4), Parent = p})
end

local function stroke(p, col, t, tr)
    return new("UIStroke", {
        Color = col or Theme.Border,
        Thickness = t or 1,
        Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = p,
    })
end

-- ─── PARENT RESOLVER ───
local function getParent()
    local ok, r = pcall(function() return gethui and gethui() end)
    if ok and r then
        local t = Instance.new("Frame")
        local ok2 = pcall(function() t.Parent = r end)
        t:Destroy()
        if ok2 then return r end
    end
    local ok3, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok3 and cg then
        local t = Instance.new("Frame")
        local ok4 = pcall(function() t.Parent = cg end)
        t:Destroy()
        if ok4 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end

local parent = getParent()

-- ─── PARTS ───
local PARTS = {
    { name = "HumanoidRootPart", aliases = {"HumanoidRootPart"} },
    { name = "Head",             aliases = {"Head"} },
    { name = "UpperTorso",       aliases = {"UpperTorso", "Torso"} },
    { name = "LowerTorso",       aliases = {"LowerTorso"} },
    { name = "LeftUpperArm",     aliases = {"LeftUpperArm", "Left Arm"} },
    { name = "RightUpperArm",    aliases = {"RightUpperArm", "Right Arm"} },
    { name = "LeftLowerArm",     aliases = {"LeftLowerArm"} },
    { name = "RightLowerArm",    aliases = {"RightLowerArm"} },
    { name = "LeftUpperLeg",     aliases = {"LeftUpperLeg", "Left Leg"} },
    { name = "RightUpperLeg",    aliases = {"RightUpperLeg", "Right Leg"} },
    { name = "LeftFoot",         aliases = {"LeftFoot"} },
    { name = "RightFoot",        aliases = {"RightFoot"} },
}
local PART_NAMES = {}
for _, p in ipairs(PARTS) do table.insert(PART_NAMES, p.name) end

-- ─── STATE ───
local SMOOTH_MIN, SMOOTH_MAX = 1, 99

local State = {
    Enabled      = false,
    Smooth       = 30,
    LockKey      = Enum.KeyCode.G,
    HideKey      = Enum.KeyCode.RightControl,
    UiHidden     = false,
    SelectedPart = "Head",
    LockedPlayer = nil,
    AwaitingKey  = false,
    Unloaded     = false,
}

-- ─── CACHE (lag fix) ───
local cache = {
    lastTargetText    = nil,
    lastTargetColor   = nil,
    cachedTargetPart  = nil,
    cachedTargetChar  = nil,
    lastLabelRefresh  = 0,
}

-- ─── CONNECTIONS ───
local Connections = {}
local function track(conn)
    table.insert(Connections, conn)
    return conn
end

-- ─── HELPERS ───
local function isAlive(char)
    if not char or not char.Parent then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function getTargetPart(char)
    if not char then return nil end
    for _, p in ipairs(PARTS) do
        if p.name == State.SelectedPart then
            for _, alias in ipairs(p.aliases) do
                local found = char:FindFirstChild(alias)
                if found then return found end
            end
            break
        end
    end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
end

local function w2s(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    if not on then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function pickPlayerNearMouse()
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not isAlive(char) then continue end
        local part = getTargetPart(char)
        if not part then continue end
        local sp = w2s(part.Position)
        if sp then
            local d = (sp - mousePos).Magnitude
            if d < bestDist then best, bestDist = plr, d end
        end
    end
    return best
end

-- cached — reuse part reference until char or part changes
local function getLockedPart()
    if not State.LockedPlayer then
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
        return nil
    end
    local char = State.LockedPlayer.Character
    if not isAlive(char) then
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
        return nil
    end
    if cache.cachedTargetChar == char
       and cache.cachedTargetPart
       and cache.cachedTargetPart.Parent then
        return cache.cachedTargetPart
    end
    cache.cachedTargetChar = char
    cache.cachedTargetPart = getTargetPart(char)
    return cache.cachedTargetPart
end

local function shortKeyName(kc)
    if not kc then return "—" end
    local n = kc.Name
    n = n:gsub("^Right", "r"):gsub("^Left", "l")
    n = n:gsub("Control", "ctrl"):gsub("Shift", "shift"):gsub("Alt", "alt")
    return n
end

-- ═══════════════════════════════════════
-- KAVO UI
-- ═══════════════════════════════════════

local ScreenGui = new("ScreenGui", {
    Name = "AimlockKavo",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = parent,
})

local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 240, 0, 352),
    Position = UDim2.new(0.02, 0, 0.3, 0),
    BackgroundColor3 = Theme.Bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
    Parent = ScreenGui,
})
corner(Main, 6)
stroke(Main, Theme.Border, 1, 0)

-- ─── header ───
local Header = new("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Theme.BgAlt,
    BorderSizePixel = 0,
    Parent = Main,
})
corner(Header, 6)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 6),
    Position = UDim2.new(0, 0, 1, -6),
    BackgroundColor3 = Theme.BgAlt,
    BorderSizePixel = 0,
    Parent = Header,
})

new("TextLabel", {
    Size = UDim2.new(1, -90, 0, 14),
    Position = UDim2.new(0, 12, 0, 6),
    BackgroundTransparency = 1,
    Text = "aimlock",
    TextColor3 = Theme.Text,
    Font = Theme.FontMed,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})

new("TextLabel", {
    Size = UDim2.new(1, -90, 0, 10),
    Position = UDim2.new(0, 12, 0, 19),
    BackgroundTransparency = 1,
    Text = "made by puppydog",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header,
})

local Dot = new("Frame", {
    Size = UDim2.new(0, 6, 0, 6),
    Position = UDim2.new(1, -46, 0.5, -3),
    BackgroundColor3 = Theme.Off,
    BorderSizePixel = 0,
    Parent = Header,
})
corner(Dot, 3)

local UnloadBtn = new("TextButton", {
    Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(1, -28, 0.5, -11),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontBold,
    TextSize = 16,
    AutoButtonColor = false,
    Parent = Header,
})
corner(UnloadBtn, 4)
UnloadBtn.MouseEnter:Connect(function()
    UnloadBtn.BackgroundColor3 = Theme.Danger
    UnloadBtn.TextColor3 = Theme.Text
end)
UnloadBtn.MouseLeave:Connect(function()
    UnloadBtn.BackgroundColor3 = Theme.Card
    UnloadBtn.TextColor3 = Theme.TextDim
end)

new("Frame", {
    Size = UDim2.new(1, -20, 0, 1),
    Position = UDim2.new(0, 10, 0, 40),
    BackgroundColor3 = Theme.Divider,
    BorderSizePixel = 0,
    Parent = Main,
})

-- ─── content ───
local Content = new("Frame", {
    Name = "Content",
    Size = UDim2.new(1, -20, 1, -60),
    Position = UDim2.new(0, 10, 0, 50),
    BackgroundTransparency = 1,
    Parent = Main,
})
new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Content,
})

-- ─── toggle row ───
local ToggleRow = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    LayoutOrder = 1,
    Parent = Content,
})
new("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0),
    BackgroundTransparency = 1,
    Text = "enabled",
    TextColor3 = Theme.TextDim,
    Font = Theme.Font,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ToggleRow,
})
local Switch = new("Frame", {
    Size = UDim2.new(0, 32, 0, 16),
    Position = UDim2.new(1, -32, 0.5, -8),
    BackgroundColor3 = Theme.Off,
    BorderSizePixel = 0,
    Parent = ToggleRow,
})
corner(Switch, 3)
local SwitchKnob = new("Frame", {
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 2, 0.5, -6),
    BackgroundColor3 = Theme.TextDim,
    BorderSizePixel = 0,
    Parent = Switch,
})
corner(SwitchKnob, 2)

-- ─── target row ───
local TargetRow = new("Frame", {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    LayoutOrder = 2,
    Parent = Content,
})
new("TextLabel", {
    Size = UDim2.new(0, 60, 1, 0),
    BackgroundTransparency = 1,
    Text = "target",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TargetRow,
})
local TargetLbl = new("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.new(0, 60, 0, 0),
    BackgroundTransparency = 1,
    Text = "—",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = TargetRow,
})

-- ─── hitbox section ───
new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "hitbox part",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 3,
    Parent = Content,
})

local PartHolder = new("Frame", {
    Name = "PartHolder",
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    LayoutOrder = 4,
    ZIndex = 5,
    Parent = Content,
})
corner(PartHolder, 4)
stroke(PartHolder, Theme.Border, 1, 0)

local PartHeader = new("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
    Parent = PartHolder,
})
local PartCur = new("TextLabel", {
    Size = UDim2.new(1, -30, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = State.SelectedPart,
    TextColor3 = Theme.Text,
    Font = Theme.Font,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = PartHeader,
})
new("TextLabel", {
    Size = UDim2.new(0, 16, 1, 0),
    Position = UDim2.new(1, -22, 0, 0),
    BackgroundTransparency = 1,
    Text = "+",
    TextColor3 = Theme.TextDim,
    Font = Theme.Font,
    TextSize = 12,
    ZIndex = 7,
    Parent = PartHeader,
})

local PartList = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 180),
    Position = UDim2.new(0, 0, 1, 4),
    BackgroundColor3 = Theme.BgAlt,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.TextSub,
    CanvasSize = UDim2.new(0, 0, 0, #PARTS * 22 + 6),
    Parent = PartHolder,
})
corner(PartList, 4)
stroke(PartList, Theme.Border, 1, 0)
new("UIListLayout", {
    Padding = UDim.new(0, 0),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = PartList,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 2),
    PaddingBottom = UDim.new(0, 2),
    Parent = PartList,
})
for i, name in ipairs(PART_NAMES) do
    local item = new("TextButton", {
        Size = UDim2.new(1, -4, 0, 22),
        BackgroundColor3 = Theme.BgAlt,
        Text = "  " .. name,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = i,
        ZIndex = 51,
        Parent = PartList,
    })
    item.MouseEnter:Connect(function()
        item.BackgroundColor3 = Theme.CardHover
        item.TextColor3 = Theme.Text
    end)
    item.MouseLeave:Connect(function()
        item.BackgroundColor3 = Theme.BgAlt
        item.TextColor3 = Theme.TextDim
    end)
    item.MouseButton1Click:Connect(function()
        State.SelectedPart = name
        PartCur.Text = name
        PartList.Visible = false
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
    end)
end
PartHeader.MouseButton1Click:Connect(function()
    PartList.Visible = not PartList.Visible
end)

-- ─── smooth slider ───
local SmoothRow = new("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1,
    LayoutOrder = 5,
    Parent = Content,
})

local SmoothLbl = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 12),
    BackgroundTransparency = 1,
    Text = "smooth",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = SmoothRow,
})
local SmoothVal = new("TextLabel", {
    Size = UDim2.new(0, 40, 0, 12),
    Position = UDim2.new(1, -40, 0, 0),
    BackgroundTransparency = 1,
    Text = tostring(State.Smooth),
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = SmoothRow,
})

local Track = new("Frame", {
    Size = UDim2.new(1, 0, 0, 4),
    Position = UDim2.new(0, 0, 0, 20),
    BackgroundColor3 = Theme.Divider,
    BorderSizePixel = 0,
    Parent = SmoothRow,
})
corner(Track, 2)

local Fill = new("Frame", {
    Size = UDim2.new((State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN), 0, 1, 0),
    BackgroundColor3 = Theme.TextDim,
    BorderSizePixel = 0,
    Parent = Track,
})
corner(Fill, 2)

local Knob = new("Frame", {
    Size = UDim2.new(0, 10, 0, 10),
    Position = UDim2.new((State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN), -5, 0.5, -5),
    BackgroundColor3 = Theme.Text,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Track,
})
corner(Knob, 5)

local TrackHit = new("TextButton", {
    Size = UDim2.new(1, 14, 0, 22),
    Position = UDim2.new(0, -7, 0, 11),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 5,
    Parent = SmoothRow,
})

local function updateSmoothVisual()
    local ratio = (State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN)
    Fill.Size = UDim2.new(ratio, 0, 1, 0)
    Knob.Position = UDim2.new(ratio, -5, 0.5, -5)
    SmoothVal.Text = tostring(State.Smooth)
end

local sliderDragging = false
local function updateSmoothFromMouse()
    local mouseX = UserInputService:GetMouseLocation().X
    local trackAbs = Track.AbsolutePosition.X
    local trackW   = Track.AbsoluteSize.X
    if trackW <= 0 then return end
    local ratio = math.clamp((mouseX - trackAbs) / trackW, 0, 1)
    local val = math.floor(ratio * (SMOOTH_MAX - SMOOTH_MIN) + SMOOTH_MIN + 0.5)
    if val ~= State.Smooth then
        State.Smooth = val
        updateSmoothVisual()
    end
end

TrackHit.MouseButton1Down:Connect(function()
    sliderDragging = true
    updateSmoothFromMouse()
end)

-- ─── binds section ───
new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "binds",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 6,
    Parent = Content,
})

local function makeKeybindRow(order, labelText, getter, setter)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = Content,
    })
    corner(row, 4)
    stroke(row, Theme.Border, 1, 0)

    new("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local keyLbl = new("TextLabel", {
        Size = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = shortKeyName(getter()),
        TextColor3 = Theme.Text,
        Font = Theme.FontMed,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })

    row.MouseEnter:Connect(function()
        row.BackgroundColor3 = Theme.CardHover
    end)
    row.MouseLeave:Connect(function()
        row.BackgroundColor3 = Theme.Card
    end)

    row.MouseButton1Click:Connect(function()
        if State.AwaitingKey or State.Unloaded then return end
        State.AwaitingKey = true
        keyLbl.Text = "..."
        keyLbl.TextColor3 = Theme.Warn

        local bindConn
        bindConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Backspace then
                keyLbl.Text = shortKeyName(getter())
            else
                setter(input.KeyCode)
                keyLbl.Text = shortKeyName(input.KeyCode)
            end
            keyLbl.TextColor3 = Theme.Text
            State.AwaitingKey = false
            bindConn:Disconnect()
        end)
        track(bindConn)
    end)

    return row, keyLbl
end

local LockRow   = makeKeybindRow(7, "lock key",  function() return State.LockKey end, function(k) State.LockKey = k end)
local HideRow   = makeKeybindRow(8, "hide ui",   function() return State.HideKey end, function(k) State.HideKey = k end)

-- ─── unload button ───
local UnloadRow = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "unload",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 11,
    AutoButtonColor = false,
    LayoutOrder = 9,
    Parent = Content,
})
corner(UnloadRow, 4)
stroke(UnloadRow, Theme.Border, 1, 0)
UnloadRow.MouseEnter:Connect(function()
    UnloadRow.BackgroundColor3 = Theme.Danger
    UnloadRow.TextColor3 = Theme.Text
end)
UnloadRow.MouseLeave:Connect(function()
    UnloadRow.BackgroundColor3 = Theme.Card
    UnloadRow.TextColor3 = Theme.TextDim
end)

-- ═══════════════════════════════════════
-- LOGIC
-- ═══════════════════════════════════════

local function refreshTargetLabel()
    local now = os.clock()
    if now - cache.lastLabelRefresh < 0.1 then return end
    cache.lastLabelRefresh = now

    local text, color
    if State.LockedPlayer then
        local alive = isAlive(State.LockedPlayer.Character)
        text = State.LockedPlayer.Name .. (alive and "" or "  (dead)")
        color = alive and Theme.Text or Theme.Warn
    else
        text = "—"
        color = Theme.TextDim
    end

    if text ~= cache.lastTargetText then
        TargetLbl.Text = text
        cache.lastTargetText = text
    end
    if color ~= cache.lastTargetColor then
        TargetLbl.TextColor3 = color
        cache.lastTargetColor = color
    end
end

local function setSwitch(on)
    local bg = on and Theme.On or Theme.Off
    local knobCol = on and Theme.Text or Theme.TextDim
    local knobPos = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    TweenService:Create(Switch, TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
    TweenService:Create(SwitchKnob, TweenInfo.new(0.15), {Position = knobPos, BackgroundColor3 = knobCol}):Play()
    Dot.BackgroundColor3 = bg
end

local function setEnabled(v)
    if State.Unloaded then return end
    State.Enabled = v
    if v then
        State.LockedPlayer = pickPlayerNearMouse()
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
    else
        State.LockedPlayer = nil
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
    end
    setSwitch(v)
    cache.lastLabelRefresh = 0
    refreshTargetLabel()
end

local function setUiHidden(v)
    State.UiHidden = v
    Main.Visible = not v
    if v then PartList.Visible = false end
end

local function unload()
    if State.Unloaded then return end
    State.Unloaded = true
    State.Enabled = false
    State.LockedPlayer = nil

    pcall(function() RunService:UnbindFromRenderStep("PuppyAimCam") end)

    for _, c in ipairs(Connections) do
        if typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    Connections = {}

    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end
    print("[puppydog] Kavo Aimlock unloaded")
end

-- ─── UI events ───
ToggleRow.MouseButton1Click:Connect(function()
    setEnabled(not State.Enabled)
end)

UnloadRow.MouseButton1Click:Connect(unload)
UnloadBtn.MouseButton1Click:Connect(unload)

-- ─── global input ───
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if State.Unloaded then return end
    if State.AwaitingKey then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if gpe then return end
    if input.KeyCode == State.LockKey then setEnabled(not State.Enabled) end
    if input.KeyCode == State.HideKey then setUiHidden(not State.UiHidden) end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if State.Unloaded then return end
    if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        updateSmoothFromMouse()
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging = false
    end
end))

-- ─── camera step (BindToRenderStep — priority สูงกว่า camera module) ───
local function cameraStep()
    if State.Unloaded then return end
    if not State.Enabled then return end
    if not State.LockedPlayer then return end
    refreshTargetLabel()
    local targetPart = getLockedPart()
    if not targetPart then return end
    local desired = CFrame.new(Camera.CFrame.Position, targetPart.Position)
    local alpha = 1 - math.clamp(State.Smooth / 100, 0.01, 0.99)
    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
end

RunService:BindToRenderStep("PuppyAimCam", Enum.RenderPriority.Camera.Value + 1, cameraStep)

updateSmoothVisual()
print("[puppydog] Kavo Aimlock loaded — made by puppydog")