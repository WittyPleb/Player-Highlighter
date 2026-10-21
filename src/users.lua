
local Users = {}

local users = {}
local nextUserId = 1

local DEFAULT_COLOUR = 0xC86B17BF
local DATABASE_KEY = "playerhighlighter:users"

-- Create user table
function Users.Create(username, colour)
    local user = {
        id = nextUserId,
        username = username or "",
        colour = colour or DEFAULT_COLOUR,
        lineWidth = 1,
        controls = {},
        canDelete = nextUserId ~= 1
    }

    nextUserId = nextUserId + 1
    table.insert(users, user)

    return user
end

-- Remove user from table
function Users.Remove(id)
    if #users <= 1 then return false end

    for index, user in ipairs(users) do
        if user.id == id then
            if not user.canDelete then return false end

            table.remove(users, index)
            return true
        end
    end

    return false
end

-- Get all users in table
function Users.GetAll()
    return users
end

-- Ensure there is at least 1 user at all times
function Users.EnsureDefault()
    if #users == 0 then
        Users.Create()
    end
end

-- Load user table
function Users.Load()
    local savedUsers = PersistentDB:Get(DATABASE_KEY)

    users = {}
    nextUserId = 1

    if type(savedUsers) == "table" then
        for _, savedUser in ipairs(savedUsers) do
            if type(savedUser) == "table" then
                local colour = DEFAULT_COLOUR

                if type(savedUser.colour) == "string" then
                    colour = tonumber(savedUser.colour, 16) or DEFAULT_COLOUR -- fix in case colour save data gets wacky
                elseif type(savedUser.colour) == "number" then
                    colour = math.floor(savedUser.colour)
                end

                Users.Create(
                    savedUser.username,
                    colour
                )
            end
        end
    end

    Users.EnsureDefault()
end

-- Save user table
function Users.Save()
    local savedUsers = {}

    for _, user in ipairs(users) do
        local colour = user.colour

        if type(colour) == "string" then
            colour = tonumber(colour, 16)
        end

        if type(colour) ~= "number" then
            --print("[PlayerHighlighter] Invalid colour for: ", tostring(user.username), " - using default!")
            colour = DEFAULT_COLOUR
        end

        table.insert(savedUsers, {
            username = user.username,
            colour = string.format("%08X", math.floor(colour))
        })
    end

    PersistentDB:Set(DATABASE_KEY, savedUsers)
end

-- Print all users in table (unused)
function Users.PrintAll()
    for _, user in ipairs(users) do
        print(
            "User ID:", user.id,
            "Username:", tostring(user.username)
        )
    end
end

return Users