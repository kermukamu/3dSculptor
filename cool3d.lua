-- cool3d "class"
local Cool3d = {}
Cool3d.__index = Cool3d

function Cool3d.new(x2d, y2d, modelDistance, host)
	local self = setmetatable({}, Cool3d)
    self.host = host

	self.points = {} -- Stores vertices as x y z. Indices = numbering
	self.lines = {} -- Position of each entry matches a vertex index, the entry value is another vertex
    self.pointsCB = {} -- Points saved on clipboard
    self.linesCB = {} -- Lines saved on clipboard
	self.lineWidth = 1
    self.dx = 0
    self.dy = 0
	self.dz = modelDistance
    self.rotSpeedPhi = 0
    self.rotSpeedTheta = 0.1
    self.rotAnglePhi = 0
    self.rotAngleTheta = 0
    self.viewingRotTable = {0, 0, 0, 0}
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

function Cool3d:update(dt)
    self.timer = self.timer + 1 * dt
    --self.dz = math.sin(self.zSpeed * self.timer) + 3
    self.rotAnglePhi = (self.rotAnglePhi + math.pi * self.rotSpeedPhi * dt)
    self.rotAngleTheta = (self.rotAngleTheta + math.pi * self.rotSpeedTheta * dt)
    self.viewingRotTable = self:calcRotationTable(self.rotAnglePhi, self.rotAngleTheta)
    self:updateModel()

    self.dz = math.max(self.dz, 0)
end

function Cool3d:updateModel()
    -- Screen will be reset every time the model is drawn.
    -- The table will have the transformed, rotated and projected vertices (2D)
    -- The z values of transformed vertices are also stored in self as they are needed to scale marker elements
    self.screen = {}
    self.allModelWithinView = true
    for i = 1, #self.points do
        -- Rotations and translations
        local p = self:rotate(self.points[i], self.viewingRotTable)
        p = self:translateXYZ(p, {self.dx, self.dy, self.dz})

        local proj = {0, 0}
        if p[3] and p[3] > 0.001 then -- Translated z is not outside the view (monitor)
            local proj = self:project(p)
            local vx = self.x2d + proj[1]*self.zCompression
            local vy = self.y2d - proj[2]*self.zCompression
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
    end
end

function Cool3d:draw()
    self:drawModel()
    if self.host:drawAxisMarkerIsOn() then self:drawAxisMarker() end
end

function Cool3d:drawModel()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(self.lineWidth)

    for i = 1, #self.screen do
        if self.screen[i] ~= nil then
            -- Text next to vertices
            local tScaling = self.zCompression*self.textScale/self.screen[i][3]
            if self.selectedVertices[i] then
                if self.host:vertexNumberingIsOn() then
                    -- love.graphics.setColor(1,1,0,1) -- Yellow
                    love.graphics.setColor(0,1,0,1) -- Green
                    love.graphics.print(tostring(i), self.screen[i][1], self.screen[i][2], 0, tScaling, tScaling)
                    love.graphics.setColor(1,1,1,1)
                end
    
                if self.host:vertexCoordsIsOn() then
                    local text = string.format("%.2f", self.points[i][1]) .. " " ..
                        string.format("%.2f", self.points[i][2]) .. " " .. string.format("%.2f", self.points[i][3])
                    local yOffset = love.graphics.getFont():getHeight() * (tScaling)
                    --love.graphics.setColor(1,0.5,0,1) -- Orange
                    love.graphics.setColor(0,0.5,0,1) -- Darker green
                    love.graphics.print(text, self.screen[i][1], self.screen[i][2] + yOffset, 0, tScaling, tScaling)
                    love.graphics.setColor(1,1,1,1)
                end
            end
    
            -- The rectangles drawn at vertices
            if self.host:drawVerticesIsOn() then
                local size = math.min(self.zCompression*self.host:getW()/(64*self.screen[i][3]), 25)
                love.graphics.setColor(0,1,1,1) -- Cyan
                if self.selectedVertices[i] then love.graphics.setColor(0,1,0,1) end -- Green if selected
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

    -- Both projection calculations and drawing is handled here due to the light computational weight of the axis marker
    local screen = {} -- Unlike in drawModel(), locals are used
    local size = self.host:getW()/32
    local points = {{0, 0, 0}, {size, 0, 0}, {0, size, 0}, {0, 0, size}}
    local lines = {{2, 3, 4}}

    for i = 1, #points do
        -- Rotations and translations
        local p = self:rotate(points[i], self.viewingRotTable)
        p = self:translateXYZ(p, {self.dxMarker, self.dyMarker, self.dzMarker})

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

function Cool3d:copySelected()
    -- Clear clipboard first
    self.pointsCB = {}
    self.linesCB = {}

    -- Collect selected vertex indices
    local selectedIndices = {}
    for i = 1, #self.points do
        if self.selectedVertices[i] then
            table.insert(selectedIndices, i)
        end
    end

    if #selectedIndices == 0 then return end

    local indexMap = {}

    -- Copy vertices and calculate their average position
    local xSum, ySum, zSum = 0, 0, 0
    for newIndex, oldIndex in ipairs(selectedIndices) do
        indexMap[oldIndex] = newIndex

        local v = self.points[oldIndex]
        local x, y, z = v[1], v[2], v[3]

        self.pointsCB[newIndex] = {x, y, z}
        self.linesCB[newIndex] = {}

        xSum = xSum + x
        ySum = ySum + y
        zSum = zSum + z
    end

    local count = #selectedIndices
    local xAvg = xSum / count
    local yAvg = ySum / count
    local zAvg = zSum / count

    -- Subtract average to move to origin
    for i = 1, #self.pointsCB do
        self.pointsCB[i][1] = self.pointsCB[i][1] - xAvg
        self.pointsCB[i][2] = self.pointsCB[i][2] - yAvg
        self.pointsCB[i][3] = self.pointsCB[i][3] - zAvg
    end

    -- Copy lines where both endpoints are selected
    for _, oldIndex in ipairs(selectedIndices) do
        local newIndex = indexMap[oldIndex]
        local links = self.lines[oldIndex]

        if links then
            for _, oldNeighbor in ipairs(links) do
                local newNeighbor = indexMap[oldNeighbor]
                if newNeighbor then
                    -- Both vertices selected → keep this line
                    table.insert(self.linesCB[newIndex], newNeighbor)
                end
            end
        end
    end
end

function Cool3d:pasteSelected(x, y, z) -- Paste to xyz
    if #self.pointsCB == 0 then return end
    local baseIndex = #self.points

    -- Add all pasted vertices and matching empty line lists
    for _, p in ipairs(self.pointsCB) do
        local newPoint = self:translateXYZ(p, {x, y, z})
        table.insert(self.points, newPoint)
        table.insert(self.lines, {}) -- placeholder
    end

    -- Rebuild the connections between the newly added vertices
    for i, links in ipairs(self.linesCB) do
        local newIndex = baseIndex + i
        for _, neighborIndex in ipairs(links) do
            local newNeighborIndex = baseIndex + neighborIndex
            table.insert(self.lines[newIndex], newNeighborIndex)
        end
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

function Cool3d:translateXYZ(xyz, dxyz)
    return {xyz[1] + dxyz[1], xyz[2] + dxyz[2], xyz[3] + dxyz[3]}
end

function Cool3d:calcRotationTable(Phi, Theta)
    local cosP = math.cos(Phi)
    local sinP = math.sin(Phi)
    local cosT = math.cos(Theta)
    local sinT = math.sin(Theta)
    return {cosP, sinP, cosT, sinT}
end

function Cool3d:rotate(xyz, rotTable)
    local cosP = rotTable[1]
    local sinP = rotTable[2]
    local cosT = rotTable[3]
    local sinT = rotTable[4]

    local x, y, z = xyz[1], xyz[2], xyz[3]

    -- Theta
    local x1 =  cosT * x + sinT * z
    local y1 =  y
    local z1 = -sinT * x + cosT * z

    -- Phi
    local x2 = x1
    local y2 =  cosP * y1 - sinP * z1
    local z2 =  sinP * y1 + cosP * z1

    return {x2, y2, z2}
end

function Cool3d:panCamera(dx, dy)
    self.dx = self.dx + dx*self.dz/self.zCompression
    self.dy = self.dy + dy*self.dz/self.zCompression
end

function Cool3d:setCamera(x, y, z)
    self.dx = x or self.dx
    self.dy = y or self.dy
    self.dz = z or self.dz
end

function Cool3d:addVertex(x, y, z)
    table.insert(self.points, {x, y, z})
    table.insert(self.lines, {})
end

function Cool3d:addVertexOnPlane(vx, vy, plane)
    if plane == "xz" or plane == "zx" then
        self:addVertex(vx, 0, vy)
    elseif plane == "xy" or plane == "yx" then
        self:addVertex(vx, vy, 0)
    elseif plane == "yz" or plane == "zy" then
        self:addVertex(0, vx, vy)
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

function Cool3d:disconnectSelected()
    local selected = {}
    for k, v in pairs(self.selectedVertices) do
        if v then table.insert(selected, k) end
    end

    for i=1, #selected-1 do
        for j=i, #selected do
            self:disconnect(selected[i], selected[j])
        end
    end
end

function Cool3d:joinSelected()
    local selected = {}
    for k, v in pairs(self.selectedVertices) do
        if v then table.insert(selected, k) end
    end

    for i=1, #selected-1 do
        for j=i, #selected do
            self:connect(selected[i], selected[j])
        end
    end
end

function Cool3d:addCircle(centerX, centerY, centerZ, radius, plane, segments, connectLines)
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
            point = self:translateXYZ(point, {centerX, centerY, centerZ})
            self:addVertex(point[1], point[2], point[3])
        end
    elseif plane == "xz" or plane == "zx" then
        for _, p in ipairs(aux) do
            local point = {p[1], 0, p[2]}
            point = self:translateXYZ(point, {centerX, centerY, centerZ})
            self:addVertex(point[1], point[2], point[3])
        end
    elseif plane == "yz" or plane == "zy" then
        for _, p in ipairs(aux) do
            local point = {0, p[1], p[2]}
            point = self:translateXYZ(point, {centerX, centerY, centerZ})
            self:addVertex(point[1], point[2], point[3])
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

function Cool3d:addSphere(cx, cy, cz, radius, segments, connectLines)
    local connect = connectLines
    local seg = segments or 6
    if seg < 6 then return "At least 6 segments required" end

    local startIndex = #self.points + 1

    local verts = {}
    local index = {}

    -- Create vertices for latitude and longitude, excluding poles
    for lat = 1, seg - 1 do
        local phi = math.pi * lat / seg
        local sinP = math.sin(phi)
        local cosP = math.cos(phi)

        index[lat] = {}
        for lon = 0, seg - 1 do
            local theta = 2 * math.pi * lon / seg
            local x = cx + radius * sinP * math.cos(theta)
            local y = cy + radius * cosP
            local z = cz + radius * sinP * math.sin(theta)
            self:addVertex(x, y, z)
            index[lat][lon] = #self.points
        end
    end

    -- Top pole and bottom pole
    self:addVertex(cx, cy + radius, cz)
    local top = #self.points
    self:addVertex(cx, cy - radius, cz)
    local bottom = #self.points

    if connect then
        -- Triangles between latitude bands
        for lat = 1, seg - 2 do
            for lon = 0, seg - 1 do
                local a = index[lat][lon]
                local b = index[lat][(lon + 1) % seg]
                local c = index[lat + 1][lon]
                local d = index[lat + 1][(lon + 1) % seg]

                -- First
                self:connect(a, b)
                self:connect(b, c)
                self:connect(c, a)

                -- Second
                self:connect(b, d)
                self:connect(d, c)
                self:connect(c, b)
            end
        end

        -- Top cap
        for lon = 0, seg - 1 do
            local a = index[1][lon]
            local b = index[1][(lon + 1) % seg]

            self:connect(top, a)
            self:connect(a, b)
            self:connect(b, top)
        end

        -- Bottom cap
        for lon = 0, seg - 1 do
            local a = index[seg - 1][lon]
            local b = index[seg - 1][(lon + 1) % seg]

            self:connect(a, bottom)
            self:connect(bottom, b)
            self:connect(b, a)
        end
    end

    return "Sphere added"
end

function Cool3d:deSelect()
    self.selectedVertices = {}
    self.firstSelectedVert = nil
end

function Cool3d:selectAll()
     for i=1, #self.points, 1 do
        if self.points[i] == nil then 
            -- Silly lua doesn't support continue...
        elseif i ~= nil then 
            self:toggleVertexSelection(i, true)
        end
    end
end

function Cool3d:toggleVertexSelectionWithinClick(x, y, val)
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
    if iSelected ~= nil then self:toggleVertexSelection(iSelected, val) end
end

function Cool3d:toggleVertexSelectionWithinRectangle(x1, y1, x2, y2, val)
    for i=1, #self.screen, 1 do
        if self.screen[i] == nil then 
            -- Silly lua doesn't support continue...
        elseif self:isWithinRectangle(x1, y1, x2, y2, self.screen[i][1], self.screen[i][2]) then
            if i ~= nil then self:toggleVertexSelection(i, val) end
        end
    end
end

function Cool3d:transformSelected(dx, dy, dz)
    for i, selected in pairs(self.selectedVertices) do
        if selected then
            local v = self.points[i]
            local vx, vy, vz = v[1]+dx, v[2]+dy, v[3]+dz
            self.points[i] = {vx, vy, vz}
        end
    end
end

function Cool3d:rotateSelected(argPhi, argTheta)
    -- Collect selected indices and compute their center
    local selected = {}
    local xSum, ySum, zSum = 0, 0, 0

    for i, isSelected in pairs(self.selectedVertices) do
        if isSelected and self.points[i] then
            table.insert(selected, i)
            local v = self.points[i]
            xSum = xSum + v[1]
            ySum = ySum + v[2]
            zSum = zSum + v[3]
        end
    end

    -- Nothing selected → nothing to do
    if #selected == 0 then return end

    local count = #selected
    local xAvg = xSum / count
    local yAvg = ySum / count
    local zAvg = zSum / count

    -- Convert degrees to radians and build rotation table
    local deg2rad = math.pi / 180
    local phi   = (argPhi   or 0) * deg2rad
    local theta = (argTheta or 0) * deg2rad
    local rotTable = self:calcRotationTable(phi, theta)

    -- Rotate each selected vertex around the selection center
    for _, i in ipairs(selected) do
        local v = self.points[i]
        -- Translate to center
        local tx = v[1] - xAvg
        local ty = v[2] - yAvg
        local tz = v[3] - zAvg

        local rotated = self:rotate({tx, ty, tz}, rotTable)

        -- Translate back and store
        self.points[i] = {rotated[1] + xAvg, rotated[2] + yAvg, rotated[3] + zAvg}
    end
end

function Cool3d:rotateSelectedXY(angleDeg) 
    -- A Separate function as the default phi theta approach has a blindspot for xy plane
    local selected = {}
    local xSum, ySum, zSum = 0, 0, 0

    for i, v in pairs(self.selectedVertices) do
        if v and self.points[i] then
            table.insert(selected, i)
            local p = self.points[i]
            xSum = xSum + p[1]
            ySum = ySum + p[2]
            zSum = zSum + p[3]
        end
    end

    if #selected == 0 then return end

    local cx = xSum / #selected
    local cy = ySum / #selected
    local cz = zSum / #selected

    local angle = angleDeg * math.pi / 180

    for _, i in ipairs(selected) do
        local p = self.points[i]

        -- Move to center and rotate
        local localPos = {p[1] - cx, p[2] - cy, p[3] - cz}
        local rotated = self:rotateZ(localPos, angle)

        -- Move back
        self.points[i] = {rotated[1] + cx, rotated[2] + cy, 
            rotated[3] + cz}
    end
end

function Cool3d:rotateZ(xyz, angle)
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    local x = xyz[1]
    local y = xyz[2]
    local z = xyz[3]

    local x2 = cosA * x - sinA * y
    local y2 = sinA * x + cosA * y

    return {x2, y2, z}
end

function Cool3d:deleteSelected()
    for i=#self.points, 1, -1 do
        if self.selectedVertices[i] then self:removeVertex(i) end
    end
    self:deSelect()
end

function Cool3d:joinSelectedToNearestSelected()
    --Vibe coded function, it better work damn it
    local selected = {}
    for i, v in pairs(self.selectedVertices) do
        if v then table.insert(selected, i) end
    end

    -- Need at least two vertices
    if #selected < 2 then return end

    -- For each selected vertex, find nearest other selected vertex
    for _, i in ipairs(selected) do
        local pi = self.points[i]
        local nearest = nil
        local minDistSq = math.huge

        for _, j in ipairs(selected) do
            if i ~= j then
                local pj = self.points[j]
                local dx = pi[1] - pj[1]
                local dy = pi[2] - pj[2]
                local dz = pi[3] - pj[3]
                local distSq = dx*dx + dy*dy + dz*dz

                if distSq < minDistSq then
                    minDistSq = distSq
                    nearest = j
                end
            end
        end

        -- Connect to nearest selected vertex
        if nearest then
            self:connect(i, nearest)
        end
    end
end

function Cool3d:multiplyModelSize(m)
    for i, selected in pairs(self.selectedVertices) do
        if selected then
            local v = self.points[i]
            local vx, vy, vz = v[1]*m, v[2]*m, v[3]*m
            self.points[i] = {vx, vy, vz}
        end
    end
end

function Cool3d:getSelectionCenter()
    local xSum, ySum, zSum = 0, 0, 0
    local count = 0
    for k, v in pairs(self.selectedVertices) do
        if v and self.points[k] then
            local x, y, z = self.points[k][1], self.points[k][2], self.points[k][3]
            xSum = xSum + x
            ySum = ySum + y
            zSum = zSum + z
            count = count + 1
        end
    end
    if count == 0 then
        return 0, 0, 0
    end

    local xAvg = xSum / count
    local yAvg = ySum / count
    local zAvg = zSum / count
    return xAvg, yAvg, zAvg
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

function Cool3d:isWithinRectangle(x1, y1, x2, y2, px, py)
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)

    return px >= minX and px <= maxX and py >= minY and py <= maxY
end

-- Getters and setters

function Cool3d:getPoints() return self.points end
function Cool3d:getLines() return self.lines end
function Cool3d:getTextScale() return self.textScale end
function Cool3d:getSelectedVertices() return self.selectedVertices end
function Cool3d:getAxisMarkerX() return self.host:getX() + self.host:getW()/8 end
function Cool3d:getAxisMarkerY() return self.host:getY() + self.host:getH() - self.host:getH()/8 end
function Cool3d:getAllModelWithinView() return self.allModelWithinView end
function Cool3d:getDZ(value) return self.dz end
function Cool3d:setDZ(value) self.dz = value end
function Cool3d:toggleVertexSelection(number, val)
    if not val then
        -- Deselection is done this way as normally deselected vertices
        -- are not stored at all in self.selectedVertices
        self.selectedVertices[number] = nil
        return nil
    end

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

function Cool3d:incrementOrientation(argPhi, argTheta)
    local deg2rad = math.pi / 180
    self.rotAnglePhi = self.rotAnglePhi + argPhi * deg2rad
    self.rotAngleTheta = self.rotAngleTheta +argTheta * deg2rad
end

return { Cool3d = Cool3d}