local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Easing = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Math'):FindFirstChild('Easing'))
local TweenComponent = require("@Shared/Components/TweenComponent")

local variantsBoosts = require("@Modules/Core/VariantBoosts")

local CurrentCamera = workspace.CurrentCamera
local CameraParticle = Assets.Models:FindFirstChild("CameraParticle")
local Utils = {
    AudioController = Framework.Get("AudioService"),
    ProfileService = Framework.Get("ProfileService"),
}

function Utils:GetBrainrotProperties(name)
    local module = Assets.BrainrotProperties:FindFirstChild(name)
    if module then
        return require(module)
    end 
    return nil
end

function Utils:GetBrainrotModel(name)
    local module = Assets.BrainrotProperties:FindFirstChild(name)
    if module then
        local model = module:FindFirstChildWhichIsA("Model")
        if model then
            return model
        end
        return nil
    end 
    return nil
end

function Utils:CalculateUpgradeCost(baseCost: number, currentLevel: number): number
    baseCost = baseCost or 5

    local growth = 1.5

    local cost = baseCost * (growth ^ (currentLevel - 1))

    return math.floor(cost + 0.5)
end

function Utils:GetBrainrotMPS(brainrotData)
    local props = self:GetBrainrotProperties(brainrotData.Name)
    if not props then return 0 end

    local baseMPS = props.CashPS or 0
    local level = brainrotData.Level or 0
    
    local levelMultiplier = 1.25
    
    local variantBoost = 1
    if brainrotData.Variants then
        for variantName, _ in pairs(brainrotData.Variants) do
            local vProps = variantsBoosts[variantName]
            if vProps and vProps.Cash then
                variantBoost = variantBoost * (1 + (vProps.Cash / 100))
            end
        end
    end

    local playerBoost = 1

    self.ProfileService:Get("Multipliers"):andThen(function(multipliers)
        if multipliers["Cash"] then
            playerBoost *= multipliers["Cash"]
        end
    end)
    print(playerBoost)
    
    local finalMPS = baseMPS * (levelMultiplier ^ level) * variantBoost * playerBoost
    print(finalMPS)
    return math.floor(finalMPS)
end

function Utils:EmitParticles(imageID,options)
    local particleCount = math.random(4, 5)

    if not CurrentCamera then return end

    if options and options.Sound then
        self.AudioController:PlaySound(options.Sound)
    end

    for i = 1, particleCount do
        local newPart = CameraParticle:Clone()

        newPart.Anchored = true 
        newPart.CanCollide = false
        newPart.CastShadow = false

        local surfaceGui = newPart:FindFirstChildWhichIsA("SurfaceGui")
        local winImage = surfaceGui and surfaceGui:FindFirstChildWhichIsA("ImageLabel")
        
        Lighting.ColorCorrection.TintColor = options and options.CorrectionColor or Color3.fromRGB(0, 255, 0)
        TweenService:Create(Lighting.ColorCorrection, TweenInfo.new(0.6), {TintColor = Color3.fromRGB(255, 255, 255)}):Play()

        if winImage and surfaceGui then
            if imageID then
                winImage.Image = "rbxassetid://" .. imageID
            end
            
            surfaceGui.AlwaysOnTop = true 

            newPart.Parent = CurrentCamera
            newPart.CFrame = CurrentCamera.CFrame

            local randomX = math.random(-25, 25) / 7 
            local randomY = math.random(-30, 30) / 10
            local randomZ = math.random(-70, -40) / 10

            local targetOffset = CFrame.new(randomX, randomY, randomZ)

            local randomRotation = CFrame.Angles(0, 0, math.rad(math.random(-15, 15)))

            local partTween = TweenComponent.new(1.2, function(alpha)
                local currentTarget = CurrentCamera.CFrame * targetOffset * randomRotation
                newPart.CFrame = CurrentCamera.CFrame:Lerp(currentTarget, alpha)
                winImage.ImageTransparency = alpha
            end, Easing.circOut)

            partTween:Play()
            partTween.Completed:Connect(function()
                newPart:Destroy()
                partTween:Destroy()
            end)
        else
            newPart:Destroy()
        end
    end
end

return Utils