-- Toolbar "class"
local Toolbar = {}
Toolbar.__index = Toolbar

function Toolbar.new(x, y, iconSize, host)
    local self = setmetatable({}, Toolbar)
    self.host = host

    local path = "icons/"
    local iconSelection = love.graphics.newImage(path .. "selection.png")
    local iconMove = love.graphics.newImage(path .. "move.png")
    local iconRotate = love.graphics.newImage(path .. "rotate.png")
    local iconVertex = love.graphics.newImage(path .. "vertex.png")
    local iconCircle = love.graphics.newImage(path .. "circle.png")
    local iconSphere = love.graphics.newImage(path .. "sphere.png")
    local iconRectangle = love.graphics.newImage(path .. "rectangle.png")
    local iconCuboid = love.graphics.newImage(path .. "cube.png")
    local iconCameraMove = love.graphics.newImage(path .. "move_camera.png")
    local iconCameraRotate = love.graphics.newImage(path .. "rotate_camera.png")
    local iconExtrusionAlongLine = love.graphics.newImage(path .. "extrude.png")
    local iconExtrusionAroundPivot = love.graphics.newImage(path .. "extrude_around_pivot.png")

    self.modes = {
        ["selection"] = {{"rectangle", iconSelection}},
        ["move selected"] = {{"translate", iconMove}, {"rotate", iconRotate}},
        ["vertex"] = {{"single", iconVertex}, {"circle", iconCircle}, {"sphere", iconSphere}, {"rectangle", iconRectangle}, {"cuboid", iconCuboid}},
        ["move camera"] = {{"translate", iconCameraMove}, {"rotate", iconCameraRotate}},
        ["extrude selected"] = {{"along line", iconExtrusionAlongLine}, {"around pivot", iconExtrusionAroundPivot}}
    }

    self.x = x
    self.y = y
    self.drawnIconPositions = {} -- In format {{x1, y1, {mode, subMode}, {x2, y2, {mode, subMode}}...}
    self.size = iconSize

    -- Other
    self.timer = 0
    return self
end

function Toolbar:update(dt)
    self.timer = math.max(self.timer + dt, 0)
end

function Toolbar:draw()
    self.drawnIconPositions = {}
    local i = 0
    local currentToolMode = self.host:getToolMode()
    local currentSubMode = self.host:getSubToolMode()
    for k, v in pairs(self.modes) do
        local y = self.y + self.size*(i)
        local x = self.x
        if k == currentToolMode and self.host:getActiveSection() == self then -- If selected draw all sub icons next to each other
            for j = 1, #v, 1 do
                local subMode = v[j][1]
                local subIcon = v[j][2]
                x = self.x - (j-1)*self.size
                love.graphics.setColor(1,1,1,1) -- White
                if subMode == currentSubMode then love.graphics.setColor(0.5,0.5,0.5,1) end -- Gray
                love.graphics.rectangle("fill", x, y, self.size, self.size)
                local iconScale = self.size/subIcon:getWidth()
                love.graphics.draw(subIcon, x, y, 0, iconScale, iconScale)
                table.insert(self.drawnIconPositions, {x, y, k, v[j][1]})
            end
        else
            local toolIcon = v[1][2] -- Choose first from sub icons
            love.graphics.setColor(1,1,1,1) -- White
            if k == currentToolMode then 
                love.graphics.setColor(0.5,0.5,0.5,1) -- Gray
                toolIcon = self:getSubModeIcon(currentToolMode, currentSubMode)
            end
            love.graphics.rectangle("fill", x, y, self.size, self.size)
            local iconScale = self.size/toolIcon:getWidth()
            love.graphics.draw(toolIcon, x, y, 0, iconScale, iconScale)
            table.insert(self.drawnIconPositions, {x, y, k, v[1][1]})
        end
        i = i + 1
    end
end

function Toolbar:mousePressed(mx, my, button)
    if button == 1 then
        self:switchToModeWithin(mx, my)
    end
end

function Toolbar:getSubModeIcon(tool, sub)
    for _, a in ipairs(self.modes[tool]) do
        if a[1] == sub then return a[2] end
    end
end

function Toolbar:switchToModeWithin(mx, my)
    for _, xy in ipairs(self.drawnIconPositions) do
        local iconX = xy[1]
        local iconY = xy[2]
        if (iconX < mx and mx < (iconX + self.size)) and
            (iconY < my and my < (iconY + self.size)) then
            self.host:setToolMode(xy[3])
            self.host:setSubToolMode(xy[4])
        end
    end
end

function Toolbar:isWithinSection(x, y)
    for _, xy in ipairs(self.drawnIconPositions) do
        local iconX = xy[1]
        local iconY = xy[2]
        if (iconX < x and x < (iconX + self.size)) and
            (iconY < y and y < (iconY + self.size)) then
            return true
        end
    end
    return false
end

function Toolbar:next(tool, sub)
    for i=1, #self.modes[tool]-1, 1 do
        if self.modes[tool][i][1] == sub then 
            return self.modes[tool][i+1][1]
        end
    end
    return self.modes[tool][1][1]
end

-- Getters

function Toolbar:getX()
    return self.x
end

function Toolbar:getY()
    return self.y
end

return {Toolbar = Toolbar}