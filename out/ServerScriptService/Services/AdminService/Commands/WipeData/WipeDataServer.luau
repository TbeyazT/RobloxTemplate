local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))

return function(context, player)
    local ProfileService = Framework.WaitFor("ProfileService")
    local success, err = pcall(function()
        ProfileService:WipeData(player)
    end)

    if success then
        return `Successfully wiped data for {player.Name}.`
    else
        return `Failed to wipe data for {player.Name}: {err}`
    end
end