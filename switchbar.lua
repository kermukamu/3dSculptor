-- Switchbar "class"
local Switchbar = {}
Switchbar.__index = Switchbar

function Switchbar.new(x, y, iconSize, host)
    local self = setmetatable({}, Switchbar)
    self.host = host

    local path = "icons/"
    local iconAxisMarker = love.graphics.newImage(path .. "flag_axis_marker.png")
    local iconDrawVertices = love.graphics.newImage(path .. "flag_draw_vertices.png")
    local iconDrawLines = love.graphics.newImage(path .. "flag_draw_lines.png")
    local iconDrawFaces = love.graphics.newImage(path .. "flag_draw_faces.png")

    self.modes = {
        ["axisMarker"] = {function() return self:getAxisMarker() end, iconAxisMarker, function() self:toggleAxisMarker() end},
        ["drawVertices"] = {function() return self:getDrawVertices() end, iconDrawVertices, function() self:toggleDrawVertices() end},
        ["drawLines"] = {function() return self:getDrawLines() end, iconDrawLines, function() self:toggleDrawLines() end},
        ["drawFaces"] = {function() return self:getDrawFaces() end, iconDrawFaces, function() self:toggleDrawFaces() end}
    }

    self.x = x
    self.y = y
    self.size = iconSize

    self.drawnIconPositions = {}

    -- Other
    self.timer = 0
    return self
end

function Switchbar:update(dt)
    self.timer = math.max(self.timer + dt, 0)
end

function Switchbar:draw()
    local i = 0
    self.drawnIconPositions = {}
    for k, v in pairs(self.modes) do
        local statusCall = v[1]
        if statusCall ~= nil then
            local status = statusCall()
            local icon = v[2]
            local x = self.x + self.size*(i)
            local y = self.y
            love.graphics.setColor(1,1,1,0) -- Transparent
            if status then 
                love.graphics.setColor(1,1,1,0.5) -- Translucent white
            end
            love.graphics.rectangle("fill", x, y, self.size, self.size)
            local iconScale = self.size/icon:getWidth()
            love.graphics.setColor(1,1,1,1) -- White
            love.graphics.draw(icon, x, y, 0, iconScale, iconScale)
            table.insert(self.drawnIconPositions, {x, y, k})
        end
        i = i + 1
    end
end

function Switchbar:mousePressed(mx, my, button)
    if button == 1 then
        self:toggleAt(mx, my)
    end
end

function Switchbar:toggleAt(mx, my)
    for _, xy in ipairs(self.drawnIconPositions) do
        local iconX = xy[1]
        local iconY = xy[2]
        if (iconX < mx and mx < (iconX + self.size)) and
            (iconY < my and my < (iconY + self.size)) then
            local call = self.modes[xy[3]][3]
            if call ~= nil then call() end
        end
    end
end

function Switchbar:isWithinSection(x, y)
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

function Switchbar:toggleAxisMarker()
    local previous = self:getAxisMarker()
    self.host:setDrawAxis(not previous)
end

function Switchbar:toggleDrawVertices()
    local previous = self:getDrawVertices()
    self.host:setDrawVertices(not previous)
end

function Switchbar:toggleDrawLines()
    local previous = self:getDrawLines()
    self.host:setDrawLines(not previous)
end

function Switchbar:toggleDrawFaces()
    local previous = self:getDrawFaces()
    self.host:setDrawFaces(not previous)
end

-- Getters

function Switchbar:getX()
    return self.x
end
function Switchbar:getY()
    return self.y
end
function Switchbar:getAxisMarker()
    return self.host:drawAxisMarkerIsOn()
end

function Switchbar:getDrawVertices()
    return self.host:drawVerticesIsOn()
end

function Switchbar:getDrawLines()
    return self.host:drawLinesIsOn()
end

function Switchbar:getDrawFaces()
    return self.host:drawFacesIsOn()
end

return {Switchbar = Switchbar}