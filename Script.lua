local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "ICheat",
   LoadingTitle = "Loading ICheat…",
   LoadingSubtitle = "by ICheats",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "ICheatConfig"
   },
   Discord = {
      Enabled = false,
      Invite = "",
      RememberJoins = true
   },
   KeySystem = false,
   KeySettings = {
      Title = "ICheat",
      Subtitle = "Key System",
      Note = "Get key from Discord",
      FileName = "ICheatKey",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"Hello"}
   },
Theme = "DarkBlue"
})

-- Main Tab (add your cheats here)
local MainTab = Window:CreateTab("Main", 4483362458)
local MainSection = MainTab:CreateSection("Features")

-- Example Toggle (you can add more)
MainTab:CreateToggle({
   Name = "Example Feature",
   CurrentValue = false,
   Flag = "ExampleToggle",
   Callback = function(Value)
      -- Your code here (no prints/notifications)
   end,
})

local AimTab = Window:CreateTab("Aimbot", 4483362458)
local Aimse = AimTab:CreateSection("Controller AB")

-- ──────────────────────────────────────────────────────────────
--  Services & Locals
-- ──────────────────────────────────────────────────────────────
local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local CoreGui         = game:GetService("CoreGui")
 
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
 
-- ──────────────────────────────────────────────────────────────
--  State Variables
-- ──────────────────────────────────────────────────────────────
local targetHead      = nil
local isLocked        = false
local lockOnEnabled   = false       -- master switch (via toggle)
local showFOVCircle   = false        -- controlled by FOV Toggle
local showStatusGUI   = false        -- controlled by UI Toggle
 
local circleRadius    = 100
local MIN_RADIUS      = 50
local MAX_RADIUS      = 250
 
-- UI Elements
local lockOnCircle    = nil
local lockOnStroke    = nil
local statusGui       = nil         -- we'll create lazily
 
-- ──────────────────────────────────────────────────────────────
--  Status GUI (top-right panel)
-- ──────────────────────────────────────────────────────────────
local function updateLockOnGUI()
    if not showStatusGUI then
        if statusGui then statusGui.Enabled = false end
        return
    end
 
    local sgName = "ICheatLockStatus"
    statusGui = CoreGui:FindFirstChild(sgName)
    if not statusGui then
        statusGui = Instance.new("ScreenGui")
        statusGui.Name = sgName
        statusGui.ResetOnSpawn = false
        statusGui.Parent = CoreGui
    end
    statusGui.Enabled = true
 
    local frame = statusGui:FindFirstChild("MainFrame")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name = "MainFrame"
        frame.Size             = UDim2.new(0, 220, 0, 80)
        frame.Position         = UDim2.new(1, -240, 0, 30)
        frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        frame.BackgroundTransparency = 0.40
        frame.BorderSizePixel  = 0
        frame.Parent = statusGui
 
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
 
        local stroke = Instance.new("UIStroke")
        stroke.Thickness    = 1.2
        stroke.Color        = Color3.fromRGB(90, 90, 90)
        stroke.Transparency = 0.5
        stroke.Parent = frame
    end
 
    local function getOrCreateLabel(name, yPos, default)
        local lbl = frame:FindFirstChild(name)
        if not lbl then
            lbl = Instance.new("TextLabel")
            lbl.Name = name
            lbl.Size               = UDim2.new(1, -20, 0, 28)
            lbl.Position           = UDim2.new(0, 10, 0, yPos)
            lbl.BackgroundTransparency = 1
            lbl.Font               = Enum.Font.GothamSemibold
            lbl.TextSize           = 17
            lbl.TextXAlignment     = Enum.TextXAlignment.Left
            lbl.RichText           = true
            lbl.Text               = default
            lbl.Parent = frame
        end
        return lbl
    end
 
    local statusLabel = getOrCreateLabel("Status", 12, "")
    local targetLabel = getOrCreateLabel("Target", 45, "")
 
    statusLabel.Text = isLocked 
        and "Lock-On: <font color='rgb(80,255,120)'>ON</font>" 
        or  "Lock-On: <font color='rgb(255,80,80)'>OFF</font>"
 
    if isLocked and targetHead and targetHead.Parent then
        local character = targetHead.Parent
        local player = Players:GetPlayerFromCharacter(character)
        local name = player and player.Name or (character.Name or "Unknown")
        targetLabel.Text = "Locked: <font color='rgb(120,220,255)'>" .. name .. "</font>"
    else
        targetLabel.Text = "Locked: <font color='rgb(160,160,160)'>None</font>"
    end
end
 
-- ──────────────────────────────────────────────────────────────
--  FOV Circle (center screen)
-- ──────────────────────────────────────────────────────────────
local function updateFOVCircle()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local sg = pg:FindFirstChild("ICheatFOVCircle")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "ICheatFOVCircle"
        sg.ResetOnSpawn = false
        sg.Parent = pg
    end
 
    if not lockOnCircle then
        lockOnCircle = Instance.new("Frame")
        lockOnCircle.BackgroundTransparency = 1
        lockOnCircle.Parent = sg
 
        lockOnStroke = Instance.new("UIStroke")
        lockOnStroke.Thickness    = 2.5
        lockOnStroke.Transparency = 0.3
        lockOnStroke.Parent = lockOnCircle
 
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = lockOnCircle
    end
 
    local diameter = circleRadius * 2
    lockOnCircle.Size     = UDim2.new(0, diameter, 0, diameter)
    lockOnCircle.Position = UDim2.new(0.5, -diameter/2, 0.5, -diameter/2)
    lockOnCircle.Visible  = lockOnEnabled and showFOVCircle
 
    lockOnStroke.Color = isLocked and Color3.fromRGB(80, 255, 120)
                       or  Color3.fromRGB(100, 180, 255)
end
 
-- ──────────────────────────────────────────────────────────────
--  Helpers
-- ──────────────────────────────────────────────────────────────
local function isInsideFOV(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    if not onScreen then return false end
 
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    return dist <= circleRadius
end
 
local function findClosestTarget()
    local bestHead, bestDist = nil, math.huge
 
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
 
        local head = char:FindFirstChild("Head")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not (head and hum and hum.Health > 0.1) then continue end
 
        if isInsideFOV(head.Position) then
            local dist = (Camera.CFrame.Position - head.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestHead = head
            end
        end
    end
 
    return bestHead
end
 
-- ──────────────────────────────────────────────────────────────
--  Input – R3 to lock / unlock
-- ──────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR3 then
        if not lockOnEnabled then return end
 
        if isLocked then
            isLocked = false
            targetHead = nil
        else
            targetHead = findClosestTarget()
            isLocked = targetHead ~= nil
        end
 
        updateLockOnGUI()
        updateFOVCircle()
    end
end)
 
-- ──────────────────────────────────────────────────────────────
--  Main Loops
-- ──────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not isLocked or not targetHead then return end
 
    if not targetHead.Parent or not targetHead.Parent.Parent then
        isLocked = false
        targetHead = nil
        updateLockOnGUI()
        updateFOVCircle()
        return
    end
 
    local hum = targetHead.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0.1 then
        isLocked = false
        targetHead = nil
        updateLockOnGUI()
        updateFOVCircle()
    end
end)
 
RunService.RenderStepped:Connect(function()
    if isLocked and targetHead and targetHead.Parent then
        -- Snap camera to target head
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHead.Position)
 
        -- Optional: silent aim style (commented — you can expand this)
        -- local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        -- if tool and tool:FindFirstChild("Handle") then
        --     -- manipulate bullet direction / raycast here
        -- end
    end
end)
 
-- ──────────────────────────────────────────────────────────────
--  UI Controls
-- ──────────────────────────────────────────────────────────────
 
AimTab:CreateToggle({
    Name = "Enable Lock-on",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(enabled)
        lockOnEnabled = enabled
        if not enabled then
            isLocked = false
            targetHead = nil
        end
        updateLockOnGUI()
        updateFOVCircle()
    end,
})
 
AimTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = false,
    Flag = "FOVCircleToggle",
    Callback = function(enabled)
        showFOVCircle = enabled
        updateFOVCircle()
    end,
})
 
AimTab:CreateToggle({
    Name = "Show Status GUI",
    CurrentValue = false,
    Flag = "StatusGUIToggle",
    Callback = function(enabled)
        showStatusGUI = enabled
        updateLockOnGUI()
    end,
})
 
AimTab:CreateSlider({
    Name = "FOV Circle Size",
    Range = {MIN_RADIUS, MAX_RADIUS},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 100,
    Flag = "FOVSlider",
    Callback = function(value)
        circleRadius = value
        updateFOVCircle()
    end,
})
 
-- Initial setup
updateLockOnGUI()
updateFOVCircle()

-- Create new "Player" tab
local PlayerTab = Window:CreateTab("Player", 4483362458)  -- Tab icon (roblox asset id)
local PlayerSection = PlayerTab:CreateSection("Movement")

-- Speed Toggle
local speedEnabled = false
local currentSpeed = 16

local SpeedToggle = PlayerTab:CreateToggle({
   Name = "WS Toggle",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(Value)
      speedEnabled = Value
      local humanoid = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
      if humanoid then
         if Value then
            humanoid.WalkSpeed = currentSpeed
         else
            humanoid.WalkSpeed = 16
         end
      end
   end,
})

-- Speed Slider (16-99)
local SpeedSlider = PlayerTab:CreateSlider({
   Name = "Walk Speed",
   Range = {16, 99},
   Increment = 1,
   Suffix = "",
   CurrentValue = 16,
   Flag = "SpeedSlider",
   Callback = function(Value)
      currentSpeed = Value
      if speedEnabled then
         local humanoid = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
         if humanoid then
            humanoid.WalkSpeed = Value
         end
      end
   end,
})

local enabled = false
local multiplier = 0.5

PlayerTab:CreateToggle({
   Name = "CFrame Toggle",
   CurrentValue = false,
   Flag = "EnableToggle",
   Callback = function(Value)
      enabled = Value
   end,
})

PlayerTab:CreateSlider({
   Name = "CFrame Speed",
   Range = {0.1, 5},  -- From 0.1 to 5 (higher = faster, Neverlose used 0.5 default)
   Increment = 0.1,
   Suffix = "",
   CurrentValue = 0.5,
   Flag = "SpeedSlider",
   Callback = function(Value)
      multiplier = Value
   end,
})

-- CFrame movement loop (taken & adapted from Neverlose script)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

RunService.RenderStepped:Connect(function()
   if not enabled then return end

   local char = game.Players.LocalPlayer.Character
   if not char or not char:FindFirstChild("HumanoidRootPart") then return end

   local root = char.HumanoidRootPart
   local hum = char:FindFirstChild("Humanoid")

   if hum.Health <= 0 then return end

   local moveDir = hum.MoveDirection  -- This works for both keyboard and mobile thumbstick

   if moveDir.Magnitude > 0 then
      root.CFrame = root.CFrame + moveDir * multiplier
   end
end)

-- Re-apply on respawn (automatic since loop checks character)
game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
   task.wait(0.5)
   -- No extra code needed - loop handles it
end)

-- Re-apply speed on character respawn
game.Players.LocalPlayer.CharacterAdded:Connect(function(char)
   task.wait(0.5)
   local humanoid = char:FindFirstChildOfClass("Humanoid")
   if humanoid then
      if speedEnabled then
         humanoid.WalkSpeed = currentSpeed
      else
         humanoid.WalkSpeed = 16
      end
   end
end)

local Noclip = nil
local Clip = nil

function noclip()
	Clip = false
	local function Nocl()
		if Clip == false and game.Players.LocalPlayer.Character ~= nil then
			for _,v in pairs(game.Players.LocalPlayer.Character:GetDescendants()) do
				if v:IsA('BasePart') and v.CanCollide and v.Name ~= floatName then
					v.CanCollide = false
				end
			end
		end
		wait(0.21) -- basic optimization
	end
	Noclip = game:GetService('RunService').Stepped:Connect(Nocl)
end

function clip()
	if Noclip then Noclip:Disconnect() end
	Clip = true
end

c = false

local nToggle = PlayerTab:CreateToggle({
   Name = "Noclip",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(Value)
c = not c
if c == true then
noclip() else clip() end
   end,
})

local InfiniteJumpEnabled = false

local ijToggle = PlayerTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "SpeedToggle",
   Callback = function(Value)
     InfiniteJumpEnabled = not InfiniteJumpEnabled
game:GetService("UserInputService").JumpRequest:connect(function()
	if InfiniteJumpEnabled then
game:GetService"Players".LocalPlayer.Character:FindFirstChildOfClass'Humanoid':ChangeState("Jumping")
	end
end)
   end,
})

-- Visual Tab
local VisualTab = Window:CreateTab("Visual", 4483362458)
local VisualSection = VisualTab:CreateSection("Player Visuals")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = game:GetService("Workspace").CurrentCamera
 
-- Check for Drawing API availability
local function API_Check()
    if Drawing == nil then
        return "No"
    else
        return "Yes"
    end
end
 
local Find_Required = API_Check()
 
if Find_Required == "No" then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Unsupported Exploit",
        Text = "Tracer script could not load due to an unsupported exploit.",
        Duration = 10,
        Button1 = "OK"
    })
    return
end
 
-- Global settings
_G.TeamCheck = false         -- Tracers for all players, not just enemies
_G.FromMouse = false         -- Tracers from mouse (off by default)
_G.FromCenter = false        -- Tracers from center (off by default)
_G.FromBottom = true         -- Tracers from bottom (default)
_G.TracersVisible = false     -- Tracers start enabled
_G.TracerColor = Color3.fromRGB(255, 255, 255) -- White tracers
_G.TracerThickness = 1       -- Thin tracers
_G.TracerTransparency = 0.7  -- Slightly transparent

_G.TeamCheck = false            -- Boxes for all players, not just enemies
_G.SquaresVisible = false        -- Boxes start enabled
_G.SquareColor = Color3.fromRGB(255, 255, 255) -- White boxes
_G.SquareThickness = 1          -- Thin boxes
_G.SquareFilled = false         -- Outline only (not filled)
_G.SquareTransparency = 0.7     -- Slightly transparent
_G.HeadOffset = Vector3.new(0, 0.5, 0) -- Offset for head position
_G.LegsOffset = Vector3.new(0, 3, 0)   -- Offset for legs position

local function CreateTracers()
    for _, v in next, Players:GetPlayers() do
        if v.Name ~= Players.LocalPlayer.Name then
            local TracerLine = Drawing.new("Line")
 
            RunService.RenderStepped:Connect(function()
                if workspace:FindFirstChild(v.Name) and workspace[v.Name]:FindFirstChild("HumanoidRootPart") then
                    local rootPart = workspace[v.Name].HumanoidRootPart
                    local rootPos = rootPart.CFrame * CFrame.new(0, -rootPart.Size.Y, 0).p
                    local vector, onScreen = Camera:WorldToViewportPoint(rootPos)
 
                    TracerLine.Thickness = _G.TracerThickness
                    TracerLine.Transparency = _G.TracerTransparency
                    TracerLine.Color = _G.TracerColor
 
                    if _G.FromMouse then
                        TracerLine.From = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
                    elseif _G.FromCenter then
                        TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    elseif _G.FromBottom then
                        TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    end
 
                    if onScreen then
                        TracerLine.To = Vector2.new(vector.X, vector.Y)
                        if _G.TeamCheck then
                            TracerLine.Visible = Players.LocalPlayer.Team ~= v.Team and _G.TracersVisible
                        else
                            TracerLine.Visible = _G.TracersVisible
                        end
                    else
                        TracerLine.Visible = false
                    end
                else
                    TracerLine.Visible = false
                end
            end)
 
            Players.PlayerRemoving:Connect(function()
                TracerLine.Visible = false
            end)
        end
    end
 
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            if player.Name ~= Players.LocalPlayer.Name then
                local TracerLine = Drawing.new("Line")
 
                RunService.RenderStepped:Connect(function()
                    if workspace:FindFirstChild(player.Name) and workspace[player.Name]:FindFirstChild("HumanoidRootPart") then
                        local rootPart = workspace[player.Name].HumanoidRootPart
                        local rootPos = rootPart.CFrame * CFrame.new(0, -rootPart.Size.Y, 0).p
                        local vector, onScreen = Camera:WorldToViewportPoint(rootPos)
 
                        TracerLine.Thickness = _G.TracerThickness
                        TracerLine.Transparency = _G.TracerTransparency
                        TracerLine.Color = _G.TracerColor
 
                        if _G.FromMouse then
                            TracerLine.From = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
                        elseif _G.FromCenter then
                            TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        elseif _G.FromBottom then
                            TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        end
 
                        if onScreen then
                            TracerLine.To = Vector2.new(vector.X, vector.Y)
                            if _G.TeamCheck then
                                TracerLine.Visible = Players.LocalPlayer.Team ~= player.Team and _G.TracersVisible
                            else
                                TracerLine.Visible = _G.TracersVisible
                            end
                        else
                            TracerLine.Visible = false
                        end
                    else
                        TracerLine.Visible = false
                    end
                end)
 
                Players.PlayerRemoving:Connect(function()
                    TracerLine.Visible = false
                end)
            end
        end)
    end)
end
 
-- Initialize tracers
local Success, Error = pcall(function()
    CreateTracers()
end)
 

local function CreateSquares()
    for _, v in next, Players:GetPlayers() do
        if v ~= LocalPlayer then
            local Square = Drawing.new("Square")
            Square.Thickness = _G.SquareThickness
            Square.Transparency = _G.SquareTransparency
            Square.Color = _G.SquareColor
            Square.Filled = _G.SquareFilled
            Square.Visible = false -- Start invisible, enable only when valid
 
            RunService.RenderStepped:Connect(function()
                if v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Head") then
                    local rootPos = v.Character.HumanoidRootPart.Position
                    local headPos = v.Character.Head.Position + _G.HeadOffset
                    local legsPos = rootPos - _G.LegsOffset
 
                    local rootViewport, onScreen = Camera:WorldToViewportPoint(rootPos)
                    local headViewport = Camera:WorldToViewportPoint(headPos)
                    local legsViewport = Camera:WorldToViewportPoint(legsPos)
 
                    if onScreen and _G.SquaresVisible then
                        local height = math.abs(headViewport.Y - legsViewport.Y)
                        local width = height * 0.6 -- Proportional width
                        Square.Size = Vector2.new(width, height)
                        -- Center the box on the player by using rootViewport.Y adjusted by half the height
                        Square.Position = Vector2.new(rootViewport.X - width / 2, rootViewport.Y - height / 2)
                        Square.Visible = _G.TeamCheck and v.Team ~= LocalPlayer.Team or true
                    else
                        Square.Visible = false
                    end
                else
                    Square.Visible = false
                end
            end)
 
            Players.PlayerRemoving:Connect(function(player)
                if player == v then
                    Square:Remove()
                end
            end)
        end
    end
 
    Players.PlayerAdded:Connect(function(v)
        if v ~= LocalPlayer then
            local Square = Drawing.new("Square")
            Square.Thickness = _G.SquareThickness
            Square.Transparency = _G.SquareTransparency
            Square.Color = _G.SquareColor
            Square.Filled = _G.SquareFilled
            Square.Visible = false
 
            RunService.RenderStepped:Connect(function()
                if v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Head") then
                    local rootPos = v.Character.HumanoidRootPart.Position
                    local headPos = v.Character.Head.Position + _G.HeadOffset
                    local legsPos = rootPos - _G.LegsOffset
 
                    local rootViewport, onScreen = Camera:WorldToViewportPoint(rootPos)
                    local headViewport = Camera:WorldToViewportPoint(headPos)
                    local legsViewport = Camera:WorldToViewportPoint(legsPos)
 
                    if onScreen and _G.SquaresVisible then
                        local height = math.abs(headViewport.Y - legsViewport.Y)
                        local width = height * 0.6
                        Square.Size = Vector2.new(width, height)
                        Square.Position = Vector2.new(rootViewport.X - width / 2, rootViewport.Y - height / 2)
                        Square.Visible = _G.TeamCheck and v.Team ~= LocalPlayer.Team or true
                    else
                        Square.Visible = false
                    end
                else
                    Square.Visible = false
                end
            end)
 
            Players.PlayerRemoving:Connect(function(player)
                if player == v then
                    Square:Remove()
                end
            end)
        end
    end)
end
 
-- Initialize GUI and boxes
local Success, Error = pcall(function()
    CreateSquares()
end)

-- Visual state variables
local espMasterEnabled = false
local chamsEnabled = false
local nameTagsEnabled = false
local teamCheckEnabled = true  -- NEW: Ignore teammates when ON

local visualElements = {} -- {player = {Highlight, Billboard}}

-- Update visuals for one player (with team check)
local function updatePlayerVisuals(player)
    if player == game.Players.LocalPlayer then return end

    local char = player.Character
    if not char or not char:FindFirstChild("Head") or not char:FindFirstChildOfClass("Humanoid") then
        -- Cleanup
        if visualElements[player] then
            if visualElements[player].Highlight then visualElements[player].Highlight:Destroy() end
            if visualElements[player].Billboard then visualElements[player].Billboard:Destroy() end
            visualElements[player] = nil
        end
        return
    end

    local head = char.Head
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid.Health <= 0 then return end

    -- Team check: Skip if same team and teamCheckEnabled
    if teamCheckEnabled and player.Team == LocalPlayer.Team and player.Team ~= nil then
        -- Cleanup visuals if previously shown
        if visualElements[player] then
            if visualElements[player].Highlight then visualElements[player].Highlight:Destroy() end
            if visualElements[player].Billboard then visualElements[player].Billboard:Destroy() end
            visualElements[player] = nil
        end
        return
    end

    if not visualElements[player] then visualElements[player] = {} end

    local teamColor = player.TeamColor and player.TeamColor.Color or Color3.fromRGB(200, 200, 200)

    -- Chams (Team-colored Highlight)
    if espMasterEnabled and chamsEnabled then
        if not visualElements[player].Highlight then
            local hl = Instance.new("Highlight")
            hl.Name = "ChamsHighlight"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0
            hl.FillColor = teamColor
            hl.OutlineColor = teamColor:Lerp(Color3.new(1,1,1), 0.5)
            hl.Parent = char
            visualElements[player].Highlight = hl
        else
            visualElements[player].Highlight.FillColor = teamColor
            visualElements[player].Highlight.OutlineColor = teamColor:Lerp(Color3.new(1,1,1), 0.5)
        end
    else
        if visualElements[player].Highlight then
            visualElements[player].Highlight:Destroy()
            visualElements[player].Highlight = nil
        end
    end

    -- Name Tags (Team-colored text)
    if espMasterEnabled and nameTagsEnabled then
        if not visualElements[player].Billboard then
            local bb = Instance.new("BillboardGui")
            bb.Name = "NameTag"
            bb.Adornee = head
            bb.Size = UDim2.new(0, 200, 0, 50)
            bb.StudsOffset = Vector3.new(0, 3.5, 0)
            bb.AlwaysOnTop = true
            bb.LightInfluence = 0
            bb.MaxDistance = 150

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 18
            label.TextStrokeTransparency = 0.6
            label.TextStrokeColor3 = Color3.new(0,0,0)
            label.TextColor3 = teamColor
            label.Text = player.Name
            label.Parent = bb

            bb.Parent = head
            visualElements[player].Billboard = bb
        else
            visualElements[player].Billboard.Adornee.TextLabel.TextColor3 = teamColor
        end
    else
        if visualElements[player].Billboard then
            visualElements[player].Billboard:Destroy()
            visualElements[player].Billboard = nil
        end
    end
end

-- Master toggle
local ESPMasterToggle = VisualTab:CreateToggle({
   Name = "ESP Master",
   CurrentValue = false,
   Flag = "ESPMaster",
   Callback = function(Value)
      espMasterEnabled = Value
      if not Value then
         -- Cleanup all
         for player, data in pairs(visualElements) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
         end
         visualElements = {}
      else
         -- Refresh
         for _, plr in ipairs(game.Players:GetPlayers()) do
            task.spawn(updatePlayerVisuals, plr)
         end
      end
   end,
})

-- Chams toggle
local ChamsToggle = VisualTab:CreateToggle({
   Name = "Chams (Team-Colored Highlight)",
   CurrentValue = false,
   Flag = "ChamsToggle",
   Callback = function(Value)
      chamsEnabled = Value
      if espMasterEnabled then
         for _, plr in ipairs(game.Players:GetPlayers()) do
            updatePlayerVisuals(plr)
         end
      end
   end,
})

-- Name Tags toggle
local NameTagsToggle = VisualTab:CreateToggle({
   Name = "Name Tags (Team-Colored Text)",
   CurrentValue = false,
   Flag = "NameTagsToggle",
   Callback = function(Value)
      nameTagsEnabled = Value
      if espMasterEnabled then
         for _, plr in ipairs(game.Players:GetPlayers()) do
            updatePlayerVisuals(plr)
         end
      end
   end,
})

-- NEW: Team Check toggle (ON = hide teammates)
local TeamCheckToggle = VisualTab:CreateToggle({
   Name = "Team Check (Hide Teammates)",
   CurrentValue = true,
   Flag = "TeamCheckToggle",
   Callback = function(Value)
      teamCheckEnabled = Value
      if espMasterEnabled then
         for _, plr in ipairs(game.Players:GetPlayers()) do
            updatePlayerVisuals(plr)
         end
      end
   end,
})

local TracerToggel = VisualTab:CreateToggle({
   Name = "Tracers",
   CurrentValue = false,
   Flag = "ESPMaster",
   Callback = function(Value)
   _G.TracersVisible = not _G.TracersVisible
   end,
})

local BoxToggel = VisualTab:CreateToggle({
   Name = "Boxes",
   CurrentValue = false,
   Flag = "ESPMaster",
   Callback = function(Value)
   _G.SquaresVisible = not _G.SquaresVisible
   end,
})

-- Auto-update system
game.Players.PlayerAdded:Connect(function(plr)
   plr.CharacterAdded:Connect(function()
      task.wait(0.5)
      if espMasterEnabled then
         updatePlayerVisuals(plr)
      end
   end)
   plr.CharacterRemoving:Connect(function()
      if visualElements[plr] then
         if visualElements[plr].Highlight then visualElements[plr].Highlight:Destroy() end
         if visualElements[plr].Billboard then visualElements[plr].Billboard:Destroy() end
         visualElements[plr] = nil
      end
   end)
end)

-- Initial scan
for _, plr in ipairs(game.Players:GetPlayers()) do
   if plr.Character then
      task.spawn(updatePlayerVisuals, plr)
   end
   plr.CharacterAdded:Connect(function()
      task.wait(0.5)
      if espMasterEnabled then
         updatePlayerVisuals(plr)
      end
   end)
   plr.CharacterRemoving:Connect(function()
      if visualElements[plr] then
         if visualElements[plr].Highlight then visualElements[plr].Highlight:Destroy() end
         if visualElements[plr].Billboard then visualElements[plr].Billboard:Destroy() end
         visualElements[plr] = nil
      end
   end)
end

-- Local player respawn handler
game.Players.LocalPlayer.CharacterAdded:Connect(function()
   task.wait(0.5)
   if espMasterEnabled then
      for _, plr in ipairs(game.Players:GetPlayers()) do
         updatePlayerVisuals(plr)
      end
   end
end)

local GameTab = Window:CreateTab("Game", 4483362458)
local Prox = GameTab:CreateSection("Proxys")

local enabled = false
local originalDurations = {}  -- Saves original HoldDuration for each prompt

local function setInstant(enable)
   enabled = enable

   if enable then
      -- First time: save originals
      if next(originalDurations) == nil then
         for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
               originalDurations[v] = v.HoldDuration
               v.HoldDuration = 0
            end
         end
      else
         -- Re-apply zero duration
         for prompt, _ in pairs(originalDurations) do
            if prompt and prompt.Parent then
               prompt.HoldDuration = 0
            end
         end
      end
   else
      -- Restore originals
      for prompt, origTime in pairs(originalDurations) do
         if prompt and prompt.Parent then
            prompt.HoldDuration = origTime
         end
      end
   end
end

GameTab:CreateToggle({
   Name = "Instant Proxy",
   CurrentValue = false,
   Flag = "InstantProxyToggle",
   Callback = function(Value)
      setInstant(Value)
   end,
})

-- Auto-apply to new prompts (even after toggle on)
workspace.DescendantAdded:Connect(function(v)
   if enabled and v:IsA("ProximityPrompt") then
      if not originalDurations[v] then
         originalDurations[v] = v.HoldDuration
      end
      v.HoldDuration = 0
   end
end)

local ExtraTab = Window:CreateTab("Extra", 4483362458)
local ExtraSel = ExtraTab:CreateSection("Scripts")
local Pl = ExtraTab:CreateButton({
   Name = "Prison Life",
   Callback = function()
loadstring(game:HttpGet("https://pastebin.com/raw/ScYckEDk"))()
   end,
})
local Ca = ExtraTab:CreateButton({
   Name = "Controller AB",
   Callback = function()
loadstring(game:HttpGet("https://pastebin.com/raw/tX1Earbr"))()
   end,
})
local EHB = ExtraTab:CreateButton({
   Name = "EHitbox",
   Callback = function()
loadstring(game:HttpGet("https://pastebin.com/raw/c2QAXbAZ"))()
   end,
})
