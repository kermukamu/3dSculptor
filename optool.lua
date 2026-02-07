-- Opacity tool "class"
local OpTool = {}
OpTool.__index = OpTool

function OpTool.new(x, y, iconSize, host)
    local self = setmetatable({}, OpTool)
    self.host = host

    self.x = x
    self.y = y
    self.size = iconSize

    local path = "icons/optool.png"
    self.iconOpTool = love.graphics.newImage(path)
    self.iconImageData = love.image.newImageData(path)

    -- These get updated only when the tool is open
    self.lastClickX = nil
    self.lastClickY = nil

    self.isOpen = false
    self.openScale = 4
    self.selectedOpacity = 0

    -- Other
    self.timer = 0
    return self
end

function OpTool:update(dt)
    self.timer = math.max(self.timer + dt, 0)
    if self.host:getActiveSection() ~= self then self.isOpen = false end
end

function OpTool:draw()
    local x, y = self.x, self.y
    local color = self.host:getActiveColor()
    local r, g, b = color[1], color[2], color[3]
    love.graphics.setColor(r,g,b,1)
    local iconScale = self.size/self.iconOpTool:getWidth()
    if self.isOpen then 
        x = self:getOpenX()
        y = self:getOpenY()
        iconScale = self.openScale * iconScale
    end
    love.graphics.draw(self.iconOpTool, x, y, 0, iconScale, iconScale)
    if self.isOpen and (self.lastClickX ~= nil) and (self.lastClickY ~= nil) then
        local rad = self.size/16
        local cx, cy = self.lastClickX, self.lastClickY
        love.graphics.setColor(1,1,1,1) -- White center
        love.graphics.circle("fill", cx, cy, rad)
        love.graphics.setColor(0,0,0,1) -- Black outline
        love.graphics.circle("line", cx, cy, rad)
    end
end

function OpTool:mousePressed(mx, my, button)
    
    if button == 1 then
        if not self.isOpen then
            self:open()
        else
            imgData = self.iconImageData
            local scale = self.openScale * self.size/imgData:getWidth()
            local x, y = (mx-self:getOpenX())/scale, (my-self:getOpenY())/scale
            _, _, _, a = imgData:getPixel(x, y)
            self.selectedOpacity = a
            self.lastClickX = mx
            self.lastClickY = my
        end
    end
end

function OpTool:isWithinSection(x, y)
    local iconX, iconY, size = self.x, self.y, self.size
    if self.isOpen then
        iconX = self:getOpenX()
        iconY = self:getOpenY()
        size = self:getOpenSize()
    end
    if (iconX < x and x < (iconX + size)) and
        (iconY < y and y < (iconY + size)) then
        return true
    end
    return false
end

function OpTool:open()
    self.isOpen = true
end

function OpTool:setX(x)
    self.x = x
end

-- Getters

function OpTool:getX()
    return self.x
end

function OpTool:getY()
    return self.y
end

function OpTool:getSize()
    return self.size
end

function OpTool:getOpenX()
    return self.x-self.size*(self.openScale-1)
end

function OpTool:getOpenY()
    return self.y-self.size*(self.openScale-1)
end

function OpTool:getOpenSize()
    return self.openScale * self.size
end

function OpTool:getSelectedOpacity()
    return self.selectedOpacity
end

return {OpTool = OpTool}