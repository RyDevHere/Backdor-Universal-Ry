-- RyDev | UNIVERSAL - Complete Gaming Suite

-- Invisible Configuration
getgenv().InvisibleSettings = {
    Enabled = false,
    ToggleKey = Enum.KeyCode.X,
    DefaultSpeed = 16,
    BoostedSpeed = 48,
    InvisibilityPosition = Vector3.new(-25.95, 84, 3537.55),
    
    -- Colors
    InvisibleColor = Color3.fromRGB(0, 170, 255),
    SpeedBoostColor = Color3.fromRGB(231, 76, 60),
    SuccessColor = Color3.fromRGB(46, 204, 113),
}

-- ESP Configuration
getgenv().ESPSettings = {
    Enabled = true,
    Laser = true,
    Name = true,
    Distance = true,
    Health = true,
    Box = true,
    TeamCheck = true,
    MaxDistance = 2000,
    
    -- Colors
    EnemyColor = Color3.fromRGB(255, 0, 0),
    FriendColor = Color3.fromRGB(0, 255, 0),
    LaserWidth = 0.15,
    
    -- Text Settings
    TextSize = 14,
    TextFont = Enum.Font.GothamBold
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Invisible System Variables
local playerState = {
    isInvisible = false,
    isSpeedBoosted = false,
    originalSpeed = getgenv().InvisibleSettings.DefaultSpeed,
}

-- ESP System Variables
local ESPObjects = {}

-- Spectator System Variables
local Active = false
local TargetList = {}
local CurrentIndex = 0
local CurrentTarget = nil

local FlingActive = false
local FlingThread = nil
local OriginalCFrame = nil

local FollowActive = false
local FollowConnection = nil
local FollowAnim = nil

local SendPartActive = false
local SendPartLoopThread = nil

-- FREEZE State
local FreezeConnection = nil
local OriginalWalkSpeed = 16
local OriginalJumpPower = 50

-- Network stabilizer placeholder
local NetworkConnection = nil

-- Colors - Blue & Black Theme
local COLORS = {
    DARK_BLUE = Color3.fromRGB(0, 40, 85),
    MEDIUM_BLUE = Color3.fromRGB(0, 80, 160),
    LIGHT_BLUE = Color3.fromRGB(0, 170, 255),
    NEON_BLUE = Color3.fromRGB(0, 200, 255),
    DARK_BLACK = Color3.fromRGB(5, 5, 10),
    MEDIUM_BLACK = Color3.fromRGB(15, 15, 20),
    LIGHT_BLACK = Color3.fromRGB(25, 25, 35),
    WHITE = Color3.fromRGB(255, 255, 255),
    GREEN = Color3.fromRGB(0, 255, 128),
    RED = Color3.fromRGB(255, 60, 60),
    GOLD = Color3.fromRGB(255, 215, 0)
}

-- Character refs untuk spectator
local humanoid, rootPart
local function refreshCharacterRefs()
    local char = LocalPlayer.Character
    if char then
        humanoid = char:FindFirstChildOfClass("Humanoid")
        rootPart = char:FindFirstChild("HumanoidRootPart")
        
        if humanoid then
            OriginalWalkSpeed = humanoid.WalkSpeed
            OriginalJumpPower = humanoid.JumpPower
        end
    else
        humanoid = nil
        rootPart = nil
    end
end
refreshCharacterRefs()

LocalPlayer.CharacterAdded:Connect(function(char)
    pcall(function()
        char:WaitForChild("Humanoid", 5)
        char:WaitForChild("HumanoidRootPart", 5)
    end)
    refreshCharacterRefs()

    if FollowActive then
        if FollowConnection then
            FollowConnection:Disconnect()
            FollowConnection = nil
        end
        if FollowAnim then
            pcall(function() FollowAnim:Stop() end)
            FollowAnim = nil
        end
        FollowActive = false
    end
end)

-- ========== SPECTATOR SYSTEM FUNCTIONS ==========

-- FREEZE CHARACTER SYSTEM
local function freezeCharacter()
    if FreezeConnection then
        FreezeConnection:Disconnect()
    end
    
    FreezeConnection = RunService.Heartbeat:Connect(function()
        if humanoid and rootPart then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            
            pcall(function()
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
    
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
end

local function unfreezeCharacter()
    if FreezeConnection then
        FreezeConnection:Disconnect()
        FreezeConnection = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = OriginalWalkSpeed
        humanoid.JumpPower = OriginalJumpPower
    end
end

-- SEND PART FUNCTIONS
local function OneTimeUnanchor()
    if _G.__JSY_UnanchorCooldown then return end
    _G.__JSY_UnanchorCooldown = true
    task.spawn(function()
        local start = tick()
        while tick() - start < 1 do
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("RopeConstraint") then
                    local p0 = obj.Attachment0 and obj.Attachment0.Parent
                    local p1 = obj.Attachment1 and obj.Attachment1.Parent
                    pcall(function() obj:Destroy() end)
                    if p0 and p0:IsA("BasePart") then p0.Anchored = false end
                    if p1 and p1:IsA("BasePart") then p1.Anchored = false end
                end
            end

            for _, part in ipairs(Workspace:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    part.AssemblyLinearVelocity = Vector3.new(math.random(-50,50), math.random(20,100), math.random(-50,50))
                end
            end

            task.wait(0.2)
        end
        _G.__JSY_UnanchorCooldown = false
    end)
end

local function GetAllPartsRecursive(parent)
    local parts = {}
    for _, obj in ipairs(parent:GetChildren()) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        elseif obj:IsA("Model") or obj:IsA("Folder") then
            for _, p in ipairs(GetAllPartsRecursive(obj)) do
                table.insert(parts, p)
            end
        end
    end
    return parts
end

local function EnableNetworkStabilizer()
    if NetworkConnection then return end
    pcall(function()
        NetworkConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                end
            end)
        end)
    end)
end

local function DisableNetworkStabilizer()
    if NetworkConnection then
        NetworkConnection:Disconnect()
        NetworkConnection = nil
    end
end

local function sendUnanchoredPartsToTarget(target)
    if not target or not target.Character then return end
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    EnableNetworkStabilizer()
    OneTimeUnanchor()

    local folder = Workspace:FindFirstChild("JSY_SendPartFolder") or Instance.new("Folder", Workspace)
    folder.Name = "JSY_SendPartFolder"

    local targetPart = folder:FindFirstChild("TargetPart") or Instance.new("Part", folder)
    targetPart.Name = "TargetPart"
    targetPart.Anchored = true
    targetPart.CanCollide = false
    targetPart.Transparency = 1
    targetPart.Size = Vector3.new(1,1,1)
    targetPart.CFrame = targetHRP.CFrame
    local attach1 = targetPart:FindFirstChild("Attachment") or Instance.new("Attachment", targetPart)

    local function ForcePart(v)
        if not v:IsA("BasePart") then return end
        if v.Anchored then return end
        if v.Parent and v.Parent:FindFirstChildOfClass("Humanoid") then return end
        if v.Name == "Handle" then return end

        local originalCFrame = v.CFrame
        local originalAnchored = v.Anchored
        local originalCanCollide = v.CanCollide

        for _, x in ipairs(v:GetChildren()) do
            if x:IsA("BodyMover") or x:IsA("AlignPosition") or x:IsA("Torque") or x:IsA("RocketPropulsion") or x:IsA("AlignOrientation") then
                pcall(function() x:Destroy() end)
            end
        end

        v.CanCollide = false

        local torque = Instance.new("Torque")
        torque.Parent = v
        torque.Torque = Vector3.new(100000,100000,100000)

        local align = Instance.new("AlignPosition")
        align.Parent = v
        align.MaxForce = math.huge
        align.MaxVelocity = math.huge
        align.Responsiveness = 200

        local attach2 = Instance.new("Attachment", v)
        torque.Attachment0 = attach2
        align.Attachment0 = attach2
        align.Attachment1 = attach1

        task.spawn(function()
            local started = tick()
            while tick() - started < 2 do
                if not v or not v.Parent then break end
                task.wait(0.05)
            end

            pcall(function()
                if v and v:IsA("BasePart") then
                    v.AssemblyLinearVelocity = Vector3.zero
                    v.AssemblyAngularVelocity = Vector3.zero
                end

                if align and align.Parent then align:Destroy() end
                if torque and torque.Parent then torque:Destroy() end
                
                for _, child in ipairs(v:GetChildren()) do
                    if child:IsA("Attachment") then
                        if child ~= attach1 then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end

                if v and v.Parent then
                    pcall(function()
                        v.CanCollide = originalCanCollide
                        v.Anchored = originalAnchored
                        task.wait(0.05)
                        v.CFrame = originalCFrame
                    end)
                end
            end)
        end)
    end

    local parts = GetAllPartsRecursive(Workspace)
    for _, p in ipairs(parts) do
        pcall(function()
            if not p.Anchored then
                ForcePart(p)
            end
        end)
    end

    task.spawn(function()
        local duration = 5
        local start = tick()
        while tick() - start < duration do
            if attach1 and targetHRP then
                pcall(function()
                    attach1.WorldCFrame = targetHRP.CFrame
                    targetPart.CFrame = targetHRP.CFrame
                end)
            end
            task.wait()
        end
        pcall(function() folder:Destroy() end)
        DisableNetworkStabilizer()
    end)
end

local function turnOffSendPart()
    if SendPartActive then
        SendPartActive = false
        unfreezeCharacter()
    end
end

-- TARGETING SYSTEM
local function getTargetablePlayers()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    return list
end

local function refreshTargetList()
    local oldTarget = CurrentTarget
    TargetList = getTargetablePlayers()
    
    if #TargetList == 0 then
        CurrentIndex = 0
        CurrentTarget = nil
        return
    end
    
    if oldTarget and table.find(TargetList, oldTarget) then
        CurrentIndex = table.find(TargetList, oldTarget)
        CurrentTarget = oldTarget
        return
    end
    
    if oldTarget then
        for i, player in ipairs(TargetList) do
            if player.UserId == oldTarget.UserId then
                CurrentIndex = i
                CurrentTarget = player
                return
            end
        end
    end
    
    if CurrentIndex < 1 or CurrentIndex > #TargetList then
        CurrentIndex = 1
    end
    
    CurrentTarget = TargetList[CurrentIndex]
end

local refreshDebounce = false
local function safeRefreshTargetList()
    if refreshDebounce then return end
    refreshDebounce = true
    
    refreshTargetList()
    
    task.wait(0.5)
    refreshDebounce = false
end

Players.PlayerAdded:Connect(function(plr) 
    task.wait(0.1)
    safeRefreshTargetList()
end)

Players.PlayerRemoving:Connect(function(plr)
    task.wait(0.1)
    safeRefreshTargetList()
    
    if CurrentTarget and plr == CurrentTarget then
        CurrentTarget = nil
        
        if FollowActive then
            stopFollow()
        end
        
        if FlingActive then
            FlingActive = false
        end
        
        if SendPartActive then
            turnOffSendPart()
        end
    end
end)

-- CAMERA SYSTEM
local CameraConnection
local function setupCameraSystem()
    if CameraConnection then
        CameraConnection:Disconnect()
    end
    
    CameraConnection = RunService.RenderStepped:Connect(function()
        if not Active then 
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                if Camera.CameraSubject ~= LocalPlayer.Character.Humanoid then
                    Camera.CameraSubject = LocalPlayer.Character.Humanoid
                end
            end
            return 
        end
        
        if CurrentTarget and CurrentTarget.Character then
            local hrp = CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                Camera.CameraSubject = hrp
            end
        else
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = LocalPlayer.Character.Humanoid
            end
        end
    end)
end

setupCameraSystem()

-- TELEPORT FUNCTION
local function teleportToTarget()
    if not CurrentTarget then 
        return 
    end
    local lpHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetHRP = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
    if lpHRP and targetHRP then
        lpHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
    end
end

-- KICK/FLING FUNCTION
local function flingLoop()
    while FlingActive do
        RunService.Heartbeat:Wait()
        local lpHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHRP = CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
        if lpHRP and targetHRP then
            local dir = (targetHRP.Position - lpHRP.Position)
            if dir.Magnitude > 0 then
                lpHRP.AssemblyLinearVelocity = dir.Unit * 500
            end
            lpHRP.CFrame = targetHRP.CFrame
        end
    end
end

local function toggleFling()
    if not CurrentTarget then 
        return 
    end
    local lpHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lpHRP then return end

    FlingActive = not FlingActive

    if FlingActive then
        OriginalCFrame = lpHRP.CFrame
        if not FlingThread then
            FlingThread = task.spawn(flingLoop)
        end
    else
        FlingActive = false
        FlingThread = nil
        task.defer(function()
            pcall(function()
                if lpHRP and OriginalCFrame then
                    lpHRP.AssemblyLinearVelocity = Vector3.zero
                    lpHRP.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.1)
                    lpHRP.CFrame = OriginalCFrame
                end
            end)
        end)
    end
end

-- FOLLOW FUNCTION
local function stopFollow()
    FollowActive = false
    if FollowConnection then FollowConnection:Disconnect() FollowConnection = nil end
    if FollowAnim then pcall(function() FollowAnim:Stop() end) FollowAnim = nil end
end

local function startFollowToTarget(target)
    if not target or not rootPart or not humanoid then return end
    FollowActive = true

    pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://100681208320300"
        FollowAnim = humanoid:LoadAnimation(anim)
        FollowAnim.Looped = true
        FollowAnim:Play()
    end)

    FollowConnection = RunService.Heartbeat:Connect(function()
        if not FollowActive then return end
        if not target.Character then stopFollow() return end
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then stopFollow() return end
        rootPart.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
    end)
end

local function toggleFollow()
    if FollowActive then
        stopFollow()
        return
    end
    if not CurrentTarget then 
        return 
    end
    refreshCharacterRefs()
    startFollowToTarget(CurrentTarget)
end

-- SEND PART FUNCTION
local function toggleSendPart()
    SendPartActive = not SendPartActive

    if SendPartActive then
        freezeCharacter()

        if not SendPartLoopThread then
            SendPartLoopThread = task.spawn(function()
                while SendPartActive do
                    if CurrentTarget and CurrentTarget.Character then
                        pcall(function()
                            sendUnanchoredPartsToTarget(CurrentTarget)
                        end)
                    end
                    task.wait(2.2)
                end
                SendPartLoopThread = nil
            end)
        end
    else
        unfreezeCharacter()
    end
end

-- ========== INVISIBLE SYSTEM FUNCTIONS ==========

local function createNotification(title, text)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 3,
    })
end

local function setCharacterTransparency(character, transparency)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            descendant.Transparency = transparency
        end
    end
end

local function getHumanoid()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("Humanoid")
end

local function getHumanoidRootPart()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

-- Invisible Core Functions
local function toggleInvisibility()
    if not LocalPlayer.Character then
        warn("Character not found")
        return
    end

    playerState.isInvisible = not playerState.isInvisible

    if playerState.isInvisible then
        local humanoidRootPart = getHumanoidRootPart()
        if not humanoidRootPart then
            warn("HumanoidRootPart not found")
            return
        end

        local savedPosition = humanoidRootPart.CFrame

        -- Move to invisibility position
        LocalPlayer.Character:MoveTo(getgenv().InvisibleSettings.InvisibilityPosition)
        task.wait(0.15)

        -- Create invisible seat
        local seat = Instance.new("Seat")
        seat.Name = "invischair"
        seat.Anchored = false
        seat.CanCollide = false
        seat.Transparency = 1
        seat.Position = getgenv().InvisibleSettings.InvisibilityPosition
        seat.Parent = workspace

        -- Weld seat to character
        local weld = Instance.new("Weld")
        weld.Part0 = seat
        weld.Part1 = LocalPlayer.Character:FindFirstChild("Torso") or LocalPlayer.Character:FindFirstChild("UpperTorso")
        weld.Parent = seat

        task.wait()
        seat.CFrame = savedPosition

        -- Set character transparency
        setCharacterTransparency(LocalPlayer.Character, 0.5)

        createNotification("Invisibility ON", "Kamu sekarang tidak terlihat")
    else
        -- Remove invisible chair
        local invisChair = workspace:FindFirstChild("invischair")
        if invisChair then
            invisChair:Destroy()
        end

        -- Restore character visibility
        if LocalPlayer.Character then
            setCharacterTransparency(LocalPlayer.Character, 0)
        end

        createNotification("Invisibility OFF", "Anda sekarang terlihat")
    end
end

local function toggleSpeedBoost()
    local humanoid = getHumanoid()
    if not humanoid then
        warn("Humanoid not found")
        return
    end

    playerState.isSpeedBoosted = not playerState.isSpeedBoosted

    if playerState.isSpeedBoosted then
        humanoid.WalkSpeed = getgenv().InvisibleSettings.BoostedSpeed
        createNotification("Speed Boost ON", "Kecepatan ditingkatkan!")
    else
        humanoid.WalkSpeed = playerState.originalSpeed
        createNotification("Speed Boost OFF", "Atur Ulang Kecepatan")
    end
end

local function resetPlayerState()
    playerState.isInvisible = false
    playerState.isSpeedBoosted = false

    -- Remove invisible chair
    local invisChair = workspace:FindFirstChild("invischair")
    if invisChair then
        invisChair:Destroy()
    end

    -- Restore character visibility
    if LocalPlayer.Character then
        setCharacterTransparency(LocalPlayer.Character, 0)
    end

    -- Reset speed
    local humanoid = getHumanoid()
    if humanoid then
        humanoid.WalkSpeed = playerState.originalSpeed
    end
end

-- ========== ESP SYSTEM FUNCTIONS ==========

local function GetTeamColor(player)
    if not getgenv().ESPSettings.TeamCheck then
        return getgenv().ESPSettings.EnemyColor
    end
    
    if player.Team == LocalPlayer.Team then
        return getgenv().ESPSettings.FriendColor
    else
        return getgenv().ESPSettings.EnemyColor
    end
end

local function CreateESP(player)
    if ESPObjects[player] then
        if ESPObjects[player].Beam then ESPObjects[player].Beam:Destroy() end
        if ESPObjects[player].Attachment0 then ESPObjects[player].Attachment0:Destroy() end
        if ESPObjects[player].Attachment1 then ESPObjects[player].Attachment1:Destroy() end
        if ESPObjects[player].Box then ESPObjects[player].Box:Destroy() end
        if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
    end
    
    local esp = {}
    
    -- Laser Beam
    if getgenv().ESPSettings.Laser then
        local LocalChar = LocalPlayer.Character
        local PlayerChar = player.Character
        
        if LocalChar and PlayerChar then
            local localRoot = LocalChar:FindFirstChild("HumanoidRootPart")
            local playerRoot = PlayerChar:FindFirstChild("HumanoidRootPart")
            
            if localRoot and playerRoot then
                local attachment0 = Instance.new("Attachment")
                attachment0.Name = "LaserAttachment0"
                attachment0.Parent = localRoot
                
                local attachment1 = Instance.new("Attachment")
                attachment1.Name = "LaserAttachment1"
                attachment1.Parent = playerRoot
                
                local beam = Instance.new("Beam")
                beam.Name = "RyDev_Laser"
                beam.Attachment0 = attachment0
                beam.Attachment1 = attachment1
                beam.Color = ColorSequence.new(GetTeamColor(player))
                beam.FaceCamera = true
                beam.Width0 = getgenv().ESPSettings.LaserWidth
                beam.Width1 = getgenv().ESPSettings.LaserWidth
                beam.Brightness = 1.5
                beam.LightEmission = 0.3
                beam.Enabled = getgenv().ESPSettings.Enabled and getgenv().ESPSettings.Laser
                beam.Parent = workspace
                
                esp.Beam = beam
                esp.Attachment0 = attachment0
                esp.Attachment1 = attachment1
            end
        end
    end
    
    -- Box ESP
    if getgenv().ESPSettings.Box then
        local box = Instance.new("BoxHandleAdornment")
        box.Name = player.Name .. "_Box"
        box.Size = Vector3.new(4, 6, 4)
        box.Color3 = GetTeamColor(player)
        box.Transparency = 0.3
        box.AlwaysOnTop = true
        box.ZIndex = 1
        box.Visible = false
        box.Parent = CoreGui
        
        esp.Box = box
    end
    
    -- Billboard GUI
    local billboard = Instance.new("BillboardGui")
    billboard.Name = player.Name .. "_Info"
    billboard.Size = UDim2.new(0, 200, 0, 80)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = getgenv().ESPSettings.MaxDistance
    billboard.Enabled = false
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.Parent = CoreGui
    
    -- Name Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = getgenv().ESPSettings.TextSize
    nameLabel.Font = getgenv().ESPSettings.TextFont
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Visible = getgenv().ESPSettings.Name
    nameLabel.Parent = billboard
    
    -- Distance Label
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "Distance"
    distanceLabel.Size = UDim2.new(1, 0, 0, 20)
    distanceLabel.Position = UDim2.new(0, 0, 0, 20)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0m"
    distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distanceLabel.TextSize = getgenv().ESPSettings.TextSize
    distanceLabel.Font = getgenv().ESPSettings.TextFont
    distanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distanceLabel.TextStrokeTransparency = 0.3
    distanceLabel.Visible = getgenv().ESPSettings.Distance
    distanceLabel.Parent = billboard
    
    -- Health Bar
    local healthBarContainer = Instance.new("Frame")
    healthBarContainer.Name = "HealthBar"
    healthBarContainer.Size = UDim2.new(1, 0, 0, 15)
    healthBarContainer.Position = UDim2.new(0, 0, 0, 40)
    healthBarContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBarContainer.BorderSizePixel = 1
    healthBarContainer.BorderColor3 = Color3.fromRGB(0, 0, 0)
    healthBarContainer.Visible = getgenv().ESPSettings.Health
    healthBarContainer.Parent = billboard
    
    local healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthFill"
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarContainer
    
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(1, 0, 1, 0)
    healthText.BackgroundTransparency = 1
    healthText.Text = "100/100"
    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthText.TextSize = getgenv().ESPSettings.TextSize - 2
    healthText.Font = Enum.Font.Gotham
    healthText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthText.TextStrokeTransparency = 0.3
    healthText.Parent = healthBarContainer
    
    esp.Billboard = billboard
    esp.NameLabel = nameLabel
    esp.DistanceLabel = distanceLabel
    esp.HealthBar = healthBarFill
    esp.HealthText = healthText
    
    ESPObjects[player] = esp
    return esp
end

local function UpdateESP(player, esp)
    if not getgenv().ESPSettings.Enabled then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    local character = player.Character
    if not character then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not head or not rootPart then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    -- Team Check
    if getgenv().ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    -- Distance Check
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > getgenv().ESPSettings.MaxDistance then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then
        if esp.Beam then esp.Beam.Enabled = false end
        if esp.Box then esp.Box.Visible = false end
        if esp.Billboard then esp.Billboard.Enabled = false end
        return
    end
    
    -- Update Laser Beam
    if esp.Beam and getgenv().ESPSettings.Laser then
        local LocalChar = LocalPlayer.Character
        if LocalChar then
            local localRoot = LocalChar:FindFirstChild("HumanoidRootPart")
            if localRoot then
                if esp.Attachment0.Parent ~= localRoot then
                    esp.Attachment0.Parent = localRoot
                end
                if esp.Attachment1.Parent ~= rootPart then
                    esp.Attachment1.Parent = rootPart
                end
                
                esp.Beam.Enabled = true
                esp.Beam.Color = ColorSequence.new(GetTeamColor(player))
                esp.Beam.Width0 = getgenv().ESPSettings.LaserWidth
                esp.Beam.Width1 = getgenv().ESPSettings.LaserWidth
            else
                esp.Beam.Enabled = false
            end
        else
            esp.Beam.Enabled = false
        end
    elseif esp.Beam then
        esp.Beam.Enabled = false
    end
    
    -- Update Box
    if esp.Box and getgenv().ESPSettings.Box then
        esp.Box.Adornee = rootPart
        esp.Box.Visible = true
        esp.Box.Color3 = GetTeamColor(player)
    elseif esp.Box then
        esp.Box.Visible = false
    end
    
    -- Update Billboard
    if esp.Billboard then
        esp.Billboard.Adornee = head
        esp.Billboard.Enabled = true
        
        if esp.NameLabel then
            esp.NameLabel.Visible = getgenv().ESPSettings.Name
            esp.NameLabel.TextColor3 = GetTeamColor(player)
        end
        
        if esp.DistanceLabel then
            esp.DistanceLabel.Visible = getgenv().ESPSettings.Distance
            esp.DistanceLabel.Text = math.floor(distance) .. "m"
        end
        
        if esp.HealthBar and esp.HealthText and getgenv().ESPSettings.Health then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            esp.HealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
            esp.HealthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
            
            if healthPercent > 0.7 then
                esp.HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            elseif healthPercent > 0.3 then
                esp.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            else
                esp.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
        end
    end
end

local function RemoveESP(player)
    if ESPObjects[player] then
        if ESPObjects[player].Beam then ESPObjects[player].Beam:Destroy() end
        if ESPObjects[player].Attachment0 then ESPObjects[player].Attachment0:Destroy() end
        if ESPObjects[player].Attachment1 then ESPObjects[player].Attachment1:Destroy() end
        if ESPObjects[player].Box then ESPObjects[player].Box:Destroy() end
        if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
        ESPObjects[player] = nil
    end
end

-- Player Management for ESP
local function PlayerAdded(player)
    if player == LocalPlayer then return end
    
    player.CharacterAdded:Connect(function()
        wait(1)
        CreateESP(player)
    end)
    
    player.CharacterRemoving:Connect(function()
        RemoveESP(player)
    end)
    
    if player.Character then
        wait(2)
        CreateESP(player)
    end
end

local function PlayerRemoving(player)
    RemoveESP(player)
end

-- Initialize systems
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        spawn(function()
            PlayerAdded(player)
        end)
    end
end

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

-- Character respawn handling
LocalPlayer.CharacterAdded:Connect(function()
    wait(2)
    for player, esp in pairs(ESPObjects) do
        if player and player.Character then
            RemoveESP(player)
            wait()
            CreateESP(player)
        end
    end
    
    -- Reset invisible state
    resetPlayerState()
end)

-- Main update loop
RunService.Heartbeat:Connect(function()
    for player, esp in pairs(ESPObjects) do
        if player and esp and player.Character then
            UpdateESP(player, esp)
        end
    end
end)

-- Keyboard input for invisible
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == getgenv().InvisibleSettings.ToggleKey then
        toggleInvisibility()
    end
end)

-- ========== PRODUCT FAKER SYSTEM ==========

local MarketplaceService = game:GetService("MarketplaceService")
local productFakerActive = false
local productFakerGui = nil
local activeResetThreads = setmetatable({}, { __mode = "k" })

local function Finished(productInfo)
    local success, err = pcall(function()
        MarketplaceService:SignalPromptProductPurchaseFinished(localPlayer.UserId, productInfo.ProductId, true)
    end)
    if success then
        return
    end

    pcall(function()
        MarketplaceService:SignalPromptProductPurchaseFinished(localPlayer, productInfo.ProductId, true)
    end)
end

local function createProductFakerGUI()
    if productFakerGui then
        productFakerGui:Destroy()
        productFakerGui = nil
    end

    local mainGui = Instance.new("ScreenGui")
    mainGui.Name = "RyDev_ProductFaker"
    mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mainGui.Parent = game.CoreGui

    local developerProductsFrame = Instance.new("TextButton")
    developerProductsFrame.Font = Enum.Font.GothamBold
    developerProductsFrame.Text = "Developer Products - RyDev"
    developerProductsFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
    developerProductsFrame.TextSize = 16
    developerProductsFrame.AutoButtonColor = false
    developerProductsFrame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
    developerProductsFrame.BorderSizePixel = 0
    developerProductsFrame.Position = UDim2.new(0.35, 0, 0.3, 0)
    developerProductsFrame.Size = UDim2.new(0, 252, 0, 35)
    developerProductsFrame.Parent = mainGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = developerProductsFrame

    local closeButton = Instance.new("TextButton")
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Position = UDim2.new(1, -32, 0, 2.5)
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Parent = developerProductsFrame

    local closeButtonCorner = Instance.new("UICorner")
    closeButtonCorner.CornerRadius = UDim.new(0, 6)
    closeButtonCorner.Parent = closeButton

    task.delay(0.3, function()
        local buyAllProductsButton = Instance.new("TextButton")
        buyAllProductsButton.Name = "BuyAllProductsButton"
        buyAllProductsButton.Font = Enum.Font.GothamBold
        buyAllProductsButton.Text = "Buy All Products"
        buyAllProductsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyAllProductsButton.TextSize = 14
        buyAllProductsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        buyAllProductsButton.BorderSizePixel = 0
        buyAllProductsButton.Position = UDim2.new(0, 0, 1, 2)
        buyAllProductsButton.Size = UDim2.new(1, 0, 0, 30)
        buyAllProductsButton.Parent = developerProductsFrame
        Instance.new("UICorner", buyAllProductsButton).CornerRadius = UDim.new(0, 6)
    end)

    local containerFrame = Instance.new("Frame")
    containerFrame.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
    containerFrame.BorderSizePixel = 0
    containerFrame.Position = UDim2.new(0, 0, 1, 34)
    containerFrame.Size = UDim2.new(0, 252, 0, 441)
    containerFrame.Parent = developerProductsFrame

    Instance.new("UICorner").Parent = containerFrame

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(113, 113, 113)
    containerStroke.Parent = containerFrame

    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollingFrame.ScrollBarThickness = 5
    scrollingFrame.Active = true
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollingFrame.Parent = containerFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollingFrame

    -- Template Produk
    local exampleProductFrame = Instance.new("Frame")
    exampleProductFrame.BackgroundTransparency = 1
    exampleProductFrame.BorderSizePixel = 0
    exampleProductFrame.Size = UDim2.new(1, 0, 0, 100)
    exampleProductFrame.Visible = false
    exampleProductFrame.Name = "ExampleFrame"
    exampleProductFrame.Parent = scrollingFrame

    local hoverBg = Instance.new("Frame")
    hoverBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    hoverBg.BackgroundTransparency = 1
    hoverBg.BorderSizePixel = 0
    hoverBg.Size = UDim2.new(1, 0, 1, 0)
    hoverBg.Name = "HoverBg"
    hoverBg.Parent = exampleProductFrame
    Instance.new("UICorner", hoverBg).CornerRadius = UDim.new(0, 6)

    local nameLabel = Instance.new("TextLabel", exampleProductFrame)
    nameLabel.Name = "NameLabel"
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = "Product Name:"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0.048, 0, 0.1, 0)
    nameLabel.Size = UDim2.new(0.8, 0, 0, 21)

    local idLabel = Instance.new("TextLabel", exampleProductFrame)
    idLabel.Name = "IDLabel"
    idLabel.Font = Enum.Font.Gotham
    idLabel.Text = "Product ID:"
    idLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    idLabel.TextSize = 14
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.BackgroundTransparency = 1
    idLabel.Position = UDim2.new(0.048, 0, 0.29, 0)
    idLabel.Size = UDim2.new(0.5, 0, 0, 21)

    local descLabel = Instance.new("TextLabel", exampleProductFrame)
    descLabel.Name = "DescLabel"
    descLabel.Font = Enum.Font.Gotham
    descLabel.Text = "Product Description:"
    descLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    descLabel.TextSize = 14
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.BackgroundTransparency = 1
    descLabel.Position = UDim2.new(0.048, 0, 0.47, 0)
    descLabel.Size = UDim2.new(0.8, 0, 0, 21)

    local priceLabel = Instance.new("TextLabel", exampleProductFrame)
    priceLabel.Name = "PriceLabel"
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.Text = "Product Price:"
    priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    priceLabel.TextSize = 14
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.BackgroundTransparency = 1
    priceLabel.Position = UDim2.new(0.048, 0, 0.645, 0)
    priceLabel.Size = UDim2.new(0.5, 0, 0, 21)

    local divider = Instance.new("Frame", exampleProductFrame)
    divider.Name = "Divider"
    divider.BackgroundColor3 = Color3.fromRGB(102, 102, 102)
    divider.BorderSizePixel = 0
    divider.Position = UDim2.new(0, 0, 1, 0)
    divider.Size = UDim2.new(1, 0, 0, 2)

    local clickDetector = Instance.new("TextButton", exampleProductFrame)
    clickDetector.Name = "Click"
    clickDetector.Text = ""
    clickDetector.TextTransparency = 1
    clickDetector.BackgroundTransparency = 1
    clickDetector.Size = UDim2.new(1, 0, 1, 0)

    local copyScriptButton = Instance.new("TextButton", exampleProductFrame)
    copyScriptButton.Name = "CopyScriptButton"
    copyScriptButton.Font = Enum.Font.GothamBold
    copyScriptButton.Text = "Copy Script"
    copyScriptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyScriptButton.TextSize = 12
    copyScriptButton.BackgroundColor3 = Color3.fromRGB(70, 70, 150)
    copyScriptButton.Position = UDim2.new(0.65, 0, 0.25, 0)
    copyScriptButton.Size = UDim2.new(0, 80, 0, 21)
    Instance.new("UICorner", copyScriptButton).CornerRadius = UDim.new(0, 4)

    local copyButton = Instance.new("TextButton", exampleProductFrame)
    copyButton.Name = "CopyButton"
    copyButton.Font = Enum.Font.GothamBold
    copyButton.Text = "Copy ID"
    copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyButton.TextSize = 12
    copyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    copyButton.Position = UDim2.new(0.65, 0, 0.45, 0)
    copyButton.Size = UDim2.new(0, 80, 0, 21)
    Instance.new("UICorner", copyButton).CornerRadius = UDim.new(0, 4)

    local buyButton = Instance.new("TextButton", exampleProductFrame)
    buyButton.Name = "BuyButton"
    buyButton.Font = Enum.Font.GothamBold
    buyButton.Text = "Buy Product"
    buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyButton.TextSize = 12
    buyButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    buyButton.Position = UDim2.new(0.65, 0, 0.65, 0)
    buyButton.Size = UDim2.new(0, 80, 0, 21)
    Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 4)

    -- Fungsi Bantuan
    local function createHoverEffect(button, hoverColor)
        local originalColor = button.BackgroundColor3
        local tweenInfo = TweenInfo.new(0.15)
        button.MouseEnter:Connect(function()
            TweenService:Create(button, tweenInfo, {
                BackgroundColor3 = hoverColor
            }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, tweenInfo, {
                BackgroundColor3 = originalColor
            }):Play()
        end)
    end

    local function generateProductScript(productId)
        return [[local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local product = ]] .. tostring(productId) .. [[

function StartProduct()
    MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, product, true)
end

StartProduct()]]
    end

    -- Logik Utama
    task.spawn(function()
        local success, products = pcall(function()
            return MarketplaceService:GetDeveloperProductsAsync()
        end)

        if not success then
            return
        end
        
        local allProductsInfo = products:GetCurrentPage()

        local buyAllProductsButton = developerProductsFrame:WaitForChild("BuyAllProductsButton", 5)
        if buyAllProductsButton then
            createHoverEffect(buyAllProductsButton, Color3.fromRGB(180, 70, 70))
            buyAllProductsButton.MouseButton1Click:Connect(function()
                if activeResetThreads[buyAllProductsButton] then
                    task.cancel(activeResetThreads[buyAllProductsButton])
                end
                
                if not buyAllProductsButton:GetAttribute("OriginalText") then
                    buyAllProductsButton:SetAttribute("OriginalText", buyAllProductsButton.Text)
                    buyAllProductsButton:SetAttribute("OriginalColor", buyAllProductsButton.BackgroundColor3)
                end
                local originalText = buyAllProductsButton:GetAttribute("OriginalText")
                local originalColor = buyAllProductsButton:GetAttribute("OriginalColor")

                buyAllProductsButton.Text = "Processing..."
                buyAllProductsButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                
                for _, productInfo in pairs(allProductsInfo) do
                    Finished(productInfo)
                    task.wait(0.3)
                end
                
                activeResetThreads[buyAllProductsButton] = task.spawn(function()
                    buyAllProductsButton.Text = "Done!"
                    buyAllProductsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    task.wait(1.5)
                    buyAllProductsButton.Text = originalText
                    buyAllProductsButton.BackgroundColor3 = originalColor
                    activeResetThreads[buyAllProductsButton] = nil
                end)
            end)
        end

        for _, productInfo in pairs(allProductsInfo) do
            local productFrame = exampleProductFrame:Clone()
            productFrame.Visible = true
            productFrame.Parent = scrollingFrame
            productFrame.NameLabel.Text = "Name: " .. productInfo.Name
            productFrame.IDLabel.Text = "ID: " .. tostring(productInfo.ProductId)
            productFrame.DescLabel.Text = "Description: " .. productInfo.Description
            productFrame.PriceLabel.Text = "Price: " .. tostring(productInfo.PriceInRobux)

            productFrame.Click.MouseButton1Click:Connect(function()
                Finished(productInfo)
            end)

            local productHoverBg = productFrame.HoverBg
            productFrame.Click.MouseEnter:Connect(function()
                TweenService:Create(productHoverBg, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.7
                }):Play()
            end)
            productFrame.Click.MouseLeave:Connect(function()
                TweenService:Create(productHoverBg, TweenInfo.new(0.2), {
                    BackgroundTransparency = 1
                }):Play()
            end)

            local productCopyScriptButton = productFrame.CopyScriptButton
            createHoverEffect(productCopyScriptButton, Color3.fromRGB(90, 90, 180))
            productCopyScriptButton.MouseButton1Click:Connect(function()
                if setclipboard then
                    if activeResetThreads[productCopyScriptButton] then
                        task.cancel(activeResetThreads[productCopyScriptButton])
                    end
                    if not productCopyScriptButton:GetAttribute("OriginalText") then
                        productCopyScriptButton:SetAttribute("OriginalText", productCopyScriptButton.Text)
                        productCopyScriptButton:SetAttribute("OriginalColor", productCopyScriptButton.BackgroundColor3)
                    end
                    local originalText = productCopyScriptButton:GetAttribute("OriginalText")
                    local originalColor = productCopyScriptButton:GetAttribute("OriginalColor")

                    local scriptCode = generateProductScript(productInfo.ProductId)
                    setclipboard(scriptCode)
                    productCopyScriptButton.Text = "Copied!"
                    productCopyScriptButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    
                    activeResetThreads[productCopyScriptButton] = task.spawn(function()
                        task.wait(1)
                        productCopyScriptButton.Text = originalText
                        productCopyScriptButton.BackgroundColor3 = originalColor
                        activeResetThreads[productCopyScriptButton] = nil
                    end)
                end
            end)

            local productCopyButton = productFrame.CopyButton
            createHoverEffect(productCopyButton, Color3.fromRGB(90, 90, 90))
            productCopyButton.MouseButton1Click:Connect(function()
                if setclipboard then
                    if activeResetThreads[productCopyButton] then
                        task.cancel(activeResetThreads[productCopyButton])
                    end
                    if not productCopyButton:GetAttribute("OriginalText") then
                        productCopyButton:SetAttribute("OriginalText", productCopyButton.Text)
                        productCopyButton:SetAttribute("OriginalColor", productCopyButton.BackgroundColor3)
                    end
                    local originalText = productCopyButton:GetAttribute("OriginalText")
                    local originalColor = productCopyButton:GetAttribute("OriginalColor")

                    setclipboard(tostring(productInfo.ProductId))
                    productCopyButton.Text = "Copied!"
                    productCopyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    
                    activeResetThreads[productCopyButton] = task.spawn(function()
                        task.wait(1)
                        productCopyButton.Text = originalText
                        productCopyButton.BackgroundColor3 = originalColor
                        activeResetThreads[productCopyButton] = nil
                    end)
                end
            end)

            local productBuyButton = productFrame.BuyButton
            createHoverEffect(productBuyButton, Color3.fromRGB(180, 70, 70))
            productBuyButton.MouseButton1Click:Connect(function()
                if activeResetThreads[productBuyButton] then
                    task.cancel(activeResetThreads[productBuyButton])
                end
                if not productBuyButton:GetAttribute("OriginalText") then
                    productBuyButton:SetAttribute("OriginalText", productBuyButton.Text)
                    productBuyButton:SetAttribute("OriginalColor", productBuyButton.BackgroundColor3)
                end
                local originalText = productBuyButton:GetAttribute("OriginalText")
                local originalColor = productBuyButton:GetAttribute("OriginalColor")

                productBuyButton.Text = "Processing..."
                productBuyButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
                
                Finished(productInfo)
                
                activeResetThreads[productBuyButton] = task.spawn(function()
                    task.wait(0.5)
                    productBuyButton.Text = "Done!"
                    productBuyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    task.wait(1.5)
                    productBuyButton.Text = originalText
                    productBuyButton.BackgroundColor3 = originalColor
                    activeResetThreads[productBuyButton] = nil
                end)
            end)
        end
    end)

    -- Fungsi Kawalan Tetingkap
    closeButton.MouseButton1Click:Connect(function()
        mainGui:Destroy()
        productFakerGui = nil
        productFakerActive = false
    end)

    local isDragging = false
    local dragStart
    local startPosition
    local mouseMoveConnection
    local mouseUpConnection

    developerProductsFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPosition = developerProductsFrame.Position

            mouseMoveConnection = UserInputService.InputChanged:Connect(function(moveInput)
                if (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) and isDragging then
                    local delta = moveInput.Position - dragStart
                    developerProductsFrame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
                end
            end)

            mouseUpConnection = UserInputService.InputEnded:Connect(function(endInput)
                if (endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch) and isDragging then
                    isDragging = false
                    if mouseMoveConnection then
                        mouseMoveConnection:Disconnect()
                    end
                    if mouseUpConnection then
                        mouseUpConnection:Disconnect()
                    end
                end
            end)
        end
    end)

    productFakerGui = mainGui
    return mainGui
end

local function toggleProductFaker()
    if productFakerActive then
        if productFakerGui then
            productFakerGui:Destroy()
            productFakerGui = nil
        end
        productFakerActive = false
    else
        createProductFakerGUI()
        productFakerActive = true
    end
end

-- ========== WINDUI INTEGRATION ==========

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "RyDev | UNIVERSAL",
    Author = "by RyDev",
    Folder = "RyDev",
    Icon = "shield",
    NewElements = true,
})

-- ESP Tab
local ESPTab = Window:Tab({
    Title = "ESP Settings",
    Icon = "eye",
})

-- ESP Controls Section
local ESPControls = ESPTab:Section({
    Title = "ESP Controls",
})

ESPControls:Toggle({
    Title = "ESP Enabled",
    Desc = "Toggle ESP system on/off",
    Flag = "ESPEnabled",
    Default = getgenv().ESPSettings.Enabled,
    Callback = function(state)
        getgenv().ESPSettings.Enabled = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Laser Beam",
    Desc = "Show laser beam to players",
    Flag = "LaserEnabled",
    Default = getgenv().ESPSettings.Laser,
    Callback = function(state)
        getgenv().ESPSettings.Laser = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Show Name",
    Desc = "Display player names",
    Flag = "NameEnabled",
    Default = getgenv().ESPSettings.Name,
    Callback = function(state)
        getgenv().ESPSettings.Name = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Show Distance",
    Desc = "Display distance to players",
    Flag = "DistanceEnabled",
    Default = getgenv().ESPSettings.Distance,
    Callback = function(state)
        getgenv().ESPSettings.Distance = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Health Bar",
    Desc = "Show health bar with colors",
    Flag = "HealthEnabled",
    Default = getgenv().ESPSettings.Health,
    Callback = function(state)
        getgenv().ESPSettings.Health = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Box ESP",
    Desc = "Show box around players",
    Flag = "BoxEnabled",
    Default = getgenv().ESPSettings.Box,
    Callback = function(state)
        getgenv().ESPSettings.Box = state
    end
})

ESPControls:Space()

ESPControls:Toggle({
    Title = "Team Check",
    Desc = "Only show enemies (team based)",
    Flag = "TeamCheckEnabled",
    Default = getgenv().ESPSettings.TeamCheck,
    Callback = function(state)
        getgenv().ESPSettings.TeamCheck = state
    end
})

-- Visual Settings Section
local VisualSettings = ESPTab:Section({
    Title = "Visual Settings",
})

VisualSettings:Colorpicker({
    Title = "Enemy Color",
    Desc = "Color for enemy players",
    Flag = "EnemyColor",
    Default = getgenv().ESPSettings.EnemyColor,
    Callback = function(color)
        getgenv().ESPSettings.EnemyColor = color
    end
})

VisualSettings:Space()

VisualSettings:Colorpicker({
    Title = "Friend Color",
    Desc = "Color for friendly players",
    Flag = "FriendColor",
    Default = getgenv().ESPSettings.FriendColor,
    Callback = function(color)
        getgenv().ESPSettings.FriendColor = color
    end
})

VisualSettings:Space()

VisualSettings:Slider({
    Title = "Laser Width",
    Desc = "Width of the laser beam",
    Flag = "LaserWidth",
    Value = {
        Min = 0.05,
        Max = 1.0,
        Default = getgenv().ESPSettings.LaserWidth,
    },
    Callback = function(value)
        getgenv().ESPSettings.LaserWidth = value
    end
})

VisualSettings:Space()

VisualSettings:Slider({
    Title = "Max Distance",
    Desc = "Maximum ESP render distance",
    Flag = "MaxDistance",
    Value = {
        Min = 100,
        Max = 5000,
        Default = getgenv().ESPSettings.MaxDistance,
    },
    Callback = function(value)
        getgenv().ESPSettings.MaxDistance = value
    end
})

VisualSettings:Space()

VisualSettings:Slider({
    Title = "Text Size",
    Desc = "Size of ESP text",
    Flag = "TextSize",
    Value = {
        Min = 8,
        Max = 24,
        Default = getgenv().ESPSettings.TextSize,
    },
    Callback = function(value)
        getgenv().ESPSettings.TextSize = value
    end
})

-- Invisible Tab
local InvisibleTab = Window:Tab({
    Title = "Invisible System",
    Icon = "user-x",
})

local InvisibleControls = InvisibleTab:Section({
    Title = "Invisible Controls",
})

InvisibleControls:Button({
    Title = "Toggle Invisible",
    Desc = "Press X key or click here to toggle invisible",
    Color = getgenv().InvisibleSettings.InvisibleColor,
    Icon = "eye-off",
    Callback = function()
        toggleInvisibility()
    end
})

InvisibleControls:Space()

InvisibleControls:Button({
    Title = "Speed Boost",
    Desc = "Toggle speed boost on/off",
    Color = getgenv().InvisibleSettings.SpeedBoostColor,
    Icon = "zap",
    Callback = function()
        toggleSpeedBoost()
    end
})

InvisibleControls:Space()

InvisibleControls:Keybind({
    Title = "Invisible Keybind",
    Desc = "Key to toggle invisible (default: X)",
    Flag = "InvisibleKeybind",
    Value = "X",
    Callback = function(key)
        getgenv().InvisibleSettings.ToggleKey = Enum.KeyCode[key]
    end
})

InvisibleControls:Space()

InvisibleControls:Slider({
    Title = "Default Speed",
    Desc = "Normal walking speed",
    Flag = "DefaultSpeed",
    Value = {
        Min = 16,
        Max = 50,
        Default = getgenv().InvisibleSettings.DefaultSpeed,
    },
    Callback = function(value)
        getgenv().InvisibleSettings.DefaultSpeed = value
        playerState.originalSpeed = value
        
        local humanoid = getHumanoid()
        if humanoid and not playerState.isSpeedBoosted then
            humanoid.WalkSpeed = value
        end
    end
})

InvisibleControls:Space()

InvisibleControls:Slider({
    Title = "Boosted Speed",
    Desc = "Speed when boost is active",
    Flag = "BoostedSpeed",
    Value = {
        Min = 30,
        Max = 100,
        Default = getgenv().InvisibleSettings.BoostedSpeed,
    },
    Callback = function(value)
        getgenv().InvisibleSettings.BoostedSpeed = value
        
        local humanoid = getHumanoid()
        if humanoid and playerState.isSpeedBoosted then
            humanoid.WalkSpeed = value
        end
    end
})

-- Spectator Tab
local SpectatorTab = Window:Tab({
    Title = "Spectator",
    Icon = "users",
})

-- Player Selection Section
local PlayerSection = SpectatorTab:Section({
    Title = "Player Selection",
})

local CurrentTargetLabel = PlayerSection:Section({
    Title = "Current Target: None",
    TextSize = 16,
    FontWeight = Enum.FontWeight.Bold,
})

PlayerSection:Space()

PlayerSection:Button({
    Title = "Previous Player",
    Desc = "Select previous player",
    Color = COLORS.MEDIUM_BLUE,
    Icon = "chevron-left",
    Callback = function()
        if #TargetList == 0 then safeRefreshTargetList() end
        if #TargetList == 0 then 
            WindUI:Notify({
                Title = "No Players",
                Content = "No players available to spectate",
                Icon = "users"
            })
            return 
        end
        
        local nextIndex = CurrentIndex - 1
        if nextIndex < 1 then nextIndex = #TargetList end
        
        if nextIndex >= 1 and nextIndex <= #TargetList then
            CurrentIndex = nextIndex
            CurrentTarget = TargetList[CurrentIndex]
            CurrentTargetLabel:Update({
                Title = "Current Target: " .. CurrentTarget.Name
            })
            turnOffSendPart()
            WindUI:Notify({
                Title = "Target Changed",
                Content = "Now spectating: " .. CurrentTarget.Name,
                Icon = "user"
            })
        end
    end
})

PlayerSection:Space()

PlayerSection:Button({
    Title = "Next Player",
    Desc = "Select next player",
    Color = COLORS.MEDIUM_BLUE,
    Icon = "chevron-right",
    Callback = function()
        if #TargetList == 0 then safeRefreshTargetList() end
        if #TargetList == 0 then 
            WindUI:Notify({
                Title = "No Players",
                Content = "No players available to spectate",
                Icon = "users"
            })
            return 
        end
        
        local nextIndex = CurrentIndex + 1
        if nextIndex > #TargetList then nextIndex = 1 end
        
        if nextIndex >= 1 and nextIndex <= #TargetList then
            CurrentIndex = nextIndex
            CurrentTarget = TargetList[CurrentIndex]
            CurrentTargetLabel:Update({
                Title = "Current Target: " .. CurrentTarget.Name
            })
            turnOffSendPart()
            WindUI:Notify({
                Title = "Target Changed",
                Content = "Now spectating: " .. CurrentTarget.Name,
                Icon = "user"
            })
        end
    end
})

PlayerSection:Space()

PlayerSection:Button({
    Title = "Refresh Players",
    Desc = "Refresh player list",
    Color = COLORS.LIGHT_BLUE,
    Icon = "refresh-cw",
    Callback = function()
        safeRefreshTargetList()
        if CurrentTarget then
            CurrentTargetLabel:Update({
                Title = "Current Target: " .. CurrentTarget.Name
            })
        else
            CurrentTargetLabel:Update({
                Title = "Current Target: None"
            })
        end
        WindUI:Notify({
            Title = "Players Refreshed",
            Content = "Player list has been updated",
            Icon = "check"
        })
    end
})

-- Actions Section
local ActionsSection = SpectatorTab:Section({
    Title = "Player Actions",
})

ActionsSection:Button({
    Title = "Teleport to Target",
    Desc = "Teleport to selected player",
    Color = COLORS.GREEN,
    Icon = "navigation",
    Callback = teleportToTarget
})

ActionsSection:Space()

ActionsSection:Button({
    Title = "Toggle Fling",
    Desc = "Fling/Kick the target player",
    Color = COLORS.RED,
    Icon = "zap",
    Callback = toggleFling
})

ActionsSection:Space()

ActionsSection:Button({
    Title = "Toggle Follow",
    Desc = "Follow the target player",
    Color = COLORS.NEON_BLUE,
    Icon = "user-check",
    Callback = toggleFollow
})

ActionsSection:Space()

ActionsSection:Button({
    Title = "Toggle Send Parts",
    Desc = "Send unanchored parts to target",
    Color = COLORS.GOLD,
    Icon = "send",
    Callback = toggleSendPart
})

-- System Controls Section
local SystemSection = SpectatorTab:Section({
    Title = "System Controls",
})

SystemSection:Toggle({
    Title = "Spectator Active",
    Desc = "Toggle spectator mode on/off",
    Flag = "SpectatorActive",
    Default = false,
    Callback = function(state)
        Active = state
        if not state then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
            end
            WindUI:Notify({
                Title = "Spectator Off",
                Content = "Spectator mode disabled - Camera back to your character",
                Icon = "eye-off"
            })
        else
            if not CurrentTarget then
                safeRefreshTargetList()
                if not CurrentTarget then
                    WindUI:Notify({
                        Title = "Error",
                        Content = "No players available to spectate!",
                        Icon = "x"
                    })
                    Active = false
                    return
                end
            end
            WindUI:Notify({
                Title = "Spectator On",
                Content = "Spectator mode enabled - Spectating: " .. (CurrentTarget and CurrentTarget.Name or "None"),
                Icon = "eye"
            })
        end
    end
})

SystemSection:Space()

SystemSection:Button({
    Title = "Stop All Actions",
    Desc = "Stop all active actions",
    Color = COLORS.RED,
    Icon = "square",
    Callback = function()
        -- Stop follow
        if FollowActive then
            stopFollow()
        end
        
        -- Stop fling
        if FlingActive then
            FlingActive = false
            FlingThread = nil
        end
        
        -- Stop send part
        if SendPartActive then
            turnOffSendPart()
        end
        
        -- Unfreeze character
        unfreezeCharacter()
        
        WindUI:Notify({
            Title = "All Actions Stopped",
            Content = "All active actions have been stopped",
            Icon = "square"
        })
    end
})

SystemSection:Space()

SystemSection:Button({
    Title = "Reset Camera",
    Desc = "Reset camera to your character",
    Color = COLORS.LIGHT_BLUE,
    Icon = "camera",
    Callback = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            Camera.CameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
            Active = false
            WindUI:Notify({
                Title = "Camera Reset",
                Content = "Camera reset to your character",
                Icon = "camera"
            })
        end
    end
})

-- Product Faker Tab
local ProductFakerTab = Window:Tab({
    Title = "Product Faker",
    Icon = "shopping-bag",
})

local ProductFakerSection = ProductFakerTab:Section({
    Title = "Product Faker Controls",
})

ProductFakerSection:Section({
    Title = "Developer Products Faker",
    TextSize = 16,
    FontWeight = Enum.FontWeight.Bold,
})

ProductFakerSection:Space()

ProductFakerSection:Section({
    Title = [[Fake purchase developer products in-game.
    
Features:
• View all developer products
• Buy individual products  
• Buy all products at once
• Copy product IDs
• Copy purchase scripts

Note: This may not work in all games!]],
    TextSize = 14,
    TextTransparency = 0.35,
    FontWeight = Enum.FontWeight.Medium,
})

ProductFakerSection:Space()

ProductFakerSection:Button({
    Title = "Toggle Product Faker",
    Desc = "Open/Close product faker window",
    Color = Color3.fromHex("#ff6b35"),
    Icon = "shopping-bag",
    Callback = toggleProductFaker
})

ProductFakerSection:Space()

ProductFakerSection:Button({
    Title = "Refresh Products",
    Desc = "Reload developer products list",
    Color = Color3.fromHex("#30a2ff"),
    Icon = "refresh-cw",
    Callback = function()
        if productFakerActive and productFakerGui then
            productFakerGui:Destroy()
            productFakerGui = nil
            task.wait(0.5)
            createProductFakerGUI()
            WindUI:Notify({
                Title = "Product Faker",
                Content = "Products list refreshed!",
                Icon = "check"
            })
        else
            WindUI:Notify({
                Title = "Product Faker",
                Content = "Open Product Faker first!",
                Icon = "x"
            })
        end
    end
})

-- Info Tab
local InfoTab = Window:Tab({
    Title = "Info & Utilities",
    Icon = "info",
})

local InfoSection = InfoTab:Section({
    Title = "System Information",
})

InfoSection:Section({
    Title = "RyDev | UNIVERSAL Suite",
    TextSize = 20,
    FontWeight = Enum.FontWeight.SemiBold,
})

InfoSection:Space()

InfoSection:Section({
    Title = [[Complete gaming suite with multiple features:

ESP System:
• Laser Beam ESP
• Player Name Display
• Distance Indicator
• Health Bar with Color Coding
• Box ESP
• Team Color Support

Invisible System:
• Toggle Invisibility (X key)
• Speed Boost
• Customizable Speeds
• Auto-reset on respawn

Spectator System:
• Player Targeting & Navigation
• Teleport, Fling, Follow
• Send Parts to Target
• Camera Control

Product Faker:
• View Developer Products
• Fake Purchase Products
• Copy Product IDs
• Copy Purchase Scripts

All settings are automatically saved!]],
    TextSize = 14,
    TextTransparency = 0.35,
    FontWeight = Enum.FontWeight.Medium,
})

InfoTab:Space({ Columns = 2 })

InfoTab:Button({
    Title = "Refresh ESP",
    Desc = "Refresh all ESP elements",
    Color = Color3.fromHex("#30a2ff"),
    Icon = "refresh-cw",
    Callback = function()
        for player, esp in pairs(ESPObjects) do
            RemoveESP(player)
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                spawn(function()
                    PlayerAdded(player)
                end)
            end
        end
        
        WindUI:Notify({
            Title = "ESP Refreshed",
            Content = "All ESP elements have been refreshed!",
            Icon = "check",
        })
    end
})

InfoTab:Space({ Columns = 1 })

InfoTab:Button({
    Title = "Reset Invisible",
    Desc = "Reset invisible state and speed",
    Color = Color3.fromHex("#ffa230"),
    Icon = "rotate-ccw",
    Callback = function()
        resetPlayerState()
        WindUI:Notify({
            Title = "Invisible Reset",
            Content = "Invisible state and speed have been reset!",
            Icon = "check",
        })
    end
})

InfoTab:Space({ Columns = 1 })

InfoTab:Button({
    Title = "Destroy All",
    Desc = "Remove all ESP and invisible elements",
    Color = Color3.fromHex("#ff3040"),
    Icon = "trash",
    Callback = function()
        -- Remove ESP
        for player, esp in pairs(ESPObjects) do
            RemoveESP(player)
        end
        
        -- Reset invisible
        resetPlayerState()
        
        -- Reset settings
        getgenv().ESPSettings.Enabled = false
        
        WindUI:Notify({
            Title = "All Systems Destroyed",
            Content = "ESP and Invisible systems have been removed!",
            Icon = "trash",
        })
    end
})

-- Initialize target display
task.spawn(function()
    task.wait(2)
    safeRefreshTargetList()
    if CurrentTarget then
        CurrentTargetLabel:Update({
            Title = "Current Target: " .. CurrentTarget.Name
        })
    else
        CurrentTargetLabel:Update({
            Title = "Current Target: None"
        })
    end
    
    Active = false
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        Camera.CameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
    end
end)

print("🎯 RyDev | UNIVERSAL Suite LOADED!")
print("✅ Complete ESP System")
print("✅ Invisible System with Speed Boost")
print("✅ Spectator System with Multiple Features")
print("✅ Product Faker System")
print("✅ WindUI Controls")
print("✅ Automatic Settings Saving")
print("🚀 Ready to use!")

warn("Script by RyDev - Universal Gaming Suite")
