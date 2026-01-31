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
    self.allModelWithinView = true
    self.toolMode = self.host:getToolMode()
    self.currentModel = self:getCurrentModel()
    self.prevClickX = 0
    self.prevClickY = 0

    self.panSpeed = 100
    self.dx = 0
    self.dy = 0
    self.viewScale = 1
    self.clickRange = 5
    self.screen = {}
    self.gridXRes = 8
    self.gridYRes = 8

    -- Other
    self.timer = 0
    return self
end

function Panel2d:update(dt)
    self.timer = math.max(self.timer + dt, 0)
    self.viewScale = math.max(self.viewScale, 0)
    self.toolMode = self.host:getToolMode()
    self.currentModel = self:getCurrentModel()

    if self.host:getActiveSection() == self then self:handleArrowInput(dt) end
end

function Panel2d:draw()
    --Black background
    love.graphics.setColor(0,0,0,1) -- Black
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    love.graphics.setScissor(self.x, self.y, self.w, self.h) -- Limit drawing area
    self:drawGrid()
    self:drawModel()
    self:drawAxisMarker()

    -- Selection rectangle
    if self.host:getActiveSection() == self and self.toolMode == "selection" 
        and love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        local w, h = mx-self.prevClickX, my-self.prevClickY
        love.graphics.setColor(0,1,0,0.3) -- Translucent green
        love.graphics.rectangle("fill", self.prevClickX, self.prevClickY, w, h)
    end

    -- Circle drawing indicator
    local lShiftIsDown = love.keyboard.isDown("lshift")
    local lCtrlIsDown = love.keyboard.isDown("lctrl")
    if self.host:getActiveSection() == self and self.toolMode == "vertex" 
        and (lShiftIsDown or lCtrlIsDown) and love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        local dx, dy = mx-self.prevClickX, my-self.prevClickY
        local r = math.sqrt(dx*dx + dy*dy)
        love.graphics.setColor(0,1,1,0.3) --Translucent cyan
        if lShiftIsDown then love.graphics.circle("line", self.prevClickX, self.prevClickY, r)
        else love.graphics.circle("fill", self.prevClickX, self.prevClickY, r) end
    end

    if not self.allModelWithinView then self:drawHiddenVerticesComplaint() end

    love.graphics.setScissor() -- Remove drawing area limit

    -- White Frame
    local originalLW = love.graphics.getLineWidth()
    love.graphics.setColor(1,1,1,1) -- White
    love.graphics.setLineWidth(self.frameLineWidth)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    love.graphics.setLineWidth(originalLW)
end

function Panel2d:drawGrid()
    love.graphics.setColor(0.2, 0.2, 0.2, 1) -- Gray
    local y = self.y
    local yMax = self.y+self.h
    local x = self.x
    local xMax = self.x + self.w

    local yInc = self.h/self.gridYRes
    for yLine=self.y, self.y+self.h, yInc do
        love.graphics.line(x, yLine, xMax, yLine)
    end

    local xInc = self.w/self.gridXRes
    for xLine=self.x, self.x+self.w, xInc do
        love.graphics.line(xLine, y, xLine, yMax)
    end
end

function Panel2d:drawModel()
    if self.currentModel then
        local points = self.currentModel:getPoints()
        local selectedPoints = self.currentModel:getSelectedVertices()
        local lines = self.currentModel:getLines()
    
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(self.lineWidth)

        local xShift = self:getXShift()
        local yShift = self:getYShift()

        self.screen = {}
        self.allModelWithinView = true
        -- Project, draw as rectangle if selected
        for i = 1, #points do
            local px, py, pz = points[i][1], points[i][2], points[i][3]

            local x, y = 0, 0
            if self.axes == "xz" or self.axes == "zx" then
                x, y, z = px, -pz, py
            elseif self.axes == "xy" or self.axes == "yx" then
                x, y, z = px, -py, pz
            elseif self.axes == "yz" or self.axes == "zy" then
                x, y, z = py, -pz, px
            else return end -- Axes are not defined
            xS = x*self.viewScale + xShift
            yS = y*self.viewScale + yShift
            if self:isWithinView(xS, yS) then
                self.screen[i] = {xS, yS, z}
            else
                self.screen[i] = nil
                self.allModelWithinView = false
            end

            if self.screen[i] ~= nil and self.host:drawVerticesIsOn() then
                local size = self.w*self.viewScale/(64)
                love.graphics.setColor(0,1,1,1) -- Cyan
                if selectedPoints[i] then love.graphics.setColor(0,1,0,1) end -- Green
                love.graphics.rectangle("fill", xS-size/2, yS-size/2, size, size)
            end
        end
    
        -- Draw lines by connection indices
        local drawn = {}
        
        love.graphics.setColor(1,1,1,1) -- White
        love.graphics.setLineWidth(self.lineWidth)
        for i = 1, #lines do
            local a = self.screen[i]
            local links = lines[i]
    
            if a and links then
                for _, k in ipairs(links) do
                    local b = self.screen[k]
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
        love.graphics.line(0+x,0+y,0+x,-size+y)
    elseif self.axes == "xy" or self.axes == "yx" then
        love.graphics.setColor(1,0,0,1) -- Red
        love.graphics.line(0+x,0+y,size+x,0+y)
        love.graphics.setColor(0,1,0,1) -- Green
        love.graphics.line(0+x,0+y,0+x,-size+y)
    elseif self.axes == "yz" or self.axes == "zy" then
        love.graphics.setColor(0,1,0,1) -- Green
        love.graphics.line(0+x,0+y,size+x,0+y)
        love.graphics.setColor(0,0,1,1) -- Blue
        love.graphics.line(0+x,0+y,0+x,-size+y)
    else return end -- Axes are not defined
end

function Panel2d:panCamera(dx, dy)
    self.dx = self.dx + dx
    self.dy = self.dy + dy
end

function Panel2d:handleArrowInput(dt)
    if love.keyboard.isDown("left") then self:panCamera(self.panSpeed * dt, 0) end
    if love.keyboard.isDown("right") then self:panCamera(-self.panSpeed * dt, 0) end
    if love.keyboard.isDown("up") then self:panCamera(0, self.panSpeed * dt) end
    if love.keyboard.isDown("down") then self:panCamera(0, -self.panSpeed * dt) end
end

function Panel2d:keyPressed(key)
    local action = self.host:getModelerKeyActions()[key]
    if action then action[1]() end
end

function Panel2d:textInput(t)
end

function Panel2d:mousePressed(mx, my, button)
    local lShiftDown = love.keyboard.isDown("lshift")
    local lCtrlDown = love.keyboard.isDown("lctrl")
    local lAltDown = love.keyboard.isDown("lalt")
    local spaceDown = love.keyboard.isDown("space")

    if not (((lShiftDown or lAltDown) and self.toolMode == "selection") 
        or self.toolMode == "move") then 
        self.currentModel:deSelect() 
    end

    if self.toolMode == "vertex" then
        if not (lShiftDown or lCtrlDown) then
            local tx, ty = self:screenPosToModelPos(mx, my)
            self.currentModel:addVertexOnPlane(tx, ty, self.axes)
        end
    end

    self.prevClickX = mx
    self.prevClickY = my
end

function Panel2d:mouseReleased(mx, my, button)
    local lShiftDown = love.keyboard.isDown("lshift")
    local lCtrlDown = love.keyboard.isDown("lctrl")
    local lAltDown = love.keyboard.isDown("lalt")

    if self.toolMode == "selection" then
        if button == 1 then -- left click
            if (math.abs(mx - self.prevClickX) < 5) 
                and (math.abs(my - self.prevClickY) < 5) then -- Very small area between press and release
                if lAltDown then self:toggleVertexSelectionWithinClick(mx, my, false)
                else self:toggleVertexSelectionWithinClick(mx, my, true) end
            else
                if lAltDown then self:toggleVertexSelectionWithinRectangle(self.prevClickX, self.prevClickY, mx, my, false)
                else self:toggleVertexSelectionWithinRectangle(self.prevClickX, self.prevClickY, mx, my, true) end
            end
        end
    elseif self.toolMode == "vertex" then -- Draw circle centered at previous mouseLeft press
        if lShiftDown then -- Draw circle
            local cx, cy = self:screenPosToModelPos(self.prevClickX, self.prevClickY)
            local mPosMX, mPosMY = self:screenPosToModelPos(mx, my)
            local dx, dy = cx - mPosMX, cy - mPosMY
            local radius = math.sqrt((dx*dx) + (dy*dy))
            local plane = self.axes
            local segments = self.host:getCircleSegments()
            local connectLines = true
            if self.axes == "xz" or self.axes == "zx" then
                self.currentModel:drawCircle(cx, 0, cy, radius, plane, segments, connectLines)
            elseif self.axes == "xy" or self.axes == "yx" then
                self.currentModel:drawCircle(cx, cy, 0, radius, plane, segments, connectLines)
            elseif self.axes == "yz" or self.axes == "zy" then
                self.currentModel:drawCircle(0, cx, cy, radius, plane, segments, connectLines)
            end
        elseif lCtrlDown then -- Draw sphere
            local cx, cy = self:screenPosToModelPos(self.prevClickX, self.prevClickY)
            local mPosMX, mPosMY = self:screenPosToModelPos(mx, my)
            local dx, dy = cx - mPosMX, cy - mPosMY
            local radius = math.sqrt((dx*dx) + (dy*dy))
            local segments = self.host:getSphereSegments()
            local connectLines = true
            if self.axes == "xz" or self.axes == "zx" then
                self:getCurrentModel():drawSphere(cx, 0, cy, radius, segments, connectLines)
            elseif self.axes == "xy" or self.axes == "yx" then
                self:getCurrentModel():drawSphere(cx, cy, 0, radius, segments, connectLines)
            elseif self.axes == "yz" or self.axes == "zy" then
                self:getCurrentModel():drawSphere(0, cx, cy, radius, segments, connectLines)
            end
        end
    end
end

function Panel2d:mouseMoved(x, y, dx, dy)
    local sdx, sdy = dx / self.viewScale, dy / self.viewScale
    if self.host:getToolMode() == "move" and love.mouse.isDown(1) then
        if self.axes == "xz" or self.axes == "zx" then 
            self.currentModel:transformSelected(sdx, 0, -sdy) 
        elseif self.axes == "xy" or self.axes == "yx" then 
            self.currentModel:transformSelected(sdx, -sdy, 0) 
        elseif self.axes == "yz" or self.axes == "zy" then 
            self.currentModel:transformSelected(0, sdx, -sdy) 
        end
    end
end

function Panel2d:wheelMoved(x, y)
    if y > 0 then -- Wheel moved up
        self.viewScale = self.viewScale + self.viewScale/10
    elseif y < 0 then -- Wheel moved down
        self.viewScale = self.viewScale - self.viewScale/10
    end
end

function Panel2d:screenPosToModelPos(x, y)
    local tx = (x - self.x - self.w/2) / self.viewScale
    local ty = -(y - self.y - self.h/2) / self.viewScale
    return tx, ty
end

function Panel2d:deSelect()
    if self.currentModel then 
        self.currentModel:deSelect()
    end
end

function Panel2d:selectAll()
    self:getCurrentModel():selectAll()
end

function Panel2d:toggleVertexSelectionWithinClick(mx, my, val)
    if self.currentModel then
        local iSelected = nil
        for i=1, #self.screen, 1 do
            if self.screen[i] == nil then 
                -- Silly lua doesn't support continue...
            elseif self.currentModel:isWithinCircle(mx, my, self.screen[i][1], self.screen[i][2], 
                self.clickRange) then
                -- If nearest to viewer, select
                if (iSelected == nil) or (self.screen[i][3] < self.screen[iSelected][3]) then
                    iSelected = i
                end
            end
        end
        if iSelected ~= nil then self.currentModel:toggleVertexSelection(iSelected, val) end
    end
end

function Panel2d:toggleVertexSelectionWithinRectangle(x1, y1, x2, y2, val)
    if self.currentModel then
        for i=1, #self.screen, 1 do
            if self.screen[i] == nil then 
                -- Silly lua doesn't support continue...
            elseif self.currentModel:isWithinRectangle(x1, y1, x2, y2, self.screen[i][1], self.screen[i][2]) then
                if i ~= nil then self.currentModel:toggleVertexSelection(i, val) end
            end
        end
    end
end

function Panel2d:drawHiddenVerticesComplaint()
    love.graphics.setColor(1,0.2,0,1) -- Brown
    local complaint = "The complete model is not visible, try increasing view distance"
    love.graphics.print(complaint, self.x + self.w/32, self.y + self.h/32, 0)
end

function Panel2d:isWithinView(x, y)
    return ((x > self.x) and ((self.x + self.w) > x) and 
        (y > self.y) and ((self.y + self.h) > y))
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
    return self.x+self.w/2 + self.dx
end

function Panel2d:getYShift()
    return self.y+self.h/2 + self.dy
end

function Panel2d:getAxisMarkerX()
    return self.x + self.w/8
end

function Panel2d:getAxisMarkerY()
    return self.y + self.h - self.h/8
end
return {Panel2d = Panel2d}