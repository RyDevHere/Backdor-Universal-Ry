-- RyDev | UNIVERSAL - Complete Gaming Suite - Wind UI Integrated Version (No Extra GUI)

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
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")

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

-- Product Faker Variables
local productFakerActive = false
local developerProducts = {}

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

-- ========== WINDUI INTEGRATION ==========
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "RyDev | UNIVERSAL",
    Author = "by RyDev",
    Folder = "RyDev",
    Icon = "shield",
    NewElements = true,
})

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
        WindUI:Notify({
            Title = "Error",
            Content = "No target selected!",
            Icon = "x"
        })
        return 
    end
    local lpHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetHRP = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
    if lpHRP and targetHRP then
        lpHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
        WindUI:Notify({
            Title = "Teleported",
            Content = "Teleported to " .. CurrentTarget.Name,
            Icon = "navigation"
        })
    else
        WindUI:Notify({
            Title = "Error",
            Content = "Cannot teleport - character not found",
            Icon = "x"
        })
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
        WindUI:Notify({
            Title = "Error",
            Content = "No target selected!",
            Icon = "x"
        })
        return 
    end
    local lpHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lpHRP then 
        WindUI:Notify({
            Title = "Error",
            Content = "Your character not found!",
            Icon = "x"
        })
        return 
    end

    FlingActive = not FlingActive

    if FlingActive then
        OriginalCFrame = lpHRP.CFrame
        if not FlingThread then
            FlingThread = task.spawn(flingLoop)
        end
        WindUI:Notify({
            Title = "Fling Started",
            Content = "Flinging " .. CurrentTarget.Name,
            Icon = "zap"
        })
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
        WindUI:Notify({
            Title = "Fling Stopped",
            Content = "Stopped flinging",
            Icon = "square"
        })
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
        WindUI:Notify({
            Title = "Follow Stopped",
            Content = "Stopped following",
            Icon = "user-x"
        })
        return
    end
    if not CurrentTarget then 
        WindUI:Notify({
            Title = "Error",
            Content = "No target selected!",
            Icon = "x"
        })
        return 
    end
    refreshCharacterRefs()
    startFollowToTarget(CurrentTarget)
    WindUI:Notify({
        Title = "Follow Started",
        Content = "Following " .. CurrentTarget.Name,
        Icon = "user-check"
    })
end

-- SEND PART FUNCTION
local function toggleSendPart()
    if not CurrentTarget then 
        WindUI:Notify({
            Title = "Error",
            Content = "No target selected!",
            Icon = "x"
        })
        return 
    end

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
        WindUI:Notify({
            Title = "Send Parts Started",
            Content = "Sending parts to " .. CurrentTarget.Name,
            Icon = "send"
        })
    else
        unfreezeCharacter()
        WindUI:Notify({
            Title = "Send Parts Stopped",
            Content = "Stopped sending parts",
            Icon = "square"
        })
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
        WindUI:Notify({
            Title = "Error",
            Content = "Character not found!",
            Icon = "x"
        })
        return
    end

    playerState.isInvisible = not playerState.isInvisible

    if playerState.isInvisible then
        local humanoidRootPart = getHumanoidRootPart()
        if not humanoidRootPart then
            WindUI:Notify({
                Title = "Error",
                Content = "HumanoidRootPart not found!",
                Icon = "x"
            })
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

        WindUI:Notify({
            Title = "Invisibility ON",
            Content = "Kamu sekarang tidak terlihat",
            Icon = "eye-off"
        })
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

        WindUI:Notify({
            Title = "Invisibility OFF",
            Content = "Anda sekarang terlihat",
            Icon = "eye"
        })
    end
end

local function toggleSpeedBoost()
    local humanoid = getHumanoid()
    if not humanoid then
        WindUI:Notify({
            Title = "Error",
            Content = "Humanoid not found!",
            Icon = "x"
        })
        return
    end

    playerState.isSpeedBoosted = not playerState.isSpeedBoosted

    if playerState.isSpeedBoosted then
        humanoid.WalkSpeed = getgenv().InvisibleSettings.BoostedSpeed
        WindUI:Notify({
            Title = "Speed Boost ON",
            Content = "Kecepatan ditingkatkan!",
            Icon = "zap"
        })
    else
        humanoid.WalkSpeed = playerState.originalSpeed
        WindUI:Notify({
            Title = "Speed Boost OFF",
            Content = "Atur Ulang Kecepatan",
            Icon = "zap-off"
        })
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

-- Initialize ESP systems
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

-- Main ESP update loop
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

-- ========== PRODUCT FAKER SYSTEM (NO GUI) ==========

local function Finished(productId)
    local success, err = pcall(function()
        MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, productId, true)
    end)
    if success then
        return true
    end

    local success2, err2 = pcall(function()
        MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer, productId, true)
    end)
    return success2
end

local function loadDeveloperProducts()
    local success, products = pcall(function()
        return MarketplaceService:GetDeveloperProductsAsync()
    end)

    if not success then
        WindUI:Notify({
            Title = "Product Faker Error",
            Content = "Failed to load developer products!",
            Icon = "x"
        })
        return {}
    end
    
    local allProducts = products:GetCurrentPage()
    developerProducts = {}
    
    for _, productInfo in pairs(allProducts) do
        table.insert(developerProducts, {
            Name = productInfo.Name,
            Id = productInfo.ProductId,
            Description = productInfo.Description,
            Price = productInfo.PriceInRobux
        })
    end
    
    return developerProducts
end

local function buyAllProducts()
    local products = loadDeveloperProducts()
    if #products == 0 then
        WindUI:Notify({
            Title = "Product Faker",
            Content = "No products found!",
            Icon = "x"
        })
        return
    end
    
    local successCount = 0
    for i, product in ipairs(products) do
        if Finished(product.Id) then
            successCount = successCount + 1
        end
        task.wait(0.2)
    end
    
    WindUI:Notify({
        Title = "Product Faker",
        Content = string.format("Successfully purchased %d/%d products!", successCount, #products),
        Icon = "shopping-bag"
    })
end

local function buyProductById(productId)
    if Finished(productId) then
        WindUI:Notify({
            Title = "Product Faker",
            Content = "Product purchased successfully!",
            Icon = "check"
        })
        return true
    else
        WindUI:Notify({
            Title = "Product Faker",
            Content = "Failed to purchase product!",
            Icon = "x"
        })
        return false
    end
end

local function copyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    end
    return false
end

local function generateProductScript(productId)
    return [[local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local productId = ]] .. tostring(productId) .. [[

MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, productId, true)]]
end

-- ========== WINDUI TABS ==========

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
        WindUI:Notify({
            Title = "ESP " .. (state and "Enabled" or "Disabled"),
            Content = "ESP system has been " .. (state and "enabled" or "disabled"),
            Icon = state and "eye" or "eye-off"
        })
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
        WindUI:Notify({
            Title = "Keybind Updated",
            Content = "Invisible keybind set to: " .. key,
            Icon = "key"
        })
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

-- Product Faker Tab (NO EXTRA GUI)
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
    Title = [[Fake purchase developer products directly through WindUI.
    
Features:
• Buy all products at once
• Load available products
• No extra GUI windows

Note: This may not work in all games!]],
    TextSize = 14,
    TextTransparency = 0.35,
    FontWeight = Enum.FontWeight.Medium,
})

ProductFakerSection:Space()

ProductFakerSection:Button({
    Title = "Buy All Products",
    Desc = "Purchase all available developer products",
    Color = Color3.fromHex("#ff6b35"),
    Icon = "shopping-cart",
    Callback = buyAllProducts
})

ProductFakerSection:Space()

ProductFakerSection:Button({
    Title = "Load Products",
    Desc = "Reload developer products list",
    Color = Color3.fromHex("#30a2ff"),
    Icon = "refresh-cw",
    Callback = function()
        local products = loadDeveloperProducts()
        WindUI:Notify({
            Title = "Product Faker",
            Content = string.format("Loaded %d developer products!", #products),
            Icon = "check"
        })
    end
})

ProductFakerSection:Space()

-- Product List Section
local ProductListSection = ProductFakerTab:Section({
    Title = "Available Products",
})

-- Dynamic product buttons will be added here
local function updateProductList()
    -- Clear existing product buttons (simplified approach)
    ProductListSection:Clear()
    
    if #developerProducts == 0 then
        ProductListSection:Section({
            Title = "No products loaded. Click 'Load Products' above.",
            TextSize = 14,
            TextTransparency = 0.5,
        })
        return
    end
    
    for i, product in ipairs(developerProducts) do
        ProductListSection:Button({
            Title = product.Name,
            Desc = string.format("ID: %d | Price: %d R$", product.Id, product.Price),
            Color = Color3.fromHex("#4a90e2"),
            Icon = "package",
            Callback = function()
                if buyProductById(product.Id) then
                    WindUI:Notify({
                        Title = "Product Purchased",
                        Content = string.format("Successfully purchased: %s", product.Name),
                        Icon = "check"
                    })
                end
            end
        })
        
        if i < #developerProducts then
            ProductListSection:Space()
        end
    end
end

-- Load products automatically
task.spawn(function()
    task.wait(2)
    loadDeveloperProducts()
    updateProductList()
end)

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
• Buy all developer products
• No extra GUI windows
• Direct WindUI integration

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
print("✅ Product Faker System (No Extra GUI)")
print("✅ WindUI Controls")
print("✅ Automatic Settings Saving")
print("🚀 Ready to use!")

warn("Script by RyDev - Universal Gaming Suite")
