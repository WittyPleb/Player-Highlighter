local Users = require("src/users")
local Players = require("src/players")

local Settings = {}

local settingsView
local settingsView

-- Cleanup user controls
local function destroyUserControls(user)
    if user.controls.textField then
        user.controls.textField:Destroy()
    end

    if user.controls.colourPicker then
        user.controls.colourPicker:Destroy()
    end

    if user.controls.deleteButton then
        user.controls.deleteButton:Destroy()
    end

    user.controls = {}
end

-- Remove user from tracking
local function removeUser(id)
    for _, user in ipairs(Users.GetAll()) do
        if user.id == id then
            if Users.Remove(id) then
                destroyUserControls(user)
            end
            return
        end
    end
end

-- Create a new user row in UI
local function addUserRow(parent, user)
    user.controls.textField = parent:AddTextField({
        text = user.username,
        placeholder = "Username",
        width = 250,
        columnGap = 10,

        onChange = function(field, reason, content)
            if content ~= nil then
                user.username = content
            end
        end,

        onSubmit = function(field, content)
            if content ~= nil then
                user.username = content

                Users.Save()
            end
        end
    })

    user.controls.colourPicker = parent:AddColourPicker({
        value = user.colour,
        inline = true,
        alphaSlider = true,
        offsetY = 3,

        onChange = function(picker, colour)
            if type(colour) == "number" then
                user.colour = colour
            end
        end
    })

    if user.canDelete then
        user.controls.deleteButton = parent:AddSpriteButton(
            "TRASH",
            function(button, active)
                removeUser(user.id)
            end,
            {
                inline = true,
                tooltip = "Delete Highlight"
            }
        )
    end
end

-- Helper function to create a user for tracking
local function addUser(button, active)
    local user = Users.Create()
    addUserRow(settingsView, user)
end

-- Save UI controls so they can be restored
function Settings.SaveUsers()
    for _, user in ipairs(Users.GetAll()) do
        local controls = user.controls

        if controls then
            if user.controls.textField then
                local username = user.controls.textField:GetText()

                if type(username) == "string" then
                    user.username = username
                end
            end

            if user.controls.colourPicker then
                local colour = user.controls.colourPicker:GetValue()

                if type(colour) == "number" then
                    user.colour = colour
                end
            end
        end
    end
end

-- The Settings magic
function Settings.OnLayerReady(event)
    local rootLayer = event.component

    if settingsView then
        Settings.SaveUsers()
        settingsView:Destroy()
        settingsView = nil
    end

    settingsView = prettyui.SimpleView.new(rootLayer, {
        width = rootLayer.width,
        height = rootLayer.height
    })

    local selectedValues = {}

    if Players.GetHighlightsEnabled() then
        table.insert(selectedValues, "showHighlights")
    end

    if Players.GetDisplayNamesEnabled() then
        table.insert(selectedValues, "showDisplayNames")
    end

    settingsView:AddTitle({ text = "Display Settings" })

    settingsView:AddCheckboxButton({
        {
            text = "Show Highlights",
            value = "showHighlights"
        },
        {
            text = "Show Display Names",
            value = "showDisplayNames"
        }
    }, {
        selectedValues = selectedValues,

        onChange = function(group, values, changedValue, selected)
            Players.SetHighlightsEnabled(group:IsSelected("showHighlights"))
            Players.SetDisplayNamesEnabled(group:IsSelected("showDisplayNames"))
        end
    })

    settingsView:AddFancyButton("Reset to Default", function(self, active)
        prettyui.Confirm.new(rootLayer, {
            body = "Are you sure you wish to reset all settings to default? This will clear your saved data as well.",
            confirmVariant = "negative",

            onConfirm = function()
                -- Reset to default
                Players.Reset()
                Users.Reset()
                -- Redraw settings
                Settings.OnLayerReady({ component = rootLayer })
            end
        }) end,
        { variant = "negative", tooltip = "Resets the plugin back to default." }
    )

    settingsView:AddTitle({ text = "Usernames" })
    settingsView:AddSimpleButton("+ Add User", addUser, { inline = true })

    Users.EnsureDefault() -- Ensure there is at least 1 user

    for _, user in ipairs(Users.GetAll()) do
        user.controls = {}
        addUserRow(settingsView, user)
    end
end

function Settings.Destroy()
    if settingsView then
        Settings.SaveUsers()
        settingsView:Destroy()
        settingsView = nil
    end

    settingsView = nil

    for _, user in ipairs(Users.GetAll()) do
        user.controls = {}
    end
end

return Settings