local cslider = require("slider")
local Slider = cslider.Slider

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

    self.isOpen = false
    self.openScaleY = 3
    self.openScaleX = 4

    self.sliders = {}

    local sliderSize = self:getOpenSizeX() / 12
    local sliderY = self:getOpenY()+sliderSize

    -- Red slider
    local rSlX= self:getOpenX() + sliderSize
    local rTitle = "Red"
    local redSlider = Slider.new(rSlX, sliderY, sliderSize, rTitle, self)
    table.insert(self.sliders, redSlider)

    -- Green slider
    local gSlX = rSlX + (self:getOpenSizeX() / 4)
    local gTitle = "Green"
    local greenSlider = Slider.new(gSlX, sliderY, sliderSize, gTitle, self)
    table.insert(self.sliders, greenSlider)

    -- Blue slider
    local bSlX = gSlX + (self:getOpenSizeX() / 4)
    local bTitle = "Blue"
    local blueSlider = Slider.new(bSlX, sliderY, sliderSize, bTitle, self)
    table.insert(self.sliders, blueSlider)

    -- Opacity slider
    local oSlX = bSlX + (self:getOpenSizeX() / 4)
    local oTitle = "Opacity"
    local opacSlider = Slider.new(oSlX, sliderY, sliderSize, oTitle, self)
    table.insert(self.sliders, opacSlider)

    self.selectedColor = {0,0,0,0}
    self:setSelectedColor(0.4, 0.4, 0.8, 1)

    -- Other
    self.timer = 0
    return self
end

function ColorTool:update(dt)
    self.timer = math.max(self.timer + dt, 0)
    if self.host:getActiveSection() ~= self then self.isOpen = false end

    for i, s in ipairs(self.sliders) do
        s:update(dt)
        if love.mouse.isDown(1) then
            self.selectedColor[i] = s:getState()
        end
    end
end

function ColorTool:draw()
    local x, y = self.x, self.y
    love.graphics.setColor(1,1,1,1) -- White
    local iconScale = self.size/self.iconColorTool:getWidth()
    if self.isOpen then
        x, y = self:getOpenX(), self:getOpenY()
        local width, height = self:getOpenSizeX(), self:getOpenSizeY()
        love.graphics.setColor(0,0,0,1) -- Black
        love.graphics.rectangle("fill", x, y, width, height)
        love.graphics.setColor(1,1,1,1) -- White
        love.graphics.rectangle("line", x, y, width, height)
        local ac = self.selectedColor
        love.graphics.setColor(ac[1], ac[2], ac[3], ac[4])
        love.graphics.rectangle("fill", x+width/32, y+height-height*2/32, width*30/32, height/32)
        for _, s in ipairs(self.sliders) do
            s:draw()
        end
    else
        love.graphics.draw(self.iconColorTool, x, y, 0, iconScale, iconScale)
    end
end

function ColorTool:mousePressed(mx, my, button)
    if button == 1 then
        if not self.isOpen then
            self:open()
        else
            for i, s in ipairs(self.sliders) do
                s:mousePressed(mx, my, button)
            end
        end
    end
end

function ColorTool:mouseReleased(mx, my, button)
    if button == 1 and self.isOpen then
        for i, s in ipairs(self.sliders) do
            s:mouseReleased(mx, my, button)
        end
    end
end

function ColorTool:isWithinSection(x, y)
    local toolX, toolY, sizeX, sizeY = self.x, self.y, self.size, self.size
    if self.isOpen then
        toolX = self:getOpenX()
        toolY = self:getOpenY()
        sizeX = self:getOpenSizeX()
        sizeY = self:getOpenSizeY()
    end
    if (toolX < x and x < (toolX + sizeX)) and
        (toolY < y and y < (toolY + sizeY)) then
        return true
    end
    return false
end

function ColorTool:open()
    self.isOpen = true
end

function ColorTool:setSelectedColor(r, g, b, o)
    self.sliders[1]:setState(r)
    self.sliders[2]:setState(g)
    self.sliders[3]:setState(b)
    self.sliders[4]:setState(o)
    self.selectedColor = {r, g, b, o}
end

-- Getters

function ColorTool:isSetOpen()
    return self.isOpen
end

function ColorTool:getX()
    return self.x
end

function ColorTool:getY()
    return self.y
end

function ColorTool:getOpenX()
    return self.x-self.size*(self.openScaleX-1)
end

function ColorTool:getOpenY()
    return self.y-self.size*(self.openScaleY-1)
end

function ColorTool:getOpenSizeX()
    return self.openScaleX * self.size
end

function ColorTool:getOpenSizeY()
    return self.openScaleY * self.size
end

function ColorTool:getSelectedColor()
    return self.selectedColor
end

return {ColorTool = ColorTool}