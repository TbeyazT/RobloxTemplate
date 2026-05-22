local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local AnimationComponent = require("@Components/AnimationComponent")
local TweenComponent = require("@Components/TweenComponent") 
local TriggerComponent = require("@Components/TriggerComponent")

local Shake = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Shake'))

local CoreInstance = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Core'):FindFirstChild('Instance'))
local GetAnimator = require("@Modules/Utils/GetAnimator")
local LoadAnimation = require("@Modules/Utils/LoadAnimation")

local LocalPlayer = Players.LocalPlayer

local GameController = {}

function GameController:Init()
    self.MonetizationService = Framework.Get("MonetizationService")
    self.AudioService = Framework.Get("AudioService")
    self.FoodService = Framework.Get("FoodService")
    self.Utils = require(script.Parent.Utils)
    
    self.LastHit = 0
    self.HitCooldown = 1 
    
    self.ActiveShakes = {} 
    self.CurrentAutoHitWall = nil
    self.WallHealthCache = {}
    
    self.HitAnimTrack = nil
    self.HitAnimCharacter = nil
    self.HitMarkerConnection = nil
    
    self.CameraShakePreset = Shake.new()
    self.CameraShakePreset.Amplitude = 3        
    self.CameraShakePreset.Frequency = 25       
    self.CameraShakePreset.FadeInTime = 0.05    
    self.CameraShakePreset.SustainTime = 0.15   
    self.CameraShakePreset.FadeOutTime = 0.3   

    self.CameraShakePreset.PositionInfluence = Vector3.new(1,1,1) 
    self.CameraShakePreset.RotationInfluence = Vector3.new(0.03,0.03,0.03)
    
    self.AreaToWallMapping = {}
    self.SortedAreaIDs = {}
end

function GameController:Start()
    RunService.Heartbeat:Connect(function()
        if self.CurrentAutoHitWall and not self.FoodService.CurrentlyEating then
            self:AttemptHit()
        end
    end)

    Net.WallDamaged.On(function(data)
        local wallName = data.WallName
        local currentHp = data.Durability
        
        self.WallHealthCache[wallName] = currentHp
        
        local wallProps = self.Utils:GetWallProperties(wallName)
        local maxHp = wallProps and wallProps.Durability or 100
        
        local wallFolder = workspace.Walls:FindFirstChild(wallName)
        if not wallFolder then return end

        local visualModel = wallFolder:FindFirstChild("Wall")
        if visualModel then
            self:PlayHitEffect(visualModel)
        end
        
        self:UpdateWallUI(wallFolder, currentHp, maxHp)
    end)

    Net.WallDestroyed.On(function(data)
        local wallName = data.WallName
        self.WallHealthCache[wallName] = 0

        local wallFolder = workspace.Walls:FindFirstChild(wallName)
        if not wallFolder then return end

        local wallProps = self.Utils:GetWallProperties(wallName)
        local maxHp = wallProps and wallProps.Durability or 100

        self.AudioService:PlaySound("BreakPlatform")

        local visualModel = wallFolder:FindFirstChild("Wall") or wallFolder:FindFirstChild("Model")
        if visualModel then
            if visualModel then
                self:PlayHitEffect(visualModel)
            end
            self:SpawnDebris(visualModel)

            local surfaceGui = visualModel:FindFirstChildWhichIsA("SurfaceGui", true)
            if surfaceGui then
                surfaceGui.Enabled = false
            end
            
            for _, part in ipairs(visualModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    CoreInstance.getOriginalProperty(part, "Transparency")
                    CoreInstance.getOriginalProperty(part, "CanCollide")
                    
                    part.Transparency = 1
                    part.CanCollide = false
                elseif part:IsA("Texture") or part:IsA("Decal") then
                    CoreInstance.getOriginalProperty(part, "Transparency")
                    part.Transparency = 1
                end
            end
        end
        
        self:UpdateWallUI(wallFolder, 0, maxHp)
    end)

    Net.WallRepaired.On(function(data)
        local wallName = data.WallName
        
        local wallProps = self.Utils:GetWallProperties(wallName)
        local maxHp = wallProps and wallProps.Durability or 100
        
        self.WallHealthCache[wallName] = maxHp

        local wallFolder = workspace.Walls:FindFirstChild(wallName)
        if not wallFolder then return end

        local visualModel = wallFolder:FindFirstChild("Wall") or wallFolder:FindFirstChild("Model")
        if visualModel then
            local surfaceGui = visualModel:FindFirstChildWhichIsA("SurfaceGui", true)
            if surfaceGui then
                surfaceGui.Enabled = true
            end
            for _, part in ipairs(visualModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = CoreInstance.getOriginalProperty(part, "Transparency")
                    part.CanCollide = CoreInstance.getOriginalProperty(part, "CanCollide")
                elseif part:IsA("Texture") or part:IsA("Decal") then
                    part.Transparency = CoreInstance.getOriginalProperty(part, "Transparency")
                end
            end
        end
        
        self:UpdateWallUI(wallFolder, maxHp, maxHp) 
    end)

    self:InitializeWalls()
    self:SetupAutoHitboxes()
end

function GameController:GetHitAnimationTrack()
    local character = LocalPlayer.Character
    if not character then return nil end

    if self.HitAnimCharacter ~= character then
        self.HitAnimTrack = nil
        self.HitAnimCharacter = character
    end

    if not self.HitAnimTrack then
        local animator = GetAnimator(character)
        if animator then
            self.HitAnimTrack = LoadAnimation(animator, "112750204654217")
        end
    end

    return self.HitAnimTrack
end

function GameController:AttemptHit()
    local targetWall = self.CurrentAutoHitWall
    if not targetWall then return end 
    
    local currentHp = self.WallHealthCache[targetWall] or 0
    if currentHp <= 0 then return end

    local currentTime = os.clock()
    if currentTime - self.LastHit >= self.HitCooldown then
        self.LastHit = currentTime
        
        local track = self:GetHitAnimationTrack()
        
        if track then
            if self.HitMarkerConnection then
                self.HitMarkerConnection:Disconnect()
                self.HitMarkerConnection = nil
            end

            self.HitMarkerConnection = track:GetMarkerReachedSignal("Punch"):Connect(function()
                if self.HitMarkerConnection then
                    self.HitMarkerConnection:Disconnect()
                    self.HitMarkerConnection = nil
                end
                if self.CurrentAutoHitWall == targetWall and (self.WallHealthCache[targetWall] or 0) > 0 then
                    Net.HitWall.Fire()
                end
            end)

            track:Play()
            track:AdjustSpeed(2)
        end
    end
end

function GameController:SetupAutoHitboxes()
    local wallsFolder = workspace:FindFirstChild("Walls")
    if not wallsFolder then return end

    for _, wallFolder in ipairs(wallsFolder:GetChildren()) do
        local hitArea = wallFolder:FindFirstChild("HitArea")
        local hitboxPart = hitArea and hitArea:FindFirstChild("Hitbox")
        
        if hitboxPart then
            local trigger = TriggerComponent.new(hitboxPart, TriggerComponent.TouchType.Spatial)
            
            trigger.OnTouched:Connect(function(player)
                if player == LocalPlayer then
                    self.CurrentAutoHitWall = wallFolder.Name
                end
            end)

            trigger.OnTouchEnded:Connect(function(player)
                if player == LocalPlayer and self.CurrentAutoHitWall == wallFolder.Name then
                    self.CurrentAutoHitWall = nil
                end
            end)
        end
    end
end

function GameController:InitializeWalls()
    local wallsFolder = workspace:FindFirstChild("Walls")
    if not wallsFolder then return end

    for _, wallFolder in ipairs(wallsFolder:GetChildren()) do
        local wallName = wallFolder.Name
        local wallProps = self.Utils:GetWallProperties(wallName)
        local maxHp = wallProps and wallProps.Durability or 100
        
        local currentHp = maxHp 
        self.WallHealthCache[wallName] = maxHp
        
        self:InitWallUI(wallFolder, currentHp, maxHp)
    end
end

function GameController:SpawnDebris(visualModel)
    local debrisFolder = Instance.new("Folder")
    debrisFolder.Name = "DebrisFX"
    debrisFolder.Parent = workspace

    local debrisParts = {}

    local part = visualModel:IsA("Model") and visualModel.PrimaryPart

    if part then
        if part:IsA("BasePart") then
            local chunkCount = math.random(8,9)
            
            for i = 1, chunkCount do
                local chunk = Instance.new("Part")
                chunk.Size = Vector3.new(
                    math.random(10, 15) / 100, 
                    math.random(10, 15) / 100, 
                    math.random(10, 15) / 100
                ) * (part.Size.Magnitude / 3) 

                for _,texture in pairs(part:GetChildren()) do
                    if texture:IsA("Texture") then
                        texture:Clone().Parent = chunk
                    end
                end
                
                local randomOffset = Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10)
                chunk.CFrame = part.CFrame * CFrame.new(randomOffset)
                
                chunk.Color = part.Color
                chunk.Material = part.Material
                chunk.Anchored = false
                chunk.CanCollide = true
                chunk.Parent = debrisFolder
                chunk.Transparency = part.Transparency
                chunk.CollisionGroup = "NpcCollideable"
                
                local randomDir = Vector3.new(
                    math.random(-100, 100) / 100, 
                    math.random(50, 150) / 100,
                    math.random(-100, 100) / 100
                ).Unit
                
                local speed = math.random(40, 80)
                chunk.AssemblyLinearVelocity = randomDir * speed
                chunk.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
                
                table.insert(debrisParts, chunk)
            end
        end
    end

    task.delay(3, function()
        for _, chunk in ipairs(debrisParts) do
            if chunk and chunk.Parent then
                TweenService:Create(chunk, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Transparency = 1,
                    Size = Vector3.zero
                }):Play()
            end
        end
    end)

    Debris:AddItem(debrisFolder, 3.5)
end

function GameController:PlayHitEffect(visualModel)
    local rootPart = visualModel.PrimaryPart or visualModel:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end

    local camera = workspace.CurrentCamera
    if camera then
        local hitShake = self.CameraShakePreset:Clone()
        hitShake:Start()
        
        hitShake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot, isDone)
            local currentCamera = workspace.CurrentCamera
            if currentCamera then
                currentCamera.CFrame = currentCamera.CFrame * CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
            end
        end)
    end

    local originalCF = CoreInstance.getOriginalProperty(rootPart, "CFrame")

    if self.ActiveShakes[visualModel] then
        self.ActiveShakes[visualModel]:Destroy()
    end

    local shakeDuration = 0.25
    local shakeTween = TweenComponent.new(shakeDuration, function(alpha)
        if not rootPart or not rootPart.Parent then return end
        
        local damping = 1 - alpha 
        
        local shakeX = math.sin(alpha * math.pi * 6) * 0.15 * damping
        local shakeY = math.cos(alpha * math.pi * 5) * 0.15 * damping
        local shakeZ = math.sin(alpha * math.pi * 7) * 0.15 * damping
        
        rootPart.CFrame = originalCF * CFrame.new(shakeX, shakeY, shakeZ) * CFrame.Angles(shakeX/3, shakeY/3, shakeZ/3)
    end)

    shakeTween.Completed:Connect(function()
        if rootPart then rootPart.CFrame = originalCF end
        self.ActiveShakes[visualModel] = nil
        shakeTween:Destroy()
    end)
    
    self.ActiveShakes[visualModel] = shakeTween
    shakeTween:Play()

    local hologram = visualModel:Clone()
    hologram.Name = "HitHologram"
    local board = hologram:FindFirstChildWhichIsA("SurfaceGui",true)
    if board then
        board:Destroy()
    end
    
    local holoParts = {}
    
    for _, desc in ipairs(hologram:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Material = Enum.Material.Neon
            desc.Color = Color3.fromRGB(255, 255, 255)
            desc.CanCollide = false
            desc.Anchored = true
            desc.CastShadow = false
            table.insert(holoParts, desc)
        elseif desc:IsA("Texture") or desc:IsA("Decal") then
            desc.Transparency = 1 
        end
    end
    
    hologram.Parent = visualModel.Parent
    hologram:PivotTo(originalCF)

    self.AudioService:PlaySound("Hit")
    
    local baseScale = visualModel:IsA("Model") and CoreInstance.getOriginalProperty(visualModel, "Scale") or 1
    
    local holoDuration = 0.35
    local holoTween = TweenComponent.new(holoDuration, function(alpha)
        if not hologram or not hologram.Parent then return end
        
        local easeAlpha = 1 - (1 - alpha) * (1 - alpha)
        
        local currentScale = baseScale + (0.15 * easeAlpha)
        hologram:ScaleTo(math.max(0.001, currentScale))
        
        for _, part in ipairs(holoParts) do
            part.Transparency = alpha 
        end
    end)
    
    holoTween.Completed:Connect(function()
        if hologram then hologram:Destroy() end
        holoTween:Destroy()
    end)
    
    holoTween:Play()
end

function GameController:UpdateWallUI(wallFolder, currentHp, maxHp)
    local wall = wallFolder:FindFirstChild("Wall")
    if not wall then return end
    
    local billboard = wall:FindFirstChildWhichIsA("SurfaceGui", true)
    if billboard then
        local mainFrame = billboard:FindFirstChild("MainFrame")
        if not mainFrame then return end
        local fillBar = mainFrame:FindFirstChild("GreenBar", true)
        local hpText = mainFrame:FindFirstChild("HpText", true)
        
        if fillBar then
            local percent = math.clamp(currentHp / maxHp, 0, 1)
            TweenService:Create(fillBar, TweenInfo.new(0.15), {Size = UDim2.fromScale(percent, 1)}):Play()
        end
        if hpText then
            hpText.Text = tostring(currentHp) .. " / " .. tostring(maxHp)
        end
    end
end

function GameController:InitWallUI(wallFolder, currentHp, maxHp)
    local wall = wallFolder:FindFirstChild("Wall")
    if not wall then return end

    local wallProps = self.Utils:GetWallProperties(wallFolder.Name)
    if not wallProps then return end
    
    local billboard = wall:FindFirstChildWhichIsA("SurfaceGui", true)
    if billboard then
        local mainFrame = billboard:FindFirstChild("MainFrame")
        if not mainFrame then return end
        local fillBar = mainFrame:FindFirstChild("GreenBar", true)
        local hpText = mainFrame:FindFirstChild("HpText", true)
        local skipButton = mainFrame:FindFirstChild("SkipButton")
        if skipButton then
            local robuxText = skipButton:FindFirstChild("Count",true)
            if robuxText then
                self.MonetizationService:GetMarketplaceInfo(wallFolder.Name,false):andThen(function(data)
                    robuxText.Text = "SKIP R$ "..data.PriceInRobux
                end)
            end
            AnimationComponent.new(skipButton):Init(nil, function()
                self.MonetizationService:PromptProduct(wallFolder.Name)
            end)
        end
        
        if fillBar then
            local percent = math.clamp(currentHp / maxHp, 0, 1)
            TweenService:Create(fillBar, TweenInfo.new(0.15), {Size = UDim2.fromScale(percent, 1)}):Play()
        end
        if hpText then
            hpText.Text = tostring(currentHp) .. " / " .. tostring(maxHp)
        end
    end
end

function GameController:GetWallNameForArea(areaID)
    if not areaID then return nil end
    local areaStr = tostring(areaID)
    
    if not next(self.AreaToWallMapping) then
        local wallsFolder = workspace:FindFirstChild("Walls")
        if wallsFolder then
            for _, wallFolder in ipairs(wallsFolder:GetChildren()) do
                local props = self.Utils:GetWallProperties(wallFolder.Name)
                if props and props.AreaID then
                    self.AreaToWallMapping[tostring(props.AreaID)] = wallFolder.Name
                    
                    if not table.find(self.SortedAreaIDs, tonumber(props.AreaID)) then
                        table.insert(self.SortedAreaIDs, tonumber(props.AreaID))
                    end
                end
            end
            table.sort(self.SortedAreaIDs)
        end
    end

    return self.AreaToWallMapping[areaStr] or areaStr
end

function GameController:ShouldRenderArea(areaID)
    if not areaID then return true end 
    
    self:GetWallNameForArea(areaID)
    
    local numAreaID = tonumber(areaID)
    if not numAreaID or #self.SortedAreaIDs == 0 then return true end
    
    local firstUnbrokenIndex = nil
    for i, aID in ipairs(self.SortedAreaIDs) do
        local wName = self.AreaToWallMapping[tostring(aID)]
        local hp = wName and self.WallHealthCache[wName]
        
        if hp and hp > 0 then
            firstUnbrokenIndex = i
            break
        end
    end
    
    if not firstUnbrokenIndex then return true end
    
    local requestedIndex = nil
    for i, aID in ipairs(self.SortedAreaIDs) do
        if aID == numAreaID then
            requestedIndex = i
            break
        end
    end
    
    if not requestedIndex then return true end
    
    if requestedIndex <= firstUnbrokenIndex + 1 then
        return true
    end
    
    return false
end

return GameController