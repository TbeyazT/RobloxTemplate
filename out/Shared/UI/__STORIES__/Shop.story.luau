local ProfileClient = require(script.Parent.Parent.Parent:FindFirstChild('Services'):FindFirstChild('ProfileService'):FindFirstChild('Client'))
local StoryAdapter  = require(script.Parent.Parent:FindFirstChild('StoryAdapter'))
local Shop          = require("@Shared/UI/Classes/Shop")

ProfileClient:init()
ProfileClient:Mock({})

return StoryAdapter.wrap(Shop)