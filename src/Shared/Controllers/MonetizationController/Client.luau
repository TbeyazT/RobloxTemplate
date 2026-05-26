--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Framework = require("@Shared/Framework")
local Net = require("@Shared/Net")
local Config = require("@Modules/Core/MonetizationConfig")

local Promise = require("@Pckgs/Promise")
local Trove = require("@Pckgs/Trove")

local MonetizationController = {
    _root = nil :: any,
    _promptDebounces = {} :: { [string]: number },
    _infoCache = {} :: { [number]: any },
    CleanTrove = Trove.new()
}

function MonetizationController:Init()
    self.ProfileService = Framework.Get("ProfileController")
    self.AudioService = Framework.Get("AudioController")

    self.CleanTrove:Connect(MarketplaceService.PromptGamePassPurchaseFinished, function(player, passId, wasPurchased)
        if player == LocalPlayer and wasPurchased then
            self:OnPurchaseSuccess("Gamepass", passId)
        end
    end)

    self.CleanTrove:Connect(MarketplaceService.PromptProductPurchaseFinished, function(userId, productId, wasPurchased)
        if userId == LocalPlayer.UserId and wasPurchased then
            self:OnPurchaseSuccess("Product", productId)
        end
    end)
end

function MonetizationController:Start()
end

function MonetizationController:GetProductConfig(productName: string)
    return Config.Products[productName]
end

function MonetizationController:GetGamepassConfig(passName: string)
    return Config.Gamepasses[passName]
end

function MonetizationController:GetMarketplaceInfo(itemName: string, isGamepass: boolean)
    return Promise.new(function(resolve, reject)
        local configData = isGamepass and self:GetGamepassConfig(itemName) or self:GetProductConfig(itemName)
        print(configData)
        
        if not configData or not configData.ID then
            return reject("Item not found in MonetizationConfig: " .. tostring(itemName))
        end
        
        local targetId = configData.ID
        local infoType = isGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
        
        if self._infoCache[targetId] then
            return resolve(self._infoCache[targetId])
        end

        local success, result = pcall(function()
            return MarketplaceService:GetProductInfo(targetId, infoType)
        end)

        if success and result then
            self._infoCache[targetId] = result
            resolve(result)
        else
            reject("Failed to fetch product info from Roblox API for ID: " .. tostring(targetId))
        end
    end)
end

function MonetizationController:OnPurchaseSuccess(purchaseType: string, id: number)
    if self.AudioService and self.AudioService.PlaySound then
        -- self.AudioService:PlaySound("CashRegister")
    end
    
    if self.NotificationService and self.NotificationService.Notify then
        self.NotificationService:Notify({
            Text = "Purchase Successful! Thank you!",
            TextColor = Color3.fromRGB(46, 204, 113)
        })
    end
end

function MonetizationController:CanPrompt(itemName: string): boolean
    local now = os.clock()
    local lastPrompt = self._promptDebounces[itemName] or 0
    
    if now - lastPrompt < 1.5 then
        return false
    end
    
    self._promptDebounces[itemName] = now
    return true
end

function MonetizationController:PromptGamepass(passName: string)
    local passConfig = self:GetGamepassConfig(passName)
    if not passConfig then
        warn("Invalid Gamepass Name: " .. tostring(passName))
        return
    end

    if not self:CanPrompt(passName) then return end
    MarketplaceService:PromptGamePassPurchase(LocalPlayer, passConfig.ID)
end

function MonetizationController:PromptProduct(productName: string)
    local productConfig = self:GetProductConfig(productName)
    if not productConfig then
        warn("Invalid Product Name: " .. tostring(productName))
        return
    end

    if not self:CanPrompt(productName) then return end
    Net.PromptProduct.Fire(productName)
end

function MonetizationController:HasGamepassLocally(passName: string)
    return self.ProfileService:Get("OwnedGamepasses", LocalPlayer):andThen(function(ownedPasses)
        local passConfig = self:GetGamepassConfig(passName)
        if not passConfig then return false end
        
        if type(ownedPasses) ~= "table" then 
            return false 
        end
        
        return ownedPasses[tostring(passConfig.ID)] == true
    end)
end

function MonetizationController:Destroy()
    self.CleanTrove:Clean()
    table.clear(self._promptDebounces)
    table.clear(self._infoCache)
    setmetatable(self, nil)
end

return MonetizationController