local ProfileController = require("@Shared/Controllers/ProfileController/Client")
local StoryAdapter = require("../StoryAdapter")
local SpriteTest = require("../Classes/SpriteTest")

ProfileController:init()

return StoryAdapter.wrap(SpriteTest)