local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService") 

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local FormatNumber = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Core'):FindFirstChild('FormatNumber'))
local RarityColors = require("@Modules/UI/RarityGradients")

local Trove = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))

local ProximityComponent = require("@Components/ProximityComponent")

local LocalPlayer = Players.LocalPlayer
local Assets = ReplicatedStorage:FindFirstChild("Assets")

local BrainrotController = {}

function BrainrotController:Init()
    self.Utils = require(script.Parent.Utils)
    
    self.VisualSpawns = {}
    self.WorldBrainrotsData = {} 
    self.Prompts = {}
    self.CarriedVisuals = {}
    self.RenderConnections = {} 
    
    self.SpawnsFolder = workspace:FindFirstChild("ClientWorldBrainrots")
    if not self.SpawnsFolder then
        self.SpawnsFolder = Instance.new("Folder")
        self.SpawnsFolder.Name = "ClientWorldBrainrots"
        self.SpawnsFolder.Parent = workspace
    end

    self.InteractionHighlight = Instance.new("Highlight")
    self.InteractionHighlight.FillColor = Color3.fromRGB(255, 255, 255)
    self.InteractionHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    self.InteractionHighlight.FillTransparency = 1
    self.InteractionHighlight.OutlineTransparency = 1
    self.InteractionHighlight.Parent = self.SpawnsFolder

    self.CleanTrove = Trove.new()
end

function BrainrotController:Start()
    self.GameController = Framework.Get("GameService")

    Net.WorldBrainrotInitialData.SetCallback(function(data)
        for _, info in ipairs(data) do
            self.WorldBrainrotsData[info.ID] = info
            
            if self.GameController:ShouldRenderArea(info.AreaID) then
                self:CreateWorldVisual(info.ID, info.Name, info.CFrame, info.DespawnTime)
            end
        end
    end)

    Net.WorldBrainrotSpawned.On(function(info)
        self.WorldBrainrotsData[info.ID] = info
        
        if self.GameController:ShouldRenderArea(info.AreaID) then
            self:CreateWorldVisual(info.ID, info.Name, info.CFrame, info.DespawnTime)
        end
    end)

    Net.WorldBrainrotDespawned.On(function(data)
        self.WorldBrainrotsData[data.ID] = nil
        self:DestroyWorldVisual(data.ID)
    end)
    
    Net.WallDestroyed.On(function(data)
        task.defer(function()
            self:RefreshAllBrainrotsVisibility()
        end)
    end)
    
    Net.WallRepaired.On(function(data)
        task.defer(function()
            self:RefreshAllBrainrotsVisibility()
        end)
    end)

    Net.PlayerCarryingBrainrot.On(function(data)
        self:RenderCarriedBrainrot(data.Player, data.CarriedList)
    end)
    
    Net.PlayerDroppedBrainrot.On(function(data)
        self:RemoveCarriedBrainrot(data.Player)
    end)
end

function BrainrotController:RefreshAllBrainrotsVisibility()
    for id, info in pairs(self.WorldBrainrotsData) do
        local shouldRender = self.GameController:ShouldRenderArea(info.AreaID)
        
        if shouldRender then
            if not self.VisualSpawns[id] then
                self:CreateWorldVisual(info.ID, info.Name, info.CFrame, info.DespawnTime)
            end
        else
            if self.VisualSpawns[id] then
                self:DestroyWorldVisual(id)
            end
        end
    end
end

local function setBillboardText(billboard, nodeName, text)
    local node = billboard:FindFirstChild(nodeName, true)
    if not node then return nil end
    
    if node:IsA("TextLabel") then
        node.Text = text
        return node
    else
        local txtNode = node:FindFirstChildWhichIsA("TextLabel", true)
        if txtNode then 
            txtNode.Text = text 
            return txtNode
        end
    end
    return nil
end

function BrainrotController:RenderCarriedBrainrot(player, carriedList)
    self:RemoveCarriedBrainrot(player)
    
    local char = player.Character
    if not char then return end
    
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return end
    
    self.CarriedVisuals[player] = {}
    
    local currentYOffset = 0
    
    for i, brainrotName in ipairs(carriedList) do
        local baseModel = self.Utils:GetBrainrotModel(brainrotName)
        if not baseModel then continue end
        
        local clone = baseModel:Clone()
        clone.Name = "CarriedBrainrot_" .. i
        
        local root = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
        
        if root then
            for _, p in ipairs(clone:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Anchored = false
                    p.CanCollide = false 
                    p.Massless = true 
                    p.CastShadow = false
                end
            end
            
            local _, size = clone:GetBoundingBox()
            local itemHeight = size.Y
            
            currentYOffset = currentYOffset + (itemHeight / 2)
            
            clone:PivotTo(torso.CFrame * CFrame.new(0, currentYOffset, -2))
            
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = torso
            weld.Part1 = root
            weld.Parent = clone
            
            local statsUI = Assets.Models:FindFirstChild("BrainrotStats")
            local props = self.Utils:GetBrainrotProperties(brainrotName)
            if statsUI then
                local uiClone = statsUI:Clone()
                uiClone.Adornee = root
                uiClone.Parent = clone
                
                local timerFrame = uiClone:FindFirstChild("TimerFrame", true)
                if timerFrame then timerFrame.Visible = false end
                
                setBillboardText(uiClone, "BrainrotName", props and props.Name or brainrotName)
                setBillboardText(uiClone, "Earning", "$" .. FormatNumber(props and props.CashPS or 0) .. "/s")
                local text = setBillboardText(uiClone, "Rarity", props and props.Rarity or "Common")
                if text then
                    local gradient = text:FindFirstChildWhichIsA("UIGradient")
                    if gradient then
                        gradient.Color = RarityColors[props.Rarity]
                    end
                end
                setBillboardText(uiClone, "Tier", "Level 0")
            end

            clone.Parent = char
            table.insert(self.CarriedVisuals[player], clone)
            
            currentYOffset = currentYOffset + (itemHeight / 2) + 0.2
        end
    end
end

function BrainrotController:RemoveCarriedBrainrot(player)
    if self.CarriedVisuals[player] then
        for _, visual in ipairs(self.CarriedVisuals[player]) do
            if visual then visual:Destroy() end
        end
        self.CarriedVisuals[player] = nil
    end
end

function BrainrotController:CreateWorldVisual(id: string, name: string, spawnCFrame: CFrame, despawnTime: number)
    if self.VisualSpawns[id] then return end

    local baseModel = self.Utils:GetBrainrotModel(name)
    local props = self.Utils:GetBrainrotProperties(name)
    if not baseModel then return end

    local clone = baseModel:Clone()
    clone.Name = id
    
    local BBoxCF, FoodSize = clone:GetBoundingBox()
    local pivotOffset = clone:GetPivot():ToObjectSpace(BBoxCF)
    local distanceToBottom = (FoodSize.Y / 2) - pivotOffset.Y
    
    local targetCFrame = spawnCFrame * CFrame.new(0, distanceToBottom, 0)
    
    clone:PivotTo(targetCFrame)
    clone.Parent = self.SpawnsFolder
   
    local statsUI = Assets.Models:FindFirstChild("BrainrotStats")
    local timerTextNode = nil
    
    if statsUI then
        local uiClone = statsUI:Clone()
        uiClone.Adornee = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
        uiClone.Parent = clone
        
        local timerFrame = uiClone:FindFirstChild("TimerFrame", true)
        if timerFrame then timerFrame.Visible = true end
        
        setBillboardText(uiClone, "BrainrotName", props and props.Name or name)
        setBillboardText(uiClone, "Earning", "$" .. FormatNumber(props and props.CashPS or 0) .. "/s")
        local text = setBillboardText(uiClone, "Rarity", props and props.Rarity or "Common")
        if text then
            local gradient = text:FindFirstChildWhichIsA("UIGradient")
            if gradient then
                gradient.Color = RarityColors[props.Rarity]
            end
        end
        setBillboardText(uiClone, "Tier", "Level 0")
        
        timerTextNode = setBillboardText(uiClone, "Timer", "00:00")
    end

    local promptRoot = spawnCFrame.Position + Vector3.new(0, 2, 0)
    local prompt = ProximityComponent.new({
        Root = promptRoot,
        Target = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart,
        Range = 10,
        KeyCode = Enum.KeyCode.E,
        ActionText = "Grab " .. name,
        HoldDuration = 0.4
    })

    local baseScale = 1
    clone:ScaleTo(1.4)
    pcall(function() baseScale = clone:GetScale() end)
    
    local currentScale = baseScale
    local targetScale = baseScale

    prompt.Entered:Connect(function()
        targetScale = baseScale * 1.25
        self.InteractionHighlight.Adornee = clone
        TweenService:Create(self.InteractionHighlight, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FillTransparency = 0.6,
            OutlineTransparency = 0
        }):Play()
    end)

    prompt.Left:Connect(function()
        targetScale = baseScale
        local fadeOut = TweenService:Create(self.InteractionHighlight, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FillTransparency = 1,
            OutlineTransparency = 1
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            if self.InteractionHighlight.Adornee == clone then
                self.InteractionHighlight.Adornee = nil
            end
        end)
    end)

    prompt.Updated:Connect(function(distance, alpha, holdProgress)
        if holdProgress > 0 then
            targetScale = baseScale * (1.25 - (0.75 * holdProgress)) 
        elseif prompt.IsInRange then
            targetScale = baseScale * 1.25
        end
    end)

    prompt.Triggered:Connect(function()
        targetScale = baseScale 
        self.InteractionHighlight.Adornee = nil
        self.InteractionHighlight.FillTransparency = 1
        self.InteractionHighlight.OutlineTransparency = 1
        
        Net.GrabBrainrot.Fire({ID = id})
    end)
    
    local renderConn = RunService.Heartbeat:Connect(function(dt)
        if not clone or not clone.Parent then return end
        
        if timerTextNode then
            local timeLeft = math.max(0, despawnTime - workspace:GetServerTimeNow())
            local mins = math.floor(timeLeft / 60)
            local secs = math.floor(timeLeft % 60)
            timerTextNode.Text = string.format("%02d:%02d", mins, secs)
        end
        
        currentScale = currentScale + (targetScale - currentScale) * math.min(dt * 15, 1)
        pcall(function()
            clone:ScaleTo(math.max(0.001, currentScale))
            clone:PivotTo(spawnCFrame * CFrame.new(0, distanceToBottom * currentScale, 0))
        end)
    end)
    
    self.RenderConnections[id] = renderConn

    prompt:Start()
    self.Prompts[id] = prompt
    self.VisualSpawns[id] = clone
end

function BrainrotController:DestroyWorldVisual(id: string)
    if self.RenderConnections[id] then
        self.RenderConnections[id]:Disconnect()
        self.RenderConnections[id] = nil
    end

    if self.Prompts[id] then
        if typeof(self.Prompts[id].Destroy) == "function" then
            self.Prompts[id]:Destroy()
        end
        self.Prompts[id] = nil
    end

    local visual = self.VisualSpawns[id]
    if visual then
        if self.InteractionHighlight and self.InteractionHighlight.Adornee == visual then
            self.InteractionHighlight.Adornee = nil
            self.InteractionHighlight.FillTransparency = 1
            self.InteractionHighlight.OutlineTransparency = 1
        end
        visual:Destroy()
        self.VisualSpawns[id] = nil
    end
end

function BrainrotController:Destroy()
    for player, _ in pairs(self.CarriedVisuals) do
        self:RemoveCarriedBrainrot(player)
    end
    for _, conn in pairs(self.RenderConnections) do
        if conn then conn:Disconnect() end
    end
    table.clear(self.RenderConnections)
    if self.InteractionHighlight then self.InteractionHighlight:Destroy() end
    self.CleanTrove:Destroy()
end

return BrainrotController