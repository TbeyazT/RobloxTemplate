return {
    Gamepasses = {
        --[[
        VIP = { 
            ID = 1234567,
            OnUnlock = function(player, ProfileService)
                -- One-time reward for getting VIP
                ProfileService:Increment(player, "Cash", 50000)
                print(player.Name .. " received their VIP sign-on bonus!")
            end
        },
        ]]
    },
    
    Products = {
        --[[
        ["Cash"] = {
            ID = 3594058904,
            OnPurchase = function(player, ProfileService)
                stuff
            end
        }
        ]]
    }
}