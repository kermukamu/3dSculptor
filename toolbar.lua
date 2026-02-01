-- Toolbar "class"
local Toolbar = {}
Toolbar.__index = Toolbar

function Toolbar.new(x, y, iconSize, host)
    local self = setmetatable({}, Toolbar)
    self.host = host

    local path = "icons/"
    local iconSelection = love.graphics.newImage(path .. "selection.png")
    local iconMove = love.graphics.newImage(path .. "move.png")
    local iconVertex = love.graphics.newImage(path .. "vertex.png")

    self.modes = {
        ["selection"] = iconSelection,
        ["move selection"] = iconMove,
        ["vertex"] = iconVertex
    }

    self.x = x
    self.y = y
    self.size = iconSize

    -- Other
    self.timer = 0
    return self
end

function Toolbar:update(dt)
    self.timer = math.max(self.timer + dt, 0)
end

function Toolbar:draw()
    local i = 0
    for k, v in pairs(self.modes) do
        local x = self.x
        local y = self.y + self.size*(i)
        love.graphics.setColor(1,1,1,1) -- White
        if self.host:getToolMode() == k then love.graphics.setColor(0.5,0.5,0.5,1) end -- Gray
        love.graphics.rectangle("fill", x, y, self.size, self.size)
        love.graphics.setColor(0,0,0,1) -- Black
        love.graphics.rectangle("line", x, y, self.size, self.size)
        local iconScale = self.size/v:getWidth()
        love.graphics.draw(v, x, y, 0, self.iconScale, self.iconScale)
        i = i + 1
    end
end

function Toolbar:mousePressed(mx, my, button)
    if button == 1 then
        self:switchToModeWithin(mx, my)
    end
end

function Toolbar:switchToModeWithin(mx, my)
    local i = 0
    for k, v in pairs(self.modes) do
        local y = self.y + self.size*(i)
        local x = self.x
        if mx > x and x + self.size > mx and my > y and y + self.size > my then
            self.host:setToolMode(k)
            return nil
        end
        i = i + 1
    end
end

-- Getters

function Toolbar:getHeight()
    local h = 0
    for _ in pairs(self.modes) do
        h = h + self.size 
    end
    return h
end

function Toolbar:getWidth()
    return self.size
end

function Toolbar:getX()
    return self.x
end

function Toolbar:getY()
    return self.y
end

return {Toolbar = Toolbar}