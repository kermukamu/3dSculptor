-- ColorTool "class"
local ColorTool = {}
ColorTool.__index = ColorTool

function ColorTool.new(x, y, iconSize, host)
    local self = setmetatable({}, ColorTool)
    self.host = host

    self.x = x
    self.y = y
    self.size = iconSize

    local path = "icons/colortool.png"
    self.iconColorTool = love.graphics.newImage(path)
    self.iconImageData = love.image.newImageData(path)

    -- These get updated only when the tool is open
    self.lastClickX = nil
    self.lastClickY = nil

    self.isOpen = false
    self.openScale = 4
    self.selectedColor = {0.4, 0.4, 0.8, 0.6}

    -- Other
    self.timer = 0
    return self
end

function ColorTool:update(dt)
    self.timer = math.max(self.timer + dt, 0)

    if self.host:getActiveSection() ~= self then self.isOpen = false end
end

function ColorTool:draw()
    local x, y = self.x, self.y
    love.graphics.setColor(1,1,1,1) -- White
    local iconScale = self.size/self.iconColorTool:getWidth()
    if self.isOpen then 
        x = self:getOpenX()
        y = self:getOpenY()
        iconScale = self.openScale * iconScale
    end
    love.graphics.draw(self.iconColorTool, x, y, 0, iconScale, iconScale)
    if self.isOpen and (self.lastClickX ~= nil) and (self.lastClickY ~= nil) then
        local rad = self.size/16
        local cx, cy = self.lastClickX, self.lastClickY
        love.graphics.setColor(0,0,0,1) -- Black
        love.graphics.circle("line", cx, cy, rad)
    end
end

function ColorTool:mousePressed(mx, my, button)
    
    if button == 1 then
        if not self.isOpen then
            self:open()
        else
            imgData = self.iconImageData
            local scale = self.openScale * self.size/imgData:getWidth()
            local x, y = (mx-self:getOpenX())/scale, (my-self:getOpenY())/scale
            r, g, b, a = imgData:getPixel(x, y)
            self.selectedColor = {r, g, b, a}
            self.lastClickX = mx
            self.lastClickY = my
        end
    end
end

function ColorTool:isWithinSection(x, y)
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

function ColorTool:open()
    self.isOpen = true
end

-- Getters

function ColorTool:getX()
    return self.x
end

function ColorTool:getY()
    return self.y
end

function ColorTool:getOpenX()
    return self.x-self.size*(self.openScale-1)
end

function ColorTool:getOpenY()
    return self.y-self.size*(self.openScale-1)
end

function ColorTool:getOpenSize()
    return self.openScale * self.size
end

function ColorTool:getSelectedColor()
    return self.selectedColor
end

return {ColorTool = ColorTool}