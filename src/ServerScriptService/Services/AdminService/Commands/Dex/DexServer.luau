const ServerStorage = game:GetService("ServerStorage")

const DexServiceModule:ModuleScript = ServerStorage:FindFirstChild("dexTB")

const DexService = require(DexServiceModule)::any

if not DexService._initialized then
	DexService:Init()
end

return function(context, targetPlayer)
    if not DexServiceModule then
        return "Error: DexService module could not be found on the server."
    end
    
    if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
        DexService:GiveDex(targetPlayer)
        return "Gave Dex Explorer to " .. targetPlayer.Name .. "."
    elseif typeof(targetPlayer) == "table" then
        local names = {}
        for _, player in ipairs(targetPlayer) do
            if typeof(player) == "Instance" and player:IsA("Player") then
                DexService:GiveDex(player)
                table.insert(names, player.Name)
            end
        end
        return "Gave Dex Explorer to: " .. table.concat(names, ", ") .. "."
    end

    return "Failed to give Dex (Invalid target player)."
end