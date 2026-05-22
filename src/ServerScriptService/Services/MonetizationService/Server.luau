local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Framework = require("@Shared/Framework")
local Net = require("@SSS/Net")

local Config = require("@Modules/Core/MonetizationConfig")

local MonetizationService = {}

function MonetizationService:Init()
    self.ProfileService = Framework.Get("ProfileService")

    self.ProductLookup = {}
    for name, data in pairs(Config.Products) do
        self.ProductLookup[data.ID] = data
    end

    self.GamepassLookup = {}
    for name, data in pairs(Config.Gamepasses) do
        self.GamepassLookup[data.ID] = data
    end

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return self:ProcessReceipt(receiptInfo)
    end

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if wasPurchased then
            self:GrantGamepass(player, passId)
        end
    end)

    self.ProfileService:ObservePlayerAdded(function(player)
        self:CheckGamepasses(player)
    end)

    Net.PromptProduct.SetCallback(function(Player: Player, productName: string)
        local productConfig = Config.Products[productName]
        if productConfig then
            MarketplaceService:PromptProductPurchase(Player, productConfig.ID)
        else
            warn(Player.Name .. " requested invalid Product: " .. tostring(productName))
        end
    end)
end

function MonetizationService:CheckGamepasses(player: Player)
    local ownedPasses = self.ProfileService:Get(player, "OwnedGamepasses") or {}
    local dataChanged = false

    for passName, passData in pairs(Config.Gamepasses) do
        local passId = passData.ID
        
        if not ownedPasses[tostring(passId)] then
            local success, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
            end)

            if success and owns then
                if type(passData.OnUnlock) == "function" then
                    pcall(function() passData.OnUnlock(player, self.ProfileService) end)
                end
                ownedPasses[tostring(passId)] = true
                dataChanged = true
                print(player.Name .. " unlocked gamepass: " .. passName)
            end
        end
    end

    if dataChanged then
        self.ProfileService:Set(player, "OwnedGamepasses", ownedPasses)
    end
end

function MonetizationService:GrantGamepass(player: Player, passId: number)
    local ownedPasses = self.ProfileService:Get(player, "OwnedGamepasses")
    if not ownedPasses then return end

    if not ownedPasses[tostring(passId)] then
        local passData = self.GamepassLookup[passId]
        
        if passData and type(passData.OnUnlock) == "function" then
            pcall(function() passData.OnUnlock(player, self.ProfileService) end)
        end

        ownedPasses[tostring(passId)] = true
        self.ProfileService:Set(player, "OwnedGamepasses", ownedPasses)
        print("Granted Gamepass " .. tostring(passId) .. " to " .. player.Name)
    end
end

function MonetizationService:HasGamepass(player: Player, passName: string): boolean
    local passConfig = Config.Gamepasses[passName]
    if not passConfig then return false end

    local ownedPasses = self.ProfileService:Get(player, "OwnedGamepasses")
    if not ownedPasses then return false end

    return ownedPasses[tostring(passConfig.ID)] == true
end

function MonetizationService:ProcessReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player or not self.ProfileService:IsLoaded(player) then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productData = self.ProductLookup[receiptInfo.ProductId]
    if not productData then
        warn("Unknown Product ID purchased: " .. tostring(receiptInfo.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    if type(productData.OnPurchase) == "function" then
        local success, err = pcall(function()
            productData.OnPurchase(player, self.ProfileService)
        end)
        
        if not success then
            warn("Error processing product " .. tostring(receiptInfo.ProductId) .. ": " .. tostring(err))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    else
        warn("Product " .. tostring(receiptInfo.ProductId) .. " is missing an OnPurchase function!")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    print("Successfully processed product " .. tostring(receiptInfo.ProductId) .. " for " .. player.Name)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService