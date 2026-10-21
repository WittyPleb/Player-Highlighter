
local Users = require("src/users")

-- Define
local Players = {}
local activePlayers = {}
local highlightsEnabled = true
local displayNamesEnabled = true

-- Helper to create a solid box based on aabb data
local function createBoundingBoxShape(aabb)
    local shape = ShapeData.new()

    shape.positions = {
        -- Bottom corners
        aabb:GetCorner(BoxCornerType.LEFT_BOTTOM_NEAR),   -- 2
        aabb:GetCorner(BoxCornerType.RIGHT_BOTTOM_NEAR),  -- 3
        aabb:GetCorner(BoxCornerType.RIGHT_BOTTOM_FAR),   -- 7
        aabb:GetCorner(BoxCornerType.LEFT_BOTTOM_FAR),    -- 6

        -- Top corners
        aabb:GetCorner(BoxCornerType.LEFT_TOP_NEAR),      -- 0
        aabb:GetCorner(BoxCornerType.RIGHT_TOP_NEAR),     -- 1
        aabb:GetCorner(BoxCornerType.RIGHT_TOP_FAR),      -- 5
        aabb:GetCorner(BoxCornerType.LEFT_TOP_FAR)        -- 4
    }

    -- Draw the 12 edges of the box
    shape.lines = {
        -- Bottom
        0, 1,
        1, 2,
        2, 3,
        3, 0,

        -- Top
        4, 5,
        5, 6,
        6, 7,
        7, 4,

        -- Vertical
        0, 4,
        1, 5,
        2, 6,
        3, 7
    }

    -- Fill all six faces (2 triangles per face)
    shape.tris = {
        -- Bottom
        0, 2, 1,
        0, 3, 2,

        -- Top
        4, 5, 6,
        4, 6, 7,

        -- Near
        0, 1, 5,
        0, 5, 4,

        -- Far
        3, 6, 2,
        3, 7, 6,

        -- Left
        0, 4, 7,
        0, 7, 3,

        -- Right
        1, 2, 6,
        1, 6, 5
    }

    return shape
end

-- Normalize usernames
local function normalizeUsername(username)
    if not username then return "" end

    return string.lower(tostring(username):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
end

-- Find saved user (player saved in Settings)
local function findSavedUser(username)
    local normalizedName = normalizeUsername(username)

    if normalizedName == "" then return nil end

    for _, user in ipairs(Users.GetAll()) do
        if user.username ~= "" and string.lower(user.username) == normalizedName then
            return user
        end
    end

    return nil
end

-- Destroy highlight (cleanup)
local function removeHighlight(name)
    local tracked = activePlayers[name]
    if not tracked then return end

    if tracked.instance then
        tracked.instance:Destroy()
    end

    if tracked.tooltip then
        tracked.tooltip:Destroy()
    end

    activePlayers[name] = nil
end

-- Helper to create a shape instance name 
local function createInstanceName(name)
    return "playerhighlighter:player_" .. name:gsub("[^%w_]", function(char) return string.format("_%02X", string.byte(char)) end)
end

-- Destroy the bounding box
local function destroyBoundingBox(tracked)
    if tracked.instance then
        tracked.instance:Destroy()
        tracked.instance = nil
    end
end

-- Destroy the tooltip
local function destroyTooltip(tracked)
    if tracked.tooltip then
        tracked.tooltip:Destroy()
        tracked.tooltip = nil
    end

    tracked.coordGrid = nil
end

-- Update the bounding box location and colour
local function updateBoundingBox(name, tracked, player, user)

    -- Destroy the bounding box if highlightsEnabled is false
    if not highlightsEnabled then
        destroyBoundingBox(tracked)
        return
    end

    -- Create a shape instance if one doesn't exist
    if not tracked.instance then
        tracked.instance = ShapeList.CreateInstance(createInstanceName(name))

        -- TODO: Possible settings the user can change
        tracked.instance.ignoreDepth = true
        tracked.instance.lineWidth = 1
    end

    -- Set shape data based on player aabb info
    tracked.instance:SetShapeData(createBoundingBoxShape(player.aabb))

    -- Fake a translation to make the box move with the player
    -- AABB already has world coordinates
    tracked.instance.translation = Vector3.new(0,0,0)

    -- Update colour
    tracked.instance.colour = user.colour

    -- TODO: Possible settings the user can change
    tracked.instance.lineWidth = 1
    tracked.instance.ignoreDepth = true
end

-- Update tooltip (username display)
local function updateTooltip(tracked, player)

    -- Destroy tooltip if they are disabled
    if not displayNamesEnabled then
        destroyTooltip(tracked)
        return
    end

    -- Destroy tooltip if the coordGrid doesn't match the player's coordGrid
    -- This allows it to be reconstructed so it can follow the player
    if tracked.tooltip and tracked.coordGrid ~= player.coordGrid then
        destroyTooltip(tracked)
    end

    -- Create a PrettyUI anchored tooltip above the player
    if not tracked.tooltip then
        tracked.tooltip = prettyui.AnchoredTooltip.forLoc(
            player.coordGrid,
            {
                text = player.displayName,
                heightAboveGround = 512 -- TODO: Potential user setting
            }
        )
    end

    -- Update the player's coordGrid
    tracked.coordGrid = player.coordGrid
end

-- EntityDraw event
function Players.OnEntityDraw(entityEvent)
    if not highlightsEnabled and not displayNamesEnabled then return true end -- Disable all
    if entityEvent.entityType ~= 2 then return true end -- playerEntities are 2

    -- Grab the playerEntity from event
    local player = entityEvent.playerEntity

    -- Confirm player is valid before continuing
    if not player or not player.isValid then
        return true
    end

    -- Check if player exists in settings
    local user = findSavedUser(player.displayName)

    -- Exit if no player is saved
    if not user then return true end

    -- Begin tracking
    local name = normalizeUsername(player.displayName)
    local tracked = activePlayers[name]

    if not tracked then
        tracked = {
            entity = player,
            instance = nil,
            tooltip = nil,
            coordGrid = nil
        }

        activePlayers[name] = tracked
    else
        tracked.entity = player
    end

    -- Update tooltip position
    updateTooltip(tracked, player)

    -- EntityDraw always returns true
    return true
end

function Players.OnLogic(logicEvent)
    for name, tracked in pairs(activePlayers) do
        local player = tracked.entity
        local user = player and player.isValid and findSavedUser(player.displayName) or nil

        if not user then
            removeHighlight(name)
        else
            updateBoundingBox(name, tracked, player, user)
            updateTooltip(tracked, player)
        end
    end
end

-- Helper functions

function Players.SetHighlightsEnabled(enabled)
    highlightsEnabled = enabled == true
end

function Players.GetHighlightsEnabled()
    return highlightsEnabled
end

function Players.SetDisplayNamesEnabled(enabled)
    displayNamesEnabled = enabled == true
end

function Players.GetDisplayNamesEnabled()
    return displayNamesEnabled
end

function Players.Destroy()
    for name in pairs(activePlayers) do
        removeHighlight(name)
    end
end

function Players.Reset()
    -- Remove all existing boxes & tooltips
    Players.Destroy()

    -- Restore default
    highlightsEnabled = true
    displayNamesEnabled = true
end

return Players