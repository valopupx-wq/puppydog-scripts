-- AimlockObsidian.lua
-- Obsidian-style UI for SimpleAim (Roblox executor)
-- made by puppydog

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Theme = {
    Bg          = Color3.fromRGB(10, 10, 12),
    BgAlt       = Color3.fromRGB(16, 16, 20),
    Sidebar     = Color3.fromRGB(13, 13, 17),
    Card        = Color3.fromRGB(20, 20, 26),
    CardHover   = Color3.fromRGB(26, 26, 34),
    Border      = Color3.fromRGB(34, 34, 44),
    BorderSoft  = Color3.fromRGB(28, 28, 36),
    Accent      = Color3.fromRGB(168, 85, 247),
    AccentSoft  = Color3.fromRGB(139, 92, 246),
    AccentDim   = Color3.fromRGB(88, 40, 140),
    On          = Color3.fromRGB(52, 211, 153),
    Off         = Color3.fromRGB(45, 45, 58),
    Text        = Color3.fromRGB(240, 240, 245),
    TextDim     = Color3.fromRGB(150, 150, 175),
    TextSub     = Color3.fromRGB(90, 90, 110),
    Warn        = Color3.fromRGB(251, 191, 36),
    Danger      = Color3.fromRGB(244, 63, 94),
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
    return new("UICorner", {CornerRadius = UDim.new(0, r or 3), Parent = p})
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

local SMOOTH_MIN, SMOOTH_MAX = 1, 99
local State = {
    Enabled      = false,
    Smooth       = 1,
    LockKey      = Enum.KeyCode.G,
    HideKey      = Enum.KeyCode.RightControl,
    UiHidden     = false,
    SelectedPart = "HumanoidRootPart",
    LockedPlayer = nil,
    AwaitingKey  = false,
    Unloaded     = false,
    ActiveTab    = "main",
}

local cache = {
    lastTargetText   = nil,
    lastTargetColor  = nil,
    cachedTargetPart = nil,
    cachedTargetChar = nil,
    lastLabelRefresh = 0,
}

local Connections = {}
local function track(c) table.insert(Connections, c); return c end

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

local W = 420
local H = 320
local RAIL = 78

local ScreenGui = new("ScreenGui", {
    Name = "AimlockObsidian",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = parent,
})

local Shadow = new("Frame", {
    Size = UDim2.new(0, W, 0, H),
    Position = UDim2.new(0.03, 3, 0.3, 3),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = ScreenGui,
})
corner(Shadow, 6)

local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.new(0, W, 0, H),
    Position = UDim2.new(0.03, 0, 0.3, 0),
    BackgroundColor3 = Theme.Bg,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
    ClipsDescendants = true,
    ZIndex = 1,
    Parent = ScreenGui,
})
corner(Main, 6)
stroke(Main, Theme.Border, 1, 0)

Main:GetPropertyChangedSignal("Position"):Connect(function()
    Shadow.Position = Main.Position + UDim2.new(0, 3, 0, 3)
end)

local Rail = new("Frame", {
    Name = "Rail",
    Size = UDim2.new(0, RAIL, 1, 0),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Main,
})
corner(Rail, 6)
new("Frame", {
    Size = UDim2.new(0, 6, 1, 0),
    Position = UDim2.new(1, -6, 0, 0),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Rail,
})

local Logo = new("Frame", {
    Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(0, 18, 0, 16),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    ZIndex = 3,
    Parent = Rail,
})
corner(Logo, 3)

new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "A",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 13,
    ZIndex = 4,
    Parent = Logo,
})

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 0, 42),
    BackgroundTransparency = 1,
    Text = "aimlock",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 9,
    ZIndex = 3,
    Parent = Rail,
})

new("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 0, 62),
    BackgroundColor3 = Theme.BorderSoft,
    BorderSizePixel = 0,
    ZIndex = 3,
    Parent = Rail,
})

local tabs = {}
local function makeTab(id, label, y)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -16, 0, 32),
        Position = UDim2.new(0, 8, 0, y),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 3,
        Parent = Rail,
    })
    corner(btn, 4)

    local bar = new("Frame", {
        Name = "Bar",
        Size = UDim2.new(0, 2, 0, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = btn,
    })
    corner(bar, 1)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Theme.TextSub,
        Font = Theme.FontMed,
        TextSize = 11,
        ZIndex = 4,
        Parent = btn,
    })

    btn.MouseEnter:Connect(function()
        if State.ActiveTab ~= id then
            btn.BackgroundColor3 = Theme.Card
            lbl.TextColor3 = Theme.TextDim
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.ActiveTab ~= id then
            btn.BackgroundColor3 = Theme.Sidebar
            lbl.TextColor3 = Theme.TextSub
        end
    end)

    tabs[id] = { btn = btn, bar = bar, lbl = lbl }
    return btn
end

local MainTabBtn   = makeTab("main",   "MAIN",   76)
local ConfigTabBtn = makeTab("config", "CONFIG", 112)

local RailUnload = new("TextButton", {
    Size = UDim2.new(1, -16, 0, 24),
    Position = UDim2.new(0, 8, 1, -32),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0,
    Text = "exit",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 10,
    AutoButtonColor = false,
    ZIndex = 3,
    Parent = Rail,
})
corner(RailUnload, 4)
RailUnload.MouseEnter:Connect(function()
    RailUnload.BackgroundColor3 = Theme.Danger
    RailUnload.TextColor3 = Theme.Text
end)
RailUnload.MouseLeave:Connect(function()
    RailUnload.BackgroundColor3 = Theme.Sidebar
    RailUnload.TextColor3 = Theme.TextSub
end)

local Right = new("Frame", {
    Name = "Right",
    Size = UDim2.new(1, -RAIL, 1, 0),
    Position = UDim2.new(0, RAIL, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Parent = Main,
})

local Header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Theme.BgAlt,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Right,
})
corner(Header, 6)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 6),
    Position = UDim2.new(0, 0, 1, -6),
    BackgroundColor3 = Theme.BgAlt,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Header,
})

local HeaderTitle = new("TextLabel", {
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "MAIN",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
    Parent = Header,
})

local StatusBadge = new("Frame", {
    Size = UDim2.new(0, 54, 0, 20),
    Position = UDim2.new(1, -68, 0.5, -10),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    ZIndex = 3,
    Parent = Header,
})
corner(StatusBadge, 3)
stroke(StatusBadge, Theme.BorderSoft, 1, 0)

local StatusDot = new("Frame", {
    Size = UDim2.new(0, 6, 0, 6),
    Position = UDim2.new(0, 8, 0.5, -3),
    BackgroundColor3 = Theme.Off,
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = StatusBadge,
})
corner(StatusDot, 3)

local StatusText = new("TextLabel", {
    Size = UDim2.new(1, -20, 1, 0),
    Position = UDim2.new(0, 18, 0, 0),
    BackgroundTransparency = 1,
    Text = "OFF",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
    Parent = StatusBadge,
})

new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = Theme.BorderSoft,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Right,
})

local function makePage(name)
    local p = new("Frame", {
        Name = name,
        Size = UDim2.new(1, -24, 1, -58),
        Position = UDim2.new(0, 12, 0, 56),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 3,
        Parent = Right,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = p,
    })
    return p
end

local MainPage   = makePage("MainPage")
local ConfigPage = makePage("ConfigPage")

local ToggleCard = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    LayoutOrder = 1,
    ZIndex = 3,
    Parent = MainPage,
})
corner(ToggleCard, 4)
local toggleStroke = stroke(ToggleCard, Theme.BorderSoft, 1, 0)

local ToggleAccent = new("Frame", {
    Size = UDim2.new(0, 2, 1, -16),
    Position = UDim2.new(0, 0, 0, 8),
    BackgroundColor3 = Theme.Off,
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = ToggleCard,
})
corner(ToggleAccent, 1)

new("TextLabel", {
    Size = UDim2.new(1, -70, 0, 16),
    Position = UDim2.new(0, 16, 0, 10),
    BackgroundTransparency = 1,
    Text = "aimlock",
    TextColor3 = Theme.Text,
    Font = Theme.FontBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
    Parent = ToggleCard,
})

new("TextLabel", {
    Size = UDim2.new(1, -70, 0, 12),
    Position = UDim2.new(0, 16, 0, 28),
    BackgroundTransparency = 1,
    Text = "toggle to lock nearest target",
    TextColor3 = Theme.TextSub,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
    Parent = ToggleCard,
})

local Switch = new("Frame", {
    Size = UDim2.new(0, 34, 0, 18),
    Position = UDim2.new(1, -48, 0.5, -9),
    BackgroundColor3 = Theme.Off,
    BorderSizePixel = 0,
    ZIndex = 4,
    Parent = ToggleCard,
})
corner(Switch, 3)

local SwitchKnob = new("Frame", {
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 3, 0.5, -6),
    BackgroundColor3 = Theme.TextDim,
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = Switch,
})
corner(SwitchKnob, 2)

local TargetCard = new("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    ZIndex = 3,
    Parent = MainPage,
})
corner(TargetCard, 4)
stroke(TargetCard, Theme.BorderSoft, 1, 0)

new("TextLabel", {
    Size = UDim2.new(0, 60, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "TARGET",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
    Parent = TargetCard,
})

local TargetLbl = new("TextLabel", {
    Size = UDim2.new(1, -84, 1, 0),
    Position = UDim2.new(0, 70, 0, 0),
    BackgroundTransparency = 1,
    Text = "—",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 4,
    Parent = TargetCard,
})
new("UIPadding", { PaddingRight = UDim.new(0, 14), Parent = TargetLbl })

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "HITBOX PART",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 3,
    Parent = MainPage,
})

local PartHolder = new("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    LayoutOrder = 4,
    ZIndex = 5,
    Parent = MainPage,
})
corner(PartHolder, 4)
stroke(PartHolder, Theme.BorderSoft, 1, 0)

local PartHeader = new("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
    Parent = PartHolder,
})

local PartCur = new("TextLabel", {
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = State.SelectedPart,
    TextColor3 = Theme.Text,
    Font = Theme.FontMed,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = PartHeader,
})

local Chevron = new("TextLabel", {
    Size = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(1, -30, 0, 0),
    BackgroundTransparency = 1,
    Text = "▾",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontBold,
    TextSize = 11,
    ZIndex = 7,
    Parent = PartHeader,
})

local PartList = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 170),
    Position = UDim2.new(0, 0, 1, 6),
    BackgroundColor3 = Theme.BgAlt,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(0, 0, 0, #PARTS * 22 + 8),
    Parent = PartHolder,
})
corner(PartList, 4)
stroke(PartList, Theme.Accent, 1, 0.4)
new("UIListLayout", {
    Padding = UDim.new(0, 1),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = PartList,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    Parent = PartList,
})

for i, name in ipairs(PART_NAMES) do
    local item = new("TextButton", {
        Size = UDim2.new(1, -8, 0, 22),
        BackgroundColor3 = Theme.BgAlt,
        Text = "  " .. name,
        TextColor3 = Theme.TextDim,
        Font = Theme.Font,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = i,
        ZIndex = 51,
        Parent = PartList,
    })
    corner(item, 3)
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
        Chevron.Rotation = 0
        cache.cachedTargetPart = nil
        cache.cachedTargetChar = nil
    end)
end

PartHeader.MouseButton1Click:Connect(function()
    PartList.Visible = not PartList.Visible
    TweenService:Create(Chevron, TweenInfo.new(0.18), {
        Rotation = PartList.Visible and 180 or 0,
    }):Play()
end)

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "SMOOTH",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 5,
    Parent = MainPage,
})

local SmoothRow = new("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    LayoutOrder = 6,
    Parent = MainPage,
})

local SmoothVal = new("TextLabel", {
    Size = UDim2.new(0, 40, 0, 12),
    Position = UDim2.new(1, -40, 0, 0),
    BackgroundTransparency = 1,
    Text = tostring(State.Smooth),
    TextColor3 = Theme.Accent,
    Font = Theme.FontMed,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = SmoothRow,
})

local Track = new("Frame", {
    Size = UDim2.new(1, 0, 0, 4),
    Position = UDim2.new(0, 0, 0, 20),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Parent = SmoothRow,
})
corner(Track, 2)
stroke(Track, Theme.BorderSoft, 1, 0.4)

local Fill = new("Frame", {
    Size = UDim2.new((State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN), 0, 1, 0),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Parent = Track,
})
corner(Fill, 2)

local Knob = new("Frame", {
    Size = UDim2.new(0, 11, 0, 11),
    Position = UDim2.new((State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN), -5.5, 0.5, -5.5),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = Track,
})
corner(Knob, 6)
stroke(Knob, Theme.Accent, 2, 0)

local TrackHit = new("TextButton", {
    Size = UDim2.new(1, 16, 0, 22),
    Position = UDim2.new(0, -8, 0, 11),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 5,
    Parent = SmoothRow,
})

local function updateSmoothVisual()
    local ratio = (State.Smooth - SMOOTH_MIN) / (SMOOTH_MAX - SMOOTH_MIN)
    Fill.Size = UDim2.new(ratio, 0, 1, 0)
    Knob.Position = UDim2.new(ratio, -5.5, 0.5, -5.5)
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

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "KEYBINDS",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 1,
    Parent = ConfigPage,
})

local function makeKeybindRow(order, labelText, hint, getter, setter)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        Parent = ConfigPage,
    })
    corner(row, 4)
    stroke(row, Theme.BorderSoft, 1, 0)

    new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 14),
        Position = UDim2.new(0, 14, 0, 4),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Theme.Text,
        Font = Theme.FontMed,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 12),
        Position = UDim2.new(0, 14, 0, 17),
        BackgroundTransparency = 1,
        Text = hint,
        TextColor3 = Theme.TextSub,
        Font = Theme.Font,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local keyBox = new("Frame", {
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(1, -74, 0.5, -10),
        BackgroundColor3 = Theme.BgAlt,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(keyBox, 3)
    stroke(keyBox, Theme.BorderSoft, 1, 0)

    local keyLbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = shortKeyName(getter()),
        TextColor3 = Theme.Accent,
        Font = Theme.FontMed,
        TextSize = 10,
        Parent = keyBox,
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
            keyLbl.TextColor3 = Theme.Accent
            State.AwaitingKey = false
            bindConn:Disconnect()
        end)
        track(bindConn)
    end)

    return row, keyLbl
end

local LockRow = makeKeybindRow(2, "lock key", "toggle aimlock on/off", function() return State.LockKey end, function(k) State.LockKey = k end)
local HideRow = makeKeybindRow(3, "hide ui",  "show/hide window",       function() return State.HideKey end, function(k) State.HideKey = k end)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundTransparency = 1,
    LayoutOrder = 4,
    Parent = ConfigPage,
})

new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundTransparency = 1,
    Text = "ABOUT",
    TextColor3 = Theme.TextSub,
    Font = Theme.FontMed,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 5,
    Parent = ConfigPage,
})

local About = new("Frame", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    LayoutOrder = 6,
    Parent = ConfigPage,
})
corner(About, 4)
stroke(About, Theme.BorderSoft, 1, 0)

new("TextLabel", {
    Size = UDim2.new(1, -20, 0, 14),
    Position = UDim2.new(0, 14, 0, 8),
    BackgroundTransparency = 1,
    Text = "aimlock · obsidian edition",
    TextColor3 = Theme.Text,
    Font = Theme.FontMed,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = About,
})

new("TextLabel", {
    Size = UDim2.new(1, -20, 0, 12),
    Position = UDim2.new(0, 14, 0, 26),
    BackgroundTransparency = 1,
    Text = "made by puppydog",
    TextColor3 = Theme.Accent,
    Font = Theme.Font,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = About,
})

local UnloadRow = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = Theme.Card,
    BorderSizePixel = 0,
    Text = "unload script",
    TextColor3 = Theme.TextDim,
    Font = Theme.FontMed,
    TextSize = 11,
    AutoButtonColor = false,
    LayoutOrder = 7,
    Parent = ConfigPage,
})
corner(UnloadRow, 4)
stroke(UnloadRow, Theme.Danger, 1, 0.5)
UnloadRow.MouseEnter:Connect(function()
    TweenService:Create(UnloadRow, TweenInfo.new(0.15), {
        BackgroundColor3 = Theme.Danger, TextColor3 = Theme.Text,
    }):Play()
end)
UnloadRow.MouseLeave:Connect(function()
    TweenService:Create(UnloadRow, TweenInfo.new(0.15), {
        BackgroundColor3 = Theme.Card, TextColor3 = Theme.TextDim,
    }):Play()
end)

local function setTab(id)
    State.ActiveTab = id
    MainPage.Visible   = (id == "main")
    ConfigPage.Visible = (id == "config")
    HeaderTitle.Text = (id == "main") and "MAIN" or "CONFIG"

    for tid, t in pairs(tabs) do
        local active = (tid == id)
        t.btn.BackgroundColor3 = active and Theme.Card or Theme.Sidebar
        t.lbl.TextColor3 = active and Theme.Text or Theme.TextSub
        local targetBarSize = active and UDim2.new(0, 2, 1, -8) or UDim2.new(0, 2, 0, 0)
        TweenService:Create(t.bar, TweenInfo.new(0.18), {Size = targetBarSize}):Play()
    end
end

MainTabBtn.MouseButton1Click:Connect(function() setTab("main") end)
ConfigTabBtn.MouseButton1Click:Connect(function() setTab("config") end)

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
    local knobX = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    TweenService:Create(Switch, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        BackgroundColor3 = on and Theme.Accent or Theme.Off,
    }):Play()
    TweenService:Create(SwitchKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Position = knobX,
        BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.TextDim,
    }):Play()
    TweenService:Create(ToggleAccent, TweenInfo.new(0.25), {
        BackgroundColor3 = on and Theme.Accent or Theme.Off,
    }):Play()
    TweenService:Create(toggleStroke, TweenInfo.new(0.25), {
        Transparency = on and 0.5 or 0,
    }):Play()

    StatusDot.BackgroundColor3 = on and Theme.On or Theme.Off
    StatusText.Text = on and "ON" or "OFF"
    StatusText.TextColor3 = on and Theme.On or Theme.TextSub
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
    Shadow.Visible = not v
    if v then PartList.Visible = false end
end

local function unload()
    if State.Unloaded then return end
    State.Unloaded = true
    State.Enabled = false
    State.LockedPlayer = nil

    pcall(function() RunService:UnbindFromRenderStep("ObsidianAimCam") end)

    for _, c in ipairs(Connections) do
        if typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    Connections = {}

    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end
    print("[puppydog] Obsidian Aimlock unloaded")
end

ToggleCard.MouseButton1Click:Connect(function()
    setEnabled(not State.Enabled)
end)
ToggleCard.MouseEnter:Connect(function()
    TweenService:Create(ToggleCard, TweenInfo.new(0.12), {BackgroundColor3 = Theme.CardHover}):Play()
end)
ToggleCard.MouseLeave:Connect(function()
    TweenService:Create(ToggleCard, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Card}):Play()
end)

UnloadRow.MouseButton1Click:Connect(unload)
RailUnload.MouseButton1Click:Connect(unload)

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

RunService:BindToRenderStep("ObsidianAimCam", Enum.RenderPriority.Camera.Value + 1, cameraStep)

updateSmoothVisual()
setTab("main")
print("[puppydog] Obsidian Aimlock loaded — made by puppydog")