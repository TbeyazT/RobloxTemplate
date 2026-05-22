local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))
local Trove = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))

local ProximityComponent = require("@Components/ProximityComponent")
local Utils = require(script.Parent.Utils)

local GetAnimator = require("@Modules/Utils/GetAnimator")
local LoadAnimation = require("@Modules/Utils/LoadAnimation")

local LocalPlayer = Players.LocalPlayer
local Assets = ReplicatedStorage:WaitForChild("Assets")

local RENDER_DISTANCE = 150 

local FoodController = {}

function FoodController:Init()
    self.VisualFoods = {}
    self.Prompts = {}
    self.FoodInfos = {}
    self.FoodSpawnCFrames = {}
    self.CurrentlyEating = nil
    
    self.ActiveEatTracks = {} 
    
    self.FoodStatsTemplate = Assets.Models:WaitForChild("FoodStats")
    
    self.FoodsFolder = workspace:FindFirstChild("ClientFoods")
    if not self.FoodsFolder then
        self.FoodsFolder = Instance.new("Folder")
        self.FoodsFolder.Name = "ClientFoods"
        self.FoodsFolder.Parent = workspace
    end

    self.CleanTrove = Trove.new()
end

function FoodController:Start()
    local function preloadCharacterAnimations(player, char)
        task.spawn(function()
            local animator = GetAnimator(char)
            
            if animator then
                local pData = {
                    Char = char,
                    StartTrack = LoadAnimation(animator, "80124011177382"),
                    LoopTrack = LoadAnimation(animator, "116023126166244"),
                    StopTrack = LoadAnimation(animator, "129643072036120"),
                    IsEating = false
                }
                if pData.LoopTrack then pData.LoopTrack.Looped = true end
                
                self.ActiveEatTracks[player] = pData
            end
        end)
    end

    local function setupPlayer(player)
        if player.Character then
            preloadCharacterAnimations(player, player.Character)
        end
        self.CleanTrove:Connect(player.CharacterAdded, function(char)
            preloadCharacterAnimations(player, char)
        end)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        setupPlayer(player)
    end
    self.CleanTrove:Connect(Players.PlayerAdded, setupPlayer)
    self.CleanTrove:Connect(Players.PlayerRemoving, function(player)
        self.ActiveEatTracks[player] = nil
    end)


    Net.FoodInitialData.SetCallback(function(data)
        for _, info in ipairs(data) do
            self:CreateFoodVisual(info.ID, info)
        end
    end)

    Net.FoodSpawned.On(function(info)
        self:CreateFoodVisual(info.ID, info)
    end)

    Net.FoodDespawned.On(function(data)
        self:DestroyFoodVisual(data.ID)
    end)

    Net.FoodEaterUpdated.On(function(data)
        self:UpdateFoodEater(data.ID, data.Eater)
    end)

    Net.FoodCapacityUpdated.On(function(updates)
        for _, updateData in ipairs(updates) do
            local foodID = updateData.ID
            local newCapacity = updateData.Capacity
            
            local visual = self.VisualFoods[foodID]
            if visual then
                local ui = visual:FindFirstChild("FoodStats")
                if ui then
                    local maxCap = visual:GetAttribute("MaxCapacity") or 10
                    local foodFrame = ui:FindFirstChild("FoodFrame")
                    local barFrame = foodFrame and foodFrame:FindFirstChild("BarFrame")
                    
                    local fill = barFrame and barFrame:FindFirstChild("GreenBar")
                    local text = barFrame and barFrame:FindFirstChild("ConsumedText")
                    
                    if fill then
                        TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Circular,Enum.EasingDirection.Out), {
                            Size = UDim2.new(math.max(0, newCapacity / maxCap), 0, 1, 0)
                        }):Play()
                    end
                    
                    if text then
                        text.Text = math.ceil(newCapacity) .. " / " .. maxCap
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            self:UpdateRenderDistances()
        end
    end)
end

function FoodController:SetEatingAnimation(player: Player, isEating: boolean)
    local char = player.Character
    if not char then return end

    local pData = self.ActiveEatTracks[player]

    if not pData or pData.Char ~= char then
        local animator = GetAnimator(char)
        if not animator then return end
        
        pData = {
            Char = char,
            StartTrack = LoadAnimation(animator, "80124011177382"),
            LoopTrack = LoadAnimation(animator, "116023126166244"),
            StopTrack = LoadAnimation(animator, "129643072036120"),
        }
        if pData.LoopTrack then pData.LoopTrack.Looped = true end
        self.ActiveEatTracks[player] = pData
    end

    pData.IsEating = isEating

    if isEating then
        if pData.StopTrack then pData.StopTrack:Stop() end
        
        if pData.StartTrack then
            pData.StartTrack:Play()
            
            if pData.StartConn then pData.StartConn:Disconnect() end
            pData.StartConn = pData.StartTrack.Stopped:Connect(function()
                if pData.IsEating and pData.LoopTrack then
                    pData.LoopTrack:Play()
                end
            end)
        elseif pData.LoopTrack then
            pData.LoopTrack:Play()
        end
    else
        if pData.StartTrack then pData.StartTrack:Stop() end
        if pData.LoopTrack then pData.LoopTrack:Stop() end
        
        if pData.StopTrack then
            pData.StopTrack:Play()
        end
    end
end

function FoodController:UpdateRenderDistances()
    local char = LocalPlayer.Character
    local root = char and char.PrimaryPart
    local playerPos = root and root.Position

    for foodID, info in pairs(self.FoodInfos) do
        local visual = self.VisualFoods[foodID]
        if not visual then continue end

        local shouldRender = false

        if info.Eater then
            shouldRender = true
        elseif playerPos and self.FoodSpawnCFrames[foodID] then
            local dist = (self.FoodSpawnCFrames[foodID].Position - playerPos).Magnitude
            if dist <= RENDER_DISTANCE then
                shouldRender = true
            end
        end

        if shouldRender then
            if visual.Parent ~= self.FoodsFolder then
                visual.Parent = self.FoodsFolder
            end
            
            if not info.Eater then
                if not self.Prompts[foodID] then
                    self:CreatePrompt(foodID, visual, info)
                end
            else
                if self.Prompts[foodID] then
                    self:DestroyPrompt(foodID)
                end
            end
        else
            if visual.Parent ~= nil then
                visual.Parent = nil
            end
            
            if self.Prompts[foodID] then
                self:DestroyPrompt(foodID)
            end
        end
    end
end

function FoodController:CreatePrompt(foodID: string, clone: Model, info)
    local promptRoot = clone:GetPivot().Position + Vector3.new(0, 3, 0)
    local prompt = ProximityComponent.new({
        Root = promptRoot,
        Target = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart,
        Range = 15,
        KeyCode = Enum.KeyCode.E,
        ActionText = "Eat " .. info.Name,
        HoldDuration = 0.5
    })

    prompt.Triggered:Connect(function()
        self:RequestEat(foodID)
    end)
    
    prompt:Start()
    self.Prompts[foodID] = prompt
end

function FoodController:DestroyPrompt(foodID: string)
    local prompt = self.Prompts[foodID]
    if prompt then
        if type(prompt.Stop) == "function" then prompt:Stop() end
        if type(prompt.Destroy) == "function" then prompt:Destroy() end
        if type(prompt.Cleanup) == "function" then prompt:Cleanup() end
        self.Prompts[foodID] = nil
    end
end

function FoodController:UpdateFoodEater(foodID: string, player: Player?)
    local visual = self.VisualFoods[foodID]
    if not visual then return end
    
    local oldEater = nil
    if self.FoodInfos[foodID] then
        oldEater = self.FoodInfos[foodID].Eater
        self.FoodInfos[foodID].Eater = player
    end

    if oldEater and oldEater ~= player then
        self:SetEatingAnimation(oldEater, false)
    end

    if player then
        self:SetEatingAnimation(player, true)
    end

    if player == nil and self.CurrentlyEating == foodID then
        self.CurrentlyEating = nil
    end

    local oldWeld = visual:FindFirstChild("EaterWeld")
    if oldWeld then oldWeld:Destroy() end

    if player then
        visual.Parent = self.FoodsFolder
        
        local char = player.Character
        if char then
            local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char.PrimaryPart
            local pp = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
            
            if hand and pp then
                for _, desc in ipairs(visual:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        desc.CanCollide = false
                        desc.Massless = true
                        desc.Anchored = false
                    end
                end
                
                visual:PivotTo(hand.CFrame * CFrame.new(0, -hand.Size.Y/2, 0) * CFrame.Angles(math.rad(-90), 0, 0))
                
                local weld = Instance.new("WeldConstraint")
                weld.Name = "EaterWeld"
                weld.Part0 = hand
                weld.Part1 = pp
                weld.Parent = visual
            end
        end
    else
        local spawnCF = self.FoodSpawnCFrames[foodID]
        if spawnCF then
            for _, desc in ipairs(visual:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Anchored = true
                    
                    local occ = desc:GetAttribute("OriginalCanCollide")
                    if occ ~= nil then desc.CanCollide = occ end
                    
                    local om = desc:GetAttribute("OriginalMassless")
                    if om ~= nil then desc.Massless = om end
                end
            end
            visual:PivotTo(spawnCF)
        end
    end
    
    self:UpdateRenderDistances()
end

function FoodController:CreateFoodVisual(foodID: string, info)
    if self.VisualFoods[foodID] then return end

    local baseModel = Utils:GetFoodModel(info.Name)
    if not baseModel then return end

    local clone = baseModel:Clone()
    clone.Name = foodID
    clone:SetAttribute("MaxCapacity", info.MaxCapacity)
    
    local targetPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        clone.PrimaryPart = targetPart
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc:SetAttribute("OriginalCanCollide", desc.CanCollide)
                desc:SetAttribute("OriginalMassless", desc.Massless)
                
                if desc ~= targetPart then
                    local weld = Instance.new("WeldConstraint")
                    weld.Name = "InternalFoodWeld"
                    weld.Part0 = targetPart
                    weld.Part1 = desc
                    weld.Parent = desc
                end
            end
        end
    end
    
    local FoodBBoxCF, FoodSize = clone:GetBoundingBox()
    local pivotOffset = clone:GetPivot():ToObjectSpace(FoodBBoxCF)
    local distanceToBottom = (FoodSize.Y / 2) - pivotOffset.Y
    
    local targetCFrame = info.CFrame * CFrame.new(0, distanceToBottom, 0)
    
    clone.Parent = nil

    self.FoodInfos[foodID] = info
    self.FoodSpawnCFrames[foodID] = targetCFrame
    self.VisualFoods[foodID] = clone

    if targetPart then
        local ui = self.FoodStatsTemplate:Clone()
        ui.Name = "FoodStats"
        ui.Adornee = targetPart
        ui.Parent = clone

        local foodFrame = ui:FindFirstChild("FoodFrame")
        if foodFrame then
            local nameLabel = foodFrame:FindFirstChild("somename")
            if nameLabel then
                nameLabel.Text = info.Name
            end

            local barFrame = foodFrame:FindFirstChild("BarFrame")
            if barFrame then
                local fill = barFrame:FindFirstChild("GreenBar")
                local text = barFrame:FindFirstChild("ConsumedText")

                if fill then fill.Size = UDim2.new(info.Capacity / info.MaxCapacity, 0, 1, 0) end
                if text then text.Text = math.ceil(info.Capacity) .. " / " .. info.MaxCapacity end
            end
        end
    end

    if info.Eater then
        self:UpdateFoodEater(foodID, info.Eater)
    else
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("BasePart") then desc.Anchored = true end
        end
        clone:PivotTo(targetCFrame)
        self:UpdateRenderDistances()
    end
end

function FoodController:DestroyFoodVisual(foodID: string)
    if self.CurrentlyEating == foodID then
        self:CancelEating()
    end
    
    local oldEater = nil
    if self.FoodInfos[foodID] then
        oldEater = self.FoodInfos[foodID].Eater
    end
    if oldEater then
        self:SetEatingAnimation(oldEater, false)
    end

    self:DestroyPrompt(foodID)

    self.FoodInfos[foodID] = nil
    self.FoodSpawnCFrames[foodID] = nil

    local visual = self.VisualFoods[foodID]
    if visual then
        visual:Destroy()
        self.VisualFoods[foodID] = nil
    end
end

function FoodController:RequestEat(foodID: string)
    if self.CurrentlyEating == foodID then return end
    
    self:DestroyPrompt(foodID)
    self.CurrentlyEating = foodID
    
    task.spawn(function()
        local success = Net.StartEatingFood.Call(foodID)
        
        if not success then
            if self.CurrentlyEating == foodID then
                self.CurrentlyEating = nil
            end
            self:UpdateRenderDistances()
        end
    end)
end

function FoodController:CancelEating()
    if not self.CurrentlyEating then return end
    self.CurrentlyEating = nil
    Net.StopEatingFood.Fire()
end

return FoodController