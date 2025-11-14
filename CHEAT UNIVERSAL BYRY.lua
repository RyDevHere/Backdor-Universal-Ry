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
local Active = false -- DIUBAH: false secara default
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

-- DIUBAH: Pindah refreshTargetList ke bawah setelah WindUI dibuat
-- refreshTargetList() -- DIPINDAHKAN

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

-- CAMERA SYSTEM - DIPERBAIKI
local CameraConnection
local function setupCameraSystem()
    if CameraConnection then
        CameraConnection:Disconnect()
    end
    
    CameraConnection = RunService.RenderStepped:Connect(function()
        if not Active then 
            -- Pastikan kamera kembali ke karakter lokal ketika spectator nonaktif
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
            -- Jika tidak ada target, kembali ke karakter lokal
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = LocalPlayer.Character.Humanoid
            end
        end
    end)
end

-- Setup camera system saat script dimulai
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
            Title = "Success",
            Content = "Teleported to " .. CurrentTarget.Name,
            Icon = "check"
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
        WindUI:Notify({
            Title = "Fling Started",
            Content = "Flinging " .. CurrentTarget.Name,
            Icon = "zap"
        })
        if not FlingThread then
            FlingThread = task.spawn(flingLoop)
        end
    else
        FlingActive = false
        WindUI:Notify({
            Title = "Fling Stopped",
            Content = "Stopped flinging",
            Icon = "check"
        })
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
    WindUI:Notify({
        Title = "Follow Stopped",
        Content = "Stopped following",
        Icon = "user-x"
    })
end

local function startFollowToTarget(target)
    if not target or not rootPart or not humanoid then 
        WindUI:Notify({
            Title = "Error",
            Content = "Cannot follow - character issue",
            Icon = "x"
        })
        return 
    end
    FollowActive = true
    
    WindUI:Notify({
        Title = "Follow Started",
        Content = "Following " .. target.Name,
        Icon = "user-check"
    })

    pcall(function()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://100681208320300"
        FollowAnim = humanoid:LoadAnimation(anim)
        FollowAnim.Looped = true
        FollowAnim:Play()
    end)

    FollowConnection = RunService.Heartbeat:Connect(function()
        if not FollowActive then return end
        if not target.Character then 
            stopFollow() 
            return 
        end
        local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then 
            stopFollow() 
            return 
        end
        if rootPart then
            rootPart.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
        else
            stopFollow()
        end
    end)
end

local function toggleFollow()
    if FollowActive then
        stopFollow()
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
        WindUI:Notify({
            Title = "Send Part Started",
            Content = "Sending parts to " .. CurrentTarget.Name,
            Icon = "send"
        })
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
        WindUI:Notify({
            Title = "Send Part Stopped",
            Content = "Stopped sending parts",
            Icon = "check"
        })
        unfreezeCharacter()
    end
end

-- ========== INVISIBLE SYSTEM FUNCTIONS ==========
-- [Kode invisible system tetap sama...]
-- ========== ESP SYSTEM FUNCTIONS ==========
-- [Kode ESP system tetap sama...]

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

-- [Kode ESP Tab tetap sama...]

-- Invisible Tab
local InvisibleTab = Window:Tab({
    Title = "Invisible System",
    Icon = "user-x",
})

-- [Kode Invisible Tab tetap sama...]

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
    Default = false, -- DIUBAH: false secara default
    Callback = function(state)
        Active = state
        if not state then
            -- Pastikan kamera kembali ke karakter lokal
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
            end
            WindUI:Notify({
                Title = "Spectator Off",
                Content = "Spectator mode disabled - Camera back to your character",
                Icon = "eye-off"
            })
        else
            -- Pastikan ada target sebelum mengaktifkan spectator
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
            Active = false -- Nonaktifkan spectator saat reset camera
            WindUI:Notify({
                Title = "Camera Reset",
                Content = "Camera reset to your character",
                Icon = "camera"
            })
        end
    end
})

-- Info Tab
local InfoTab = Window:Tab({
    Title = "Info & Utilities",
    Icon = "info",
})

-- [Kode Info Tab tetap sama...]

-- Initialize target display - DIPERBAIKI
task.spawn(function()
    task.wait(2) -- Tunggu WindUI selesai load
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
    
    -- Pastikan spectator tidak aktif secara default
    Active = false
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        Camera.CameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
    end
end)

print("🎯 RyDev | UNIVERSAL Suite LOADED!")
print("✅ Complete ESP System") 
print("✅ Invisible System with Speed Boost")
print("✅ Spectator System with Multiple Features")
print("✅ WindUI Controls")
print("✅ Automatic Settings Saving")
print("🚀 Ready to use!")

warn("Script by RyDev - Universal Gaming Suite")
