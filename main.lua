
local Users = require("src/users")
local Settings = require("src/settings")
local Players = require("src/players")

-- Load saved usernames or initialize if none found
Users.Load()

-- Settings interface
Event.SettingsLayerReady.Subscribe("playerhighlighter:settings", Settings.OnLayerReady)

-- Entity Drawing
Event.EntityDraw.Subscribe("playerhighlighter:draw", Players.OnEntityDraw)

-- Logic
Event.Logic.Subscribe("playerhighlighter:logic", Players.OnLogic)

-- Plugin shutdown
function PluginShutdown()
    Event.SettingsLayerReady.Unsubscribe("playerhighlighter:settings")
    Event.EntityDraw.Unsubscribe("playerhighlighter:draw")
    Event.Logic.Unsubscribe("playerhighlighter:logic")

    Settings.SaveUsers()
    Users.Save()

    Settings.Destroy()
    Players.Destroy()
end
