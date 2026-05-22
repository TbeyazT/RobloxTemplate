local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Trove = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local ProximityComponent = require("@Components/ProximityComponent")
local AnimationComponent = require("@Components/AnimationComponent")
local TriggerComponent = require("@Components/TriggerComponent")
local TweenComponent = require("@Components/TweenComponent")

local RarityColors = require("@Modules/UI/RarityGradients")
local FormatNumber = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Core'):FindFirstChild('FormatNumber'))
local CoreInstance = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Core'):FindFirstChild('Instance'))

local PlotClass = {}
PlotClass.__index = PlotClass

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

function PlotClass.new(Data: { Owner: Player, PlotFolder: Folder, PlotBase: Model, BrainrotPlots: Folder })
    local self = setmetatable({}, PlotClass)

    self.ProfileService = Framework.Get("ProfileService")
    self.NotificationService = Framework.Get("NotificationService")
    self.CharacterService = Framework.Get("CharacterService")
    self.AudioService = Framework.Get("AudioService")
    self.BrainrotUtils = require(script.Parent.Parent:FindFirstChild('BrainrotService'):FindFirstChild('Utils'))    
    
self.Owner = Data.Owner
    self.PlotFolder = Data.PlotFolder
    self.PlotBase = Data.PlotBase
    self.BrainrotPlots = Data.BrainrotPlots
    
    self._prompts = {}
    self.ActiveBrainrotVisuals = {}
    self.AllClientPlots = {} 
    self.CurrentlyEquippedBrainrotID = nil
    
    self.CleanTrove = Trove.new()

    self:RenumberBrainrotPlots(self.PlotBase, 0)

    self.CleanTrove:Add(self.ProfileService:Observe("BaseUpgrades", function()
        self:UpdatePlot()
    end, self.Owner))

    self.CleanTrove:Add(self.ProfileService:Observe("Brainrots", function()
        self:UpdateBrainrotPlots()
    end, self.Owner))

    self.CleanTrove:Add(self.ProfileService:Observe("Multipliers", function()
        self:UpdateBrainrotPlots()
    end, self.Owner))

    self:UpdatePlot()
    self:UpdateBrainrotPlots()
    local baseUpgradeNode = self.PlotBase:FindFirstChild("Upgrade")
    if baseUpgradeNode then
        self:SetupBaseUpgradeButton(baseUpgradeNode)
    end

    if self.Owner == LocalPlayer then
        local function setupCharacterListeners(character)
            self.CleanTrove:Connect(character.ChildAdded, function(child)
                if child:IsA("Tool") then 
                    self.CurrentlyEquippedBrainrotID = child.Name
                    self:RefreshPrompts()
                    
                    self.ProfileService:Get("Brainrots", self.Owner):andThen(function(brainrotsData)
                        if not brainrotsData then return end
                        for _, bData in ipairs(brainrotsData) do
                            if bData.ID == child.Name then
                                local statsUI = Assets.Models:FindFirstChild("BrainrotStats")
                                if statsUI and not child:FindFirstChild("BrainrotStats") then
                                    local uiClone = statsUI:Clone()
                                    uiClone.Name = "BrainrotStats"
                                    local handle = child:FindFirstChild("Handle") or child:FindFirstChildWhichIsA("BasePart")
                                    uiClone.Adornee = handle
                                    uiClone.Parent = child

                                    local timerFrame = uiClone:FindFirstChild("TimerFrame", true)
                                    if timerFrame then timerFrame.Visible = false end

                                    local props = self.BrainrotUtils:GetBrainrotProperties(bData.Name)
                                    setBillboardText(uiClone, "BrainrotName", props and props.Name or bData.Name)
                                    setBillboardText(uiClone, "Earning", "$" .. FormatNumber(props and props.CashPS or 0) .. "/s")
                                    local text = setBillboardText(uiClone, "Rarity", props and props.Rarity or "Common")
                                    if text then
                                        local gradient = text:FindFirstChildWhichIsA("UIGradient")
                                        if gradient then
                                            gradient.Color = RarityColors[props.Rarity]
                                        end
                                    end
                                    setBillboardText(uiClone, "Tier", "Level " .. tostring(bData.Level or 0))
                                end
                                break
                            end
                        end
                    end)
                end
            end)
            
            self.CleanTrove:Connect(character.ChildRemoved, function(child)
                if child:IsA("Tool") and child.Name == self.CurrentlyEquippedBrainrotID then
                    self.CurrentlyEquippedBrainrotID = nil
                    self:RefreshPrompts()
                end
            end)

            local tool = character:FindFirstChildWhichIsA("Tool")
            if tool then
                self.CurrentlyEquippedBrainrotID = tool.Name
                self:RefreshPrompts()
            end
        end

        local charData = self.CharacterService:GetPlayerData(LocalPlayer)
        if charData and charData.Character then
            setupCharacterListeners(charData.Character)
        end

        self.CleanTrove:Connect(self.CharacterService.CharacterAdded, setupCharacterListeners)
    end

    return self
end

function PlotClass:RenumberBrainrotPlots(model: Model, floorIndex: number)
    local localPlotsFolder = model:FindFirstChild("Plots")
    if not localPlotsFolder then return end

    local plots = localPlotsFolder:GetChildren()
    
    table.sort(plots, function(a, b)
        local numA = tonumber(a.Name) or 0
        local numB = tonumber(b.Name) or 0
        return numA < numB
    end)

    local plotsPerFloor = 10

    for index, plot in ipairs(plots) do
        local newNumber = (floorIndex * plotsPerFloor) + index
        plot.Parent = self.BrainrotPlots
        plot.Name = tostring(newNumber)
        local collectNode = plot:FindFirstChild("Collect")
        if collectNode then
            self:SetupCollectButton(collectNode, newNumber)
        end
        local upgradeStuff = plot:FindFirstChild("Upgrade")
        if upgradeStuff then
            self:SetupUpgradeButton(upgradeStuff, newNumber)
        end
    end
    
    localPlotsFolder:Destroy()
end

function PlotClass:UpdatePlot()
    self.ProfileService:Get("BaseUpgrades", self.Owner):andThen(function(baseUpgrades)
        if type(baseUpgrades) ~= "number" or baseUpgrades <= 0 then return end
        
        local baseCFrame = self.PlotBase:GetPivot()
        local floorHeight = 18

        for i = 1, baseUpgrades do
            local floorName = "Plot_" .. i
            
            if not self.PlotFolder:FindFirstChild(floorName) then
                if self.PlotFolder:FindFirstChild("Plot_" .. (i - 1)) then
                    baseCFrame = self.PlotFolder["Plot_" .. (i - 1)]:GetPivot()
                end
                
                local topPlot = Assets.Models.Plot:Clone()
                topPlot.Name = floorName

                local heightOffset = CFrame.new(0, i == 1 and 0 or floorHeight, 0)
                
                topPlot:PivotTo(baseCFrame * heightOffset)
                topPlot.Parent = self.PlotFolder
                
                self:RenumberBrainrotPlots(topPlot, i)
            end
        end
    end)
end

local Debris = game:GetService("Debris")

function PlotClass:SetupCollectButton(collectNode, plotIndex)
    if not collectNode then return end

    local mainPart = collectNode:FindFirstChild("Main")
    if not mainPart then return end

    local displayer = mainPart:FindFirstChild("Displayer")
    local nameText = displayer and displayer:FindFirstChild("Name")
    
    if nameText then nameText.Text = "$0" end

    self.CleanTrove:Add(self.ProfileService:Observe("Brainrots", function(brainrotsData)
        if not nameText then return end
        
        local padCash = 0
        
        if brainrotsData then
            for _, bData in ipairs(brainrotsData) do
                if bData.AssignedPlot == plotIndex then
                    padCash = math.floor(bData.EarnedCash or 0)
                    break
                end
            end
        end
        
        nameText.Text = "$" .. FormatNumber(padCash, false)
    end, self.Owner))

    if self.Owner == LocalPlayer then
        local startCFrame = mainPart.CFrame
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
        local pressTween = TweenService:Create(mainPart, tweenInfo, {CFrame = startCFrame * CFrame.new(0, -0.15, 0)})

        local trigger = TriggerComponent.new(mainPart, TriggerComponent.TouchType.Physics)
        self.CleanTrove:Add(trigger)

        local debounce = false

        trigger.OnTouched:Connect(function(player)
            if player ~= LocalPlayer then return end
            if debounce then return end
            debounce = true

            self.ProfileService:Get("Brainrots", self.Owner):andThen(function(brainrotsData)
                if not brainrotsData then return end
                
                local claimed = false

                for _, bData in ipairs(brainrotsData) do
                    if bData.AssignedPlot == plotIndex and (bData.EarnedCash or 0) > 0 then
                        pressTween:Play()
                        
                        Net.ClaimBrainrotCash.Call({ID = bData.ID})
                        self:PlayClaimRotationEffect(plotIndex)

                        self.BrainrotUtils:EmitParticles("116539200602942",{
                            Sound = "CashRegister"
                        })

                        if Assets.Vfx:FindFirstChild("cashCollect") then
                            local vfxTemplate = Assets.Vfx:FindFirstChild("cashCollect")
                            if vfxTemplate then
                                local vfxPart = vfxTemplate:Clone()
                                vfxPart.CFrame = mainPart.CFrame * CFrame.new(0, 1.5, 0)
                                vfxPart.Anchored = true
                                vfxPart.CanCollide = false
                                vfxPart.Transparency = 1
                                vfxPart.Parent = workspace
                                
                                local attachment = vfxPart:FindFirstChild("Attachment")
                                if attachment then
                                    for _, emitter in ipairs(attachment:GetChildren()) do
                                        if emitter:IsA("ParticleEmitter") then
                                            task.delay(0.05, function()
                                                emitter:Emit(emitter:GetAttribute("EmitCount") or 1) 
                                            end)
                                        end
                                    end
                                end
                                
                                if self.AudioService then
                                    self.AudioService:PlaySound("CashRegister") 
                                end
                                
                                Debris:AddItem(vfxPart, 2)
                            end
                        end
                        
                        claimed = true
                        break
                    end
                end
                
                if claimed then
                    task.wait(0.5)
                end
                debounce = false
            end)
        end)
    end
end

function PlotClass:SetupBaseUpgradeButton(upgradeNode)
    if not upgradeNode then return end

    local mainPart = upgradeNode:FindFirstChild("Main")
    if not mainPart then return end

    local buyGUI = mainPart:FindFirstChild("BuyGUI")
    local buttonList = buyGUI and buyGUI:FindFirstChild("ButtonList")

    local upgradeButton = buttonList and buttonList:FindFirstChild("Upgrade")
    local collectButton = buttonList and buttonList:FindFirstChild("Money")

    if self.Owner ~= LocalPlayer then
        if buyGUI then buyGUI.Enabled = false end
        return
    end

    self.CleanTrove:Add(self.ProfileService:Observe("BaseUpgrades", function(currentUpgrades)
        currentUpgrades = currentUpgrades or 0
        
        local cost = math.floor(5000000 * (math.pow(1.5, currentUpgrades)))
        local moneyText = upgradeButton:FindFirstChild("Cost",true)
        local StatusText = upgradeButton:FindFirstChild("Status",true)

        if moneyText and StatusText then
            if FormatNumber then
                moneyText.Text = "$" .. FormatNumber(cost, false)
            else
                moneyText.Text = "$" .. tostring(cost)
            end
            StatusText.Text = currentUpgrades.." > "..currentUpgrades+1
        end
    end, self.Owner))

    if collectButton then
        local animator = AnimationComponent.new(collectButton)
        self.CleanTrove:Add(animator)

        local debounce = false

        animator:Init(nil, function()
            if debounce then return end
            debounce = true

            task.wait(0.3)
            debounce = false
        end)
    end

    if upgradeButton and upgradeButton:IsA("GuiButton") then
        local animator = AnimationComponent.new(upgradeButton)
        self.CleanTrove:Add(animator)

        local debounce = false

        animator:Init(nil, function()
            if debounce then return end
            debounce = true

            self.ProfileService:Get("BaseUpgrades", self.Owner):andThen(function(currentUpgrades)
                currentUpgrades = currentUpgrades or 0
                local cost = math.floor(5000000 * (math.pow(1.5, currentUpgrades)))
                
                self.ProfileService:Get("Cash", self.Owner):andThen(function(cash)
                    if cash and cash >= cost then                        
                        Net.BuyBaseUpgrade.Fire()
                    end
                    
                    task.wait(0.3)
                    debounce = false
                end)
            end)
        end)
    else
        warn("Base Upgrade button is not a GuiButton (TextButton/ImageButton)! AnimationComponent requires a GuiButton.")
    end
end

function PlotClass:PlayUpgradeFovEffect()
    if not CurrentCamera then return end

    local originFov = CoreInstance.getOriginalProperty(CurrentCamera, "FieldOfView")
    local targetFov = 82

    local zoomIn = TweenService:Create(CurrentCamera, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = targetFov})
    zoomIn:Play()
    zoomIn.Completed:Connect(function()
        local resetCamera = CurrentCamera
        if not resetCamera then return end
        TweenService:Create(resetCamera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FieldOfView = originFov}):Play()
    end)
end

function PlotClass:PlayHologramEffect(plotIndex, brainrotName)
    local targetPlot = self.BrainrotPlots:FindFirstChild(tostring(plotIndex))
    if not targetPlot then return end
    
    local activeVisual = self.ActiveBrainrotVisuals[tostring(plotIndex)]
    local actualModel = activeVisual and activeVisual.Model
    
    local baseModel = self.BrainrotUtils:GetBrainrotModel(brainrotName)
    if not baseModel then return end
    
    local hologram = baseModel:Clone()
    hologram.Name = "UpgradeHologram"
    
    local hologramParts = {}
    for _, desc in ipairs(hologram:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Material = Enum.Material.ForceField
            desc.Color = Color3.fromRGB(255, 255, 255)
            desc.CanCollide = false
            desc.Anchored = true
            desc.CastShadow = false
            table.insert(hologramParts, desc)
        elseif desc:IsA("Texture") or desc:IsA("Decal") then
            desc.Transparency = 1 
        end
    end
    
    local baseCFrame = CoreInstance.getOriginalProperty(actualModel, "Pivot")
    local baseScale = CoreInstance.getOriginalProperty(actualModel, "Scale")
    
    if not actualModel then
        local showNode = targetPlot:FindFirstChild("Main") or targetPlot
        local yOffset = showNode.Size.Y / 2
        baseCFrame = showNode:GetPivot() * CFrame.new(0, yOffset + (hologram:GetExtentsSize().Y / 2), 0)
    end
    
    hologram:PivotTo(baseCFrame)
    hologram.Parent = targetPlot
    hologram:ScaleTo(baseScale)
    
    local duration = 0.7 
    local maxModelScale = baseScale * 1.4 
    local maxHoloScale = baseScale * 1.5
    
    local animationTween = TweenComponent.new(duration, function(alpha)
        if hologram and hologram.Parent then
            local holoAlpha = 1 - (1 - alpha) * (1 - alpha) 
            local currentHoloScale = baseScale + (maxHoloScale - baseScale) * holoAlpha
            hologram:ScaleTo(math.max(0.001, currentHoloScale))
            
            for _, part in ipairs(hologramParts) do
                part.Transparency = alpha
            end
        end
        
        if actualModel and actualModel.Parent then
            local arcPos = math.sin(alpha * math.pi) 
            
            local currentScale = baseScale + (maxModelScale - baseScale) * arcPos
            local heightOffset = arcPos * 3
            
            local rotation = alpha * math.rad(360) 
            
            local newCFrame = baseCFrame * CFrame.new(0, heightOffset, 0) * CFrame.Angles(0, rotation, 0)
            actualModel:PivotTo(newCFrame)
            actualModel:ScaleTo(math.max(0.001, currentScale))
        end
    end)
    
    animationTween.Completed:Connect(function()
        if hologram then hologram:Destroy() end
        
        if actualModel and actualModel.Parent then
            actualModel:PivotTo(baseCFrame)
            actualModel:ScaleTo(baseScale)
        end
        
        animationTween:Destroy()
    end)
    
    animationTween:Play()
end

function PlotClass:SetupUpgradeButton(upgradeNode, plotIndex)
    if not upgradeNode then return end

    local gui = upgradeNode:FindFirstChild("Gui")
    local upgradeButton = gui and gui:FindFirstChild("Upgrade") 
    local costText = upgradeButton and upgradeButton:FindFirstChild("Cost")
    local levelText = upgradeButton and upgradeButton:FindFirstChild("Level")

    self.CleanTrove:Add(self.ProfileService:Observe("Brainrots", function(brainrotsData)
        local assignedData = nil
        
        if brainrotsData then
            for _, bData in ipairs(brainrotsData) do
                if bData.AssignedPlot == plotIndex then
                    assignedData = bData
                    break
                end
            end
        end

        if assignedData then
            if upgradeButton then upgradeButton.Visible = true end
            
            local level = assignedData.Level or 0
            local props = self.BrainrotUtils:GetBrainrotProperties(assignedData.Name)
            local baseCost = props and props.BaseUpgradeCost or 100
            local cost = self.BrainrotUtils:CalculateUpgradeCost(baseCost, level)

            if costText then costText.Text = "$" .. FormatNumber(cost, false) end
            if levelText then levelText.Text = `Level <font color="rgb(255,0,0)">{tonumber(level)}</font> > Level <font color="rgb(0,255,0)">{tonumber(level+1)}</font>` end
        else
            if upgradeButton then upgradeButton.Visible = false end
        end
    end, self.Owner))

    if self.Owner == LocalPlayer and upgradeButton and upgradeButton:IsA("GuiButton") then
        local animator = AnimationComponent.new(upgradeButton)
        self.CleanTrove:Add(animator)

        local debounce = false

        animator:Init(nil, function()
            if debounce then return end
            debounce = true

            self.ProfileService:Get("Brainrots", self.Owner):andThen(function(brainrotsData)
                if not brainrotsData then 
                    debounce = false
                    return  
                end
                
                local targetID = nil
                local targetName = nil
                local currentLevel = 0
                local baseCost = 100

                for _, bData in ipairs(brainrotsData) do
                    if bData.AssignedPlot == plotIndex then
                        targetID = bData.ID
                        targetName = bData.Name
                        currentLevel = bData.Level or 0
                        
                        local props = self.BrainrotUtils:GetBrainrotProperties(bData.Name)
                        if props then baseCost = props.BaseUpgradeCost or 100 end
                        
                        break
                    end
                end

                if targetID then
                    local cost = self.BrainrotUtils:CalculateUpgradeCost(baseCost, currentLevel)
                    
                    self.ProfileService:Get("Cash", self.Owner):andThen(function(cash)
                        if cash and cash >= cost then
                            local rets = Net.UpgradeBrainrot.Call(targetID)
                            if rets and rets == "Success" then
                                self.AudioService:PlaySound("UpgradeEffect")
                                self.BrainrotUtils:EmitParticles("71244958170505",{
                                    Sound = nil,
                                    CorrectionColor = Color3.fromRGB(170, 156, 30)
                                })
                                self:PlayUpgradeFovEffect()
                                self:PlayHologramEffect(plotIndex, targetName)

                                if Assets.Vfx:FindFirstChild("Upgrade") then
                                    local vfxTemplate = Assets.Vfx:FindFirstChild("Upgrade") 
                                    if vfxTemplate then
                                        local vfxPart = vfxTemplate:Clone()
                                        vfxPart.CFrame = upgradeNode:GetPivot() * CFrame.new(0, 1.5, 0)
                                        vfxPart.Anchored = true
                                        vfxPart.CanCollide = false
                                        vfxPart.Transparency = 1
                                        vfxPart.Parent = workspace
                                        
                                        local attachment = vfxPart:FindFirstChildWhichIsA("Attachment")
                                        if attachment then
                                            for _, emitter in ipairs(attachment:GetChildren()) do
                                                if emitter:IsA("ParticleEmitter") then
                                                    task.delay(0.05, function()
                                                        emitter:Emit(emitter:GetAttribute("EmitCount") or 15) 
                                                    end)
                                                end
                                            end
                                        end
                                        
                                        Debris:AddItem(vfxPart, 2)
                                    end
                                end
                                
                            else
                                self.NotificationService:SendNotification({
                                    Text = rets,
                                    TextColor = Color3.fromRGB(255,0,0)
                                })
                            end
                        else
                            self.NotificationService:SendNotification({
                                Text = "Not enough cash",
                                TextColor = Color3.fromRGB(255,0,0)
                            })
                        end
                        
                        task.wait(0.3)
                        debounce = false
                    end)
                else
                    debounce = false
                end
            end)
        end)
    end
end

function PlotClass:PlayClaimRotationEffect(plotIndex)
    local activeVisual = self.ActiveBrainrotVisuals[tostring(plotIndex)]
    local actualModel = activeVisual and activeVisual.Model
    if not actualModel or not actualModel.Parent then return end

    local baseCFrame = CoreInstance.getOriginalProperty(actualModel, "Pivot")
    local duration = 0.5
    
    local spinTween = TweenComponent.new(duration, function(alpha)
        if actualModel and actualModel.Parent then
            local easeAlpha = 1 - (1 - alpha) * (1 - alpha)
            
            local rotation = easeAlpha * math.rad(360)
            
            actualModel:PivotTo(baseCFrame * CFrame.Angles(0, rotation, 0))
        end
    end)
    
    spinTween.Completed:Connect(function()
        if actualModel and actualModel.Parent then
            actualModel:PivotTo(baseCFrame)
        end
        spinTween:Destroy()
    end)
    
    spinTween:Play()
end

function PlotClass:UpdateBrainrotPlots()
    self.ProfileService:Get("Brainrots", self.Owner):andThen(function(brainrotsData)
        brainrotsData = brainrotsData or {}
        local incomingPlots = {}

        for _, bData in ipairs(brainrotsData) do
            if bData.AssignedPlot and bData.AssignedPlot > 0 then
                incomingPlots[tostring(bData.AssignedPlot)] = bData
            end
        end

        for plotIndex, activeVisual in pairs(self.ActiveBrainrotVisuals) do
            local incoming = incomingPlots[plotIndex]
            if not incoming or incoming.ID ~= activeVisual.ID or incoming.Name ~= activeVisual.Name or incoming.Level ~= activeVisual.Level then
                if activeVisual.Model then activeVisual.Model:Destroy() end
                self.ActiveBrainrotVisuals[plotIndex] = nil
            end
        end

        local placedModelsFolder = self.PlotFolder:FindFirstChild("PlacedModels") or Instance.new("Folder", self.PlotFolder)
        placedModelsFolder.Name = "PlacedModels"

        for plotIndex, bData in pairs(incomingPlots) do
            local targetPlot = self.BrainrotPlots:FindFirstChild(plotIndex)
            if not targetPlot then continue end

            local activeVisual = self.ActiveBrainrotVisuals[plotIndex]

            if not activeVisual then
                local baseModel = self.BrainrotUtils:GetBrainrotModel(bData.Name)
                if baseModel then
                    local clone = baseModel:Clone()
                    clone.Name = bData.ID

                    local showNode = targetPlot.Model:FindFirstChild("Main") or targetPlot
                    local yOffset = showNode.Size.Y / 2

                    local BrainrotBBoxCF, BrainrotSize = clone:GetBoundingBox()
                    local pivotOffset = clone:GetPivot():ToObjectSpace(BrainrotBBoxCF)
                    local distanceToBottom = (BrainrotSize.Y / 2) - pivotOffset.Y

                    local targetCFrame = showNode.CFrame * CFrame.new(0, yOffset + distanceToBottom, 0)
                    clone:PivotTo(targetCFrame)
                    
                    local statsUI = Assets.Models:FindFirstChild("BrainrotStats")
                    local props = self.BrainrotUtils:GetBrainrotProperties(bData.Name)
                    if statsUI then
                        local uiClone = statsUI:Clone()
                        uiClone.Adornee = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
                        uiClone.Parent = clone

                        local timerFrame = uiClone:FindFirstChild("TimerFrame", true)
                        if timerFrame then timerFrame.Visible = false end
                        local cash = self.BrainrotUtils:GetBrainrotMPS(bData)

                        setBillboardText(uiClone, "BrainrotName", props and props.Name or bData.Name)
                        setBillboardText(uiClone, "Earning", "$" .. FormatNumber(cash or props.CashPS or 0) .. "/s")
                        local text = setBillboardText(uiClone, "Rarity", props and props.Rarity or "Common")
                        if text then
                            local gradient = text:FindFirstChildWhichIsA("UIGradient")
                            if gradient then
                                gradient.Color = RarityColors[props.Rarity]
                            end
                        end
                        setBillboardText(uiClone, "Tier", "Level " .. tostring(bData.Level or 0))
                    end

                    clone.Parent = placedModelsFolder

                    self.ActiveBrainrotVisuals[plotIndex] = {
                        ID = bData.ID,
                        Name = bData.Name,
                        Level = bData.Level,
                        Model = clone
                    }
                else
                    warn("Brainrot Model not found for: " .. tostring(bData.Name))
                end
            end
        end
        
        self:RefreshPrompts()
    end)
end

function PlotClass:RefreshPrompts()
    if self.Owner ~= LocalPlayer then return end

    self.ProfileService:Get("Brainrots", self.Owner):andThen(function(brainrotsData)
        brainrotsData = brainrotsData or {}

        local occupiedPlots = {}
        local equippedData = nil
        local equippedIsAssigned = false

        for _, bData in ipairs(brainrotsData) do
            if bData.AssignedPlot and bData.AssignedPlot > 0 then
                occupiedPlots[tostring(bData.AssignedPlot)] = bData
            end
            if self.CurrentlyEquippedBrainrotID and bData.ID == self.CurrentlyEquippedBrainrotID then
                equippedData = bData
                equippedIsAssigned = (bData.AssignedPlot and bData.AssignedPlot > 0)
            end
        end

        for _, plotObj in pairs(self.BrainrotPlots:GetChildren()) do
            local plotIndexStr = plotObj.Name
            local occupant = occupiedPlots[plotIndexStr]
            
            local desiredType = "None"
            local desiredID = nil
            local desiredName = nil
            local promptRoot = nil
            
            if occupant then
                desiredType = "Unassign"
                desiredID = occupant.ID
                desiredName = occupant.Name or "Brainrot"
                
                local showNode = plotObj:FindFirstChild("BrainrotShow") or plotObj
                promptRoot = showNode:GetPivot().Position + Vector3.new(0, 4, 0)
                
            elseif self.CurrentlyEquippedBrainrotID and not equippedIsAssigned then
                desiredType = "Assign"
                desiredID = self.CurrentlyEquippedBrainrotID
                desiredName = equippedData and equippedData.Name or "Brainrot"
                
                local showNode = plotObj:FindFirstChild("BrainrotShow") or plotObj
                promptRoot = showNode:GetPivot().Position + Vector3.new(0, 5, 0)
            end

            local currentPromptData = self._prompts[plotIndexStr]
            local needsUpdate = false
            
            if not currentPromptData then
                if desiredType ~= "None" then needsUpdate = true end
            else
                if currentPromptData.Type ~= desiredType or currentPromptData.ID ~= desiredID then
                    needsUpdate = true
                end
            end
            
            if needsUpdate then
                if currentPromptData then
                    if typeof(currentPromptData.Prompt.Destroy) == "function" then
                        currentPromptData.Prompt:Destroy()
                    end
                    self._prompts[plotIndexStr] = nil
                end
                
                if desiredType ~= "None" then
                    local isAssign = (desiredType == "Assign")
                    local actionText = (isAssign and "Assign " or "Unassign ") .. desiredName
                    
                    local prompt = ProximityComponent.new({
                        Root = promptRoot,
                        Target = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart,
                        Range = 15,
                        KeyCode = Enum.KeyCode.E,
                        ActionText = actionText,
                        HoldDuration = 0.5
                    })

                    prompt.Triggered:Connect(function()
                        if self._prompts[plotIndexStr] then
                            self._prompts[plotIndexStr].Prompt:Destroy()
                            self._prompts[plotIndexStr] = nil
                        end
                        
                        if isAssign then 
                            Net.AssignBrainrot.Fire({ID = desiredID, plotNumber = tonumber(plotIndexStr)})
                        else 
                            Net.UnassignBrainrot.Fire({ID = desiredID}) 
                        end
                    end)

                    prompt:Start()
                    self._prompts[plotIndexStr] = { Prompt = prompt, Type = desiredType, ID = desiredID }
                end
            end
        end
    end)
end

function PlotClass:Destroy()
    for _, promptData in pairs(self._prompts) do
        if typeof(promptData.Prompt.Destroy) == "function" then
            promptData.Prompt:Destroy()
        end
    end
    table.clear(self._prompts)

    for _, visual in pairs(self.ActiveBrainrotVisuals) do
        if visual.Model then visual.Model:Destroy() end
    end
    table.clear(self.ActiveBrainrotVisuals)

    self.CleanTrove:Destroy()
    setmetatable(self, nil)
end

return PlotClass