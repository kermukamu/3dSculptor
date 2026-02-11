-- Slider "class"
local Slider = {}
Slider.__index = Slider

function Slider.new(x, y, size, title, host)
    local self = setmetatable({}, Slider)
    self.host = host

    self.x = x
    self.y = y
    self.width = size
    self.length = size * 6
    self.tText = title
    self.sliderState = 100
    self.stateMin = 0
    self.stateMax = 100
    self.stateScale = self.stateMax - self.stateMin
    self.bText = string.format("%.1f", self.sliderState)

    self.handleLength = self.length/12
    self.handleWidth = self.handleLength * 4
    self.handleX = self.x - (self.handleWidth-self.width)/2
    self.handleY = self.y + self.length - self.sliderState - self.handleLength/2

    self.grabbed = false
    -- Other
    self.timer = 0
    return self
end

function Slider:update(dt)
    self.timer = math.max(self.timer + dt, 0)

    if self.grabbed == true then
        -- Update slider based on mouse y
        local _, my = love.mouse.getPosition()
        local normalized = ((self.y + self.length) - my) / self.length
        local scaled = self.stateScale * normalized
        self:updateState(scaled)
    end
    local handleYDiff = (self.sliderState / self.stateScale) * self.length
    self.handleY = self.y + self.length - handleYDiff - self.handleLength/2
end

function Slider:draw()
    local textLimit = self.width*3 -- pixels

    love.graphics.setColor(1,1,1,1) -- White

    -- Top text
    local tText = self.tText
    local tOffsetY = love.graphics.getFont():getHeight()/4
    local tTextX = self.x+self.width/2-textLimit/2
    local tTextY = self.y-love.graphics.getFont():getHeight()-tOffsetY
    love.graphics.printf(tText, tTextX, tTextY, textLimit, "center")

    -- Slider rectangle
    local recX, recY = self.x, self.y
    local recWidth, recHeight = self.width, self.length
    love.graphics.rectangle("line", recX, recY, recWidth, recHeight)

    -- Bottom text
    local bText = self.bText
    local bTextX, bTextY = tTextX, self.y+self.length+tOffsetY
    love.graphics.printf(bText, bTextX, bTextY, textLimit, "center")

    -- Handle
    local handleX, handleY = self.handleX, self.handleY
    local handleLength, handleWidth = self.handleLength, self.handleWidth
    love.graphics.rectangle("fill", handleX, handleY, handleWidth, handleLength)
end

function Slider:mousePressed(mx, my, button)
    if button == 1 and self:isWithinSlider(mx, my) then
        self.grabbed = true
    end
end

function Slider:mouseReleased(mx, my, button)
    if button == 1 then
        self.grabbed = false
    end
end

function Slider:updateState(value)
    self.sliderState = math.max(self.stateMin, math.min(self.stateMax, value))
    self.bText = string.format("%.1f", self.sliderState)
end

function Slider:isWithinSlider(x, y)
    if (self.x < x and x < self.x + self.width and
        self.y < y and y < self.y + self.length) or
        (self.handleX < x and x < self.handleX + self.handleWidth and
        self.handleY < y and y < self.handleY + self.handleLength) then
        return true
    else
        return false
    end
end

-- Getters

function Slider:getState() return self.sliderState/self.stateScale end
function Slider:setState(value) self:updateState(value*self.stateScale) end

return {Slider = Slider}