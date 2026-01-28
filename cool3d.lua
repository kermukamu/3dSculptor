-- cool3d "class"
local Cool3d = {}
Cool3d.__index = Cool3d

function Cool3d.new(x2d, y2d, modelDistance, host)
	local self = setmetatable({}, Cool3d)
    self.host = host

	self.points = {} -- AKA vertices
	self.lines = {} -- between assigned vertices
	self.lineWidth = 1 or 1
    self.dx = 0
    self.dy = 0
	self.dz = modelDistance
    self.rotSpeedPhi = 0
    self.rotSpeedTheta = 0.1
    self.rotAnglePhi = 0
    self.rotAngleTheta = 0
    self.timer = 0
    self.zSpeed = 0.2

    self.dxMarker = 0
    self.dyMarker = 0
    self.dzMarker = 1000
    self.zCompression = 1000
    self.textScale = 1
    self.screen = {}
    self.selectedVertices = {}
    self.firstSelectedVert = nil
    self.clickRange = 5

    self.allModelWithinView = true

    self.x2d = x2d or 0
    self.y2d = y2d or 0
	return self
end

function Cool3d:readFile(filename)
    if filename == nil then return "No filename given" end
	local contents, err = love.filesystem.read(filename)
	if not contents then return "Could not open file" end

    self:clear()
	--Separate lines
	for line in contents:gmatch("[^\r\n]+") do
		-- Separate each value in a line, form should be x1 y1 z1 i1 i2 i3 i4...\n
		local pointParts = {}
		local lineParts = {}
		local i = 1
		for part in line:gmatch("%S+") do
			if i > 3 then table.insert(lineParts, tonumber(part))
			else table.insert(pointParts, tonumber(part)) end
			i = i + 1
		end
		table.insert(self.points, pointParts)
		table.insert(self.lines, lineParts)
	end

    return "Read table!"
end

function Cool3d:saveFile(filename)
    if filename == nil then return "No filename given" end
    local fileText = ""
    for i = 1, #self.points, 1 do
        local p = self.points[i]
        fileText = fileText .. tostring(p[1]) .. " ".. tostring(p[2]) .. " ".. tostring(p[3])
        for j = 1, #self.lines[i], 1 do
            fileText = fileText .. " " .. tostring(self.lines[i][j])
        end
        fileText = fileText .. "\n"
    end

    local success, message = love.filesystem.write(filename, fileText)
    if success then 
        return "File successfully saved to " .. love.filesystem.getSaveDirectory()
    else
        return "Write unsuccessful"
    end
end

function Cool3d:clear()
    self.points = {}
    self.lines = {}
end

function Cool3d:project(xyz)
	local x = xyz[1]
	local y = xyz[2]
	local z = xyz[3]
	if z == 0 then return {0,0} end
    return {x / z, y / z}
end

function Cool3d:translate_xyz(xyz, dxyz)
    return {xyz[1] + dxyz[1], xyz[2] + dxyz[2], xyz[3] + dxyz[3]}
end

function Cool3d:rotate(xyz, Phi, Theta)
    local cosPhi = math.cos(Phi)
    local sinPhi = math.sin(Phi)
    local cosTheta = math.cos(Theta)
    local sinTheta = math.sin(Theta)
    local x, y, z = xyz[1], xyz[2], xyz[3]

    -- Rotate on phi
    local x1 = cosPhi * x - sinPhi * y
    local y1 = sinPhi * x + cosPhi * y
    local z1 = z

    -- Rotate on theta
    local x2 =  cosTheta * x1 + sinTheta * z1
    local y2 =  y1
    local z2 = -sinTheta * x1 + cosTheta * z1

	return {x2, y2, z2}
end

function Cool3d:update(dt)
    self.timer = self.timer + 1 * dt
    --self.dz = math.sin(self.zSpeed * self.timer) + 3
    self.rotAnglePhi = (self.rotAnglePhi + math.pi * self.rotSpeedPhi * dt)
    self.rotAngleTheta = (self.rotAngleTheta + math.pi * self.rotSpeedTheta * dt)

    self.dz = math.max(self.dz, 0)
end

function Cool3d:draw()
    self:drawModel()
    if not self.allModelWithinView then self:drawHiddenVerticesComplaint() end
    if self.host:drawAxisMarkerIsOn() then self:drawAxisMarker() end
end

function Cool3d:drawModel()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(self.lineWidth)

    local w, h = love.graphics.getDimensions()

    -- Screen will be reset every time the model is drawn.
    -- The table will have the transformed, rotated and projected vertices (2D)
    -- The z values of transformed vertices are also stored in self as they are needed elsewhere
    self.screen = {}
    self.allModelWithinView = true
    for i = 1, #self.points do
        -- Rotations and translations
        local p = self:rotate(self.points[i], self.rotAnglePhi, self.rotAngleTheta)
        p = self:translate_xyz(p, {self.dx, self.dy, self.dz})

        local proj = {0, 0}
        if p[3] and p[3] > 0.001 then -- Translated z is not outside the view (monitor)
            local proj = self:project(p)
            local vx, vy = self.x2d + proj[1]*self.zCompression, self.y2d - proj[2]*self.zCompression, z
            if self:isWithinView(vx, vy) then
                self.screen[i] = {vx, vy, p[3]}
            else
                self.screen[i] = nil
                self.allModelWithinView = false
            end
        else
            self.screen[i] = nil
            self.allModelWithinView = false
        end

        if self.screen[i] ~= nil then
            -- Text next to vertices
            local tScaling = self.zCompression*self.textScale/p[3]
            if self.host:vertexNumberingIsOn()  then
                love.graphics.setColor(1,1,0,1) -- Yellow
                if self.selectedVertices[i] then love.graphics.setColor(0,1,0,1) end -- Green if vertex is selected
                love.graphics.print(tostring(i), self.screen[i][1], self.screen[i][2], 0, tScaling, tScaling)
                love.graphics.setColor(1,1,1,1)
            end

            if self.host:vertexCoordsIsOn() then
                local text = tostring(self.points[i][1]) .. " " ..
                    tostring(self.points[i][2]) .. " " .. tostring(self.points[i][3])
                local yOffset = love.graphics.getFont():getHeight() * (tScaling)
                love.graphics.setColor(1,0.5,0,1) -- Orange
                if self.selectedVertices[i] then love.graphics.setColor(0,0.5,0,1) end -- Darker green if vertex is selected
                love.graphics.print(text, self.screen[i][1], self.screen[i][2] + yOffset, 0, tScaling, tScaling)
                love.graphics.setColor(1,1,1,1)
            end

            -- The rectangles drawn at vertices
            if self.host:drawVerticesIsOn() then
                local size = self.zCompression*self.host:getW()/(64*self.screen[i][3])
                love.graphics.setColor(0,1,1,1) -- Cyan
                if self.selectedVertices[i] then love.graphics.setColor(0,1,0,1) end -- Green
                love.graphics.rectangle("fill", self.screen[i][1]-size/2, self.screen[i][2]-size/2, size, size)
            end
        end
    end
 
    -- Draw lines by connection indices
    local drawn = {}

    love.graphics.setColor(1,1,1,1) -- white
    for i = 1, #self.lines do
        local a = self.screen[i]
        local links = self.lines[i]

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

function Cool3d:drawAxisMarker()
    love.graphics.setLineWidth(self.lineWidth)

    local w, h = love.graphics.getDimensions()
    local screen = {} -- Unlike in drawModel(), locals are used
    local size = self.host:getW()/32
    local points = {{0, 0, 0}, {size, 0, 0}, {0, size, 0}, {0, 0, size}}
    local lines = {{2, 3, 4}}

    for i = 1, #points do
        -- Rotations and translations
        local p = self:rotate(points[i], self.rotAnglePhi, self.rotAngleTheta)
        p = self:translate_xyz(p, {self.dxMarker, self.dyMarker, self.dzMarker})

        local proj = {0, 0}
        if p[3] and p[3] > 0.001 then -- Translated z is not outside the view (monitor)
            local proj = self:project(p)
            local vx, vy = self:getAxisMarkerX() + proj[1]*self.zCompression, 
                self:getAxisMarkerY() - proj[2]*self.zCompression
            if self:isWithinView(vx, vy) then
                screen[i] = {vx, vy, p[3]}
            else
                screen[i] = nil
            end
        else
            screen[i] = nil
        end
    end
    -- Draw lines by connection indices
    local drawn = {}
    local colors = {{}, {1,0,0}, {0,1,0}, {0,0,1}}
    for i = 1, #lines do
        local a = screen[i]
        local links = lines[i]

        if a and links then
            for _, k in ipairs(links) do
                local r, g, b = colors[k][1], colors[k][2], colors[k][3] -- Stupid way to do it, well...
                love.graphics.setColor(r, g, b, 1)
                local b = screen[k]
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

function Cool3d:drawHiddenVerticesComplaint()
    love.graphics.setColor(1,0.2,0,1) -- Brown
    local complaint = "The complete model is not visible, try increasing view distance"
    love.graphics.print(complaint, self.host:getX() + self.host:getW()/32, self.host:getY() + self.host:getH()/32, 0, tScaling, tScaling)
end

function Cool3d:addVertex(x, y, z)
    table.insert(self.points, {x, y, z})
    table.insert(self.lines, {})
end

function Cool3d:addVertexOnPlane(x, y, plane)
    if plane == "xz" or plane == "zx" then
        self:addVertex(x, 0, y)
    elseif plane == "xy" or plane == "yx" then
        self:addVertex(x, y, 0)
    elseif plane == "yz" or plane == "zy" then
        self:addVertex(0, x, y)
    end
end

function Cool3d:removeVertex(number)
    -- Remove all connections to the point in line connections before removing the point
    table.remove(self.lines, number) -- Vertex to others
    local lTableIndices = {}
    for i = 1, #self.lines, 1 do
        local l = self.lines[i]
        for j = 1, #l, 1 do
            if l[j] == number then 
                table.insert(lTableIndices, {i, j})
            elseif l[j] > number then
                l[j] = l[j] - 1 -- Shift connections down due to element removal
            end
        end
    end
    for _, lTI in ipairs(lTableIndices) do
        table.remove(self.lines[lTI[1]], lTI[2]) -- Others to vertex
    end

    -- Remove the vertex itself
    table.remove(self.points, number)
end

function Cool3d:connect(v1, v2)
    table.insert(self.lines[v1], v2)
end

function Cool3d:disconnect(v1, v2)
    local lTableIndices = {}
    for i = 1, #self.lines[v1], 1 do
        if self.lines[v1][i] == v2 then
            table.insert(lTableIndices, {v1, i})
        end
    end
    for i = 1, #self.lines[v2], 1 do
        if self.lines[v2][i] == v1 then
            table.insert(lTableIndices, {v2, i})
        end
    end
    for _, lTI in ipairs(lTableIndices) do
        table.remove(self.lines[lTI[1]], lTI[2])
    end
end

function Cool3d:drawCircle(centerX, centerY, centerZ, radius, plane, segments, connectLines)
    local seg = segments or 16
    if seg < 3 then return "Atleast 3 segments required" end
    local connect = connectLines
    local angleDT = 2*math.pi/segments

    -- First set circle points in an auxiliary coordinate system
    local aux = {}
    for i=0, segments-1, 1 do
        local a = math.cos(angleDT * i)*radius
        local b = math.sin(angleDT * i)*radius
        table.insert(aux, {a, b})
    end

    -- Move auxiliary points to xyz at correct position according to given plane
    if plane == "xy" or plane == "yx" then
        for _, p in ipairs(aux) do
            local point = {p[1], p[2], 0}
            point = self:translate_xyz(point, {centerX, centerY, centerZ})
            self:addVertex(self:r2Dec(point[1]), self:r2Dec(point[2]), self:r2Dec(point[3]))
        end
    elseif plane == "xz" or plane == "zx" then
        for _, p in ipairs(aux) do
            local point = {p[1], 0, p[2]}
            point = self:translate_xyz(point, {centerX, centerY, centerZ})
            self:addVertex(self:r2Dec(point[1]), self:r2Dec(point[2]), self:r2Dec(point[3]))
        end
    elseif plane == "yz" or plane == "zy" then
        for _, p in ipairs(aux) do
            local point = {0, p[1], p[2]}
            point = self:translate_xyz(point, {centerX, centerY, centerZ})
            self:addVertex(self:r2Dec(point[1]), self:r2Dec(point[2]), self:r2Dec(point[3]))
        end
    else return "Plane parameter is incorrect" end

    if connect then
        local linTot = #self.lines
        for i = linTot-seg + 1, linTot-1, 1 do
            table.insert(self.lines[i], i+1)
        end
        -- Close the circle
        table.insert(self.lines[linTot-seg+1], linTot)
    end

    return "Circle drawn"
end

function Cool3d:r2Dec(value)
    return math.floor(100*value) / 100
end


function Cool3d:deSelect()
    self.selectedVertices = {}
    self.firstSelectedVert = nil
end

function Cool3d:selectVertexWithin(x, y)
    local iSelected = nil
    for i=1, #self.screen, 1 do
        if self.screen[i] == nil then 
            -- Silly lua doesn't support continue...
        elseif self:isWithinCircle(x, y, self.screen[i][1], self.screen[i][2], 
            self.clickRange) then
            if (iSelected == nil) or (self.screen[i][3] < self.screen[iSelected][3]) then
                iSelected = i
            end
        end
    end
    if iSelected ~= nil then self:setVertexSelected(iSelected) end
end

function Cool3d:deleteSelected()
    for i=1, #self.points, 1 do
        if self.selectedVertices[i] then self:removeVertex(i) end
    end
    self:deSelect()
end

function Cool3d:joinToFirstSelected()
    for k, v in pairs(self.selectedVertices) do
        if v == true and (v ~= self.firstSelectedVert) and (self.firstSelectedVert ~= nil) then
            self:connect(self.firstSelectedVert, k)
        end
    end
end

function Cool3d:multiplyModelSize(multiplier)
    for _, p in ipairs(self.points) do
        p[1] = p[1] * multiplier
        p[2] = p[2] * multiplier
        p[3] = p[3] * multiplier
    end
end

function Cool3d:isWithinView(x, y)
    return ((x > self.host:getX()) and ((self.host:getX() + self.host:getW()) > x) and 
        (y > self.host:getY()) and ((self.host:getY() + self.host:getH()) > y))
end

function Cool3d:isWithinCircle(px, py, cx, cy, r)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (r * r)
end

-- Getters and setters

function Cool3d:getPoints() return self.points end
function Cool3d:getLines() return self.lines end
function Cool3d:getTextScale() return self.textScale end
function Cool3d:getSelectedVertices() return self.selectedVertices end
function Cool3d:getAxisMarkerX() return self.host:getX() + self.host:getW()/8 end
function Cool3d:getAxisMarkerY() return self.host:getY() + self.host:getH() - self.host:getH()/8 end
function Cool3d:getDZ(value) return self.dz end
function Cool3d:setDZ(value) self.dz = value end
function Cool3d:setVertexSelected(number) 
    -- Save first selected vertice
    if (self.firstSelectedVert == nil) then
        self.firstSelectedVert = number
    end
    self.selectedVertices[number] = true
end

function Cool3d:setOrientation(argPhi, argTheta)
    local deg2rad = math.pi / 180
    self.rotAnglePhi = argPhi * deg2rad
    self.rotAngleTheta = argTheta * deg2rad
end

function Cool3d:setRotation(argPhi, argTheta)
    local deg2rad = math.pi / 180
    self.rotSpeedPhi = argPhi * deg2rad
    self.rotSpeedTheta = argTheta * deg2rad
end

return { Cool3d = Cool3d}