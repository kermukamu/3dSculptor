-- Panel2d "class"
local Panel2d = {}
Panel2d.__index = Panel2d

function Panel2d.new(x, y, w, h, axes, host)
    local self = setmetatable({}, Panel2d)
    self.host = host

    self.frameLineWidth = 5
    self.lineWidth = 1
    self.x = x + self.frameLineWidth
    self.y = y - self.frameLineWidth
    self.w = w - 2 * self.frameLineWidth
    self.h = h - 2 * self.frameLineWidth
    self.axes = axes

    self.clickRange = 5

    self.screen = {}

    -- Other
    self.timer = 0
    return self
end

function Panel2d:update(dt)
    self.timer = math.max(self.timer + dt, 0)
end

function Panel2d:draw()
    self:drawModel()
    self:drawAxisMarker()

    -- Frame
    local originalLW = love.graphics.getLineWidth()
    love.graphics.setColor(1,1,1,1) -- White
    love.graphics.setLineWidth(self.frameLineWidth)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    love.graphics.setLineWidth(originalLW)
end

function Panel2d:drawModel()
    local currentModel = self:getCurrentModel()
    if currentModel then
        local points = currentModel:getPoints()
        local selectedPoints = currentModel:getSelectedVertices()
        local lines = currentModel:getLines()
    
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(self.lineWidth)

        local xShift = self:getXShift()
        local yShift = self:getYShift()

        self.screen = {}

        -- Project, draw as rectangle if selected
        for i = 1, #points do
            local px, py, pz = points[i][1], points[i][2], points[i][3]

            local x, y = 0, 0
            if self.axes == "xz" or self.axes == "zx" then
                x, y = px, pz
            elseif self.axes == "xy" or self.axes == "yx" then
                x, y = px, py
            elseif self.axes == "yz" or self.axes == "zy" then
                x, y = py, pz
            else return end -- Axes are not defined
            xS = x + xShift
            yS = y + yShift
            table.insert(self.screen, {xS, yS})

            if selectedPoints[i] then
                local size = self.w/64
                love.graphics.setColor(0,1,0,1) -- Green
                love.graphics.rectangle("fill", xS-size/2, yS-size/2, size, size)
            end
        end
    
        -- Draw lines by connection indices
        local drawn = {}
        
        love.graphics.setColor(1,1,1,1) -- White
        love.graphics.setLineWidth(self.lineWidth)
        for i = 1, #lines do
            local a = {self.screen[i][1], self.screen[i][2]}
            local links = lines[i]
    
            if a and links then
                for _, k in ipairs(links) do
                    local b = {self.screen[k][1], self.screen[k][2]}
                    if b then
                        local key1 = i .. "-" .. k
                        local key2 = k .. "-" .. i
                        if not drawn[key1] and not drawn[key2] then
                            love.graphics.line(a[1], a[2], b[1], b[2])
                            drawn[key1] = true
                        end
                    end
                end
            end
        end
    end
end

function Panel2d:drawAxisMarker()
    love.graphics.setLineWidth(self.lineWidth)

    local xShift = self:getXShift()
    local yShift = self:getYShift()
    local x = self:getAxisMarkerX()
    local y = self:getAxisMarkerY()
    local size = self.w/32
    if self.axes == "xz" or self.axes == "zx" then
        love.graphics.setColor(1,0,0,1) -- Red
        love.graphics.line(0+x,0+y,size+x,0+y)
        love.graphics.setColor(0,0,1,1) -- Blue
        love.graphics.line(0+x,0+y,0+x,size+y)
    elseif self.axes == "xy" or self.axes == "yx" then
        love.graphics.setColor(1,0,0,1) -- Red
        love.graphics.line(0+x,0+y,size+x,0+y)
        love.graphics.setColor(0,1,0,1) -- Green
        love.graphics.line(0+x,0+y,0+x,size+y)
    elseif self.axes == "yz" or self.axes == "zy" then
        love.graphics.setColor(0,1,0,1) -- Green
        love.graphics.line(0+x,0+y,size+x,0+y)
        love.graphics.setColor(0,0,1,1) -- Blue
        love.graphics.line(0+x,0+y,0+x,size+y)
    else return end -- Axes are not defined
end

function Panel2d:keyPressed(key)
    local action = self.host:getModelerKeyActions()[key]
    if action then action[1]() end
end

function Panel2d:textInput(t)
end

function Panel2d:mousePressed(mx, my, button)
    if not love.keyboard.isDown("lshift") then self:deSelect() end
    if button == 1 then -- left click
        self:selectVerticesWithin(mx, my)
    end
end

function Panel2d:deSelect()
    local currentModel = self.host:getCurrentModel()
    if currentModel then 
        currentModel:deSelect()
    end
end

function Panel2d:selectVerticesWithin(mx, my)
    local currentModel = self.host:getCurrentModel()
    if currentModel then 
        for i=1, #self.screen, 1 do
            if self.screen[i] == nil then 
                -- Silly lua doesn't support continue...
            elseif self:isWithinCircle(mx, my, self.screen[i][1], self.screen[i][2], 
                self.clickRange) then
                currentModel:setVertexSelected(i)
            end
        end
    end
end

function Panel2d:isWithinCircle(px, py, cx, cy, r)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (r * r)
end

-- Getters and setters

function Panel2d:getCurrentModel()
    return self.host:getCurrentModel()
end

function Panel2d:drawAxisMarkerIsOn()
    return self.host:drawAxisMarkerIsOn()
end

function Panel2d:vertexNumberingIsOn()
    return self.host:vertexNumberingIsOn()
end

function Panel2d:vertexCoordsIsOn()
    return self.host:vertexCoordsIsOn()
end

function Panel2d:getXShift()
    return self.x+self.w/2
end

function Panel2d:getYShift()
    return self.y+self.h/2
end

function Panel2d:getAxisMarkerX()
    return self.x + self.w/8
end

function Panel2d:getAxisMarkerY()
    return self.y + self.h - self.h/8
end
return {Panel2d = Panel2d}