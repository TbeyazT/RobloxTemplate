local ProfileController = require("@Shared/Controllers/ProfileController/Client")
local StoryAdapter = require("../StoryAdapter")
local Inventory = require("../Classes/Inventory")

ProfileController:init()

return StoryAdapter.wrap(Inventory)