-- cool3d "class"
local Cool3d = {}
Cool3d.__index = Cool3d

function Cool3d.new(x2d, y2d, modelDistance, host)
	local self = setmetatable({}, Cool3d)
    self.host = host

	self.points = {} -- Stores vertices as x y z. Indices = numbering
	self.lines = {} -- Position of each entry matches a vertex index, the entry value is another vertex
    self.faces = {} -- Each entry consists of all vertex indices that form a face
    self.faceColors = {} -- The index of each entry is equivalent to indices of each face entry. Values inside each entry are R G B O

    self.buffer = {} -- Contains last 10 models in form {points, lines, faces, faceColors}

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
    self.zSpeed = 0.2

    self.dxMarker = 0
    self.dyMarker = 0
    self.dzMarker = 1000
    self.zCompression = 400
    self.textScale = 1
    self.screen = {} -- Used to handle user interaction with projected points
    self.drawScreen = {} -- These are sent to 2D drawing calls
    self.pointsWorld = {}
    self.selectedVertices = {}
    self.selectedFaces = {}
    self.firstSelectedVert = nil
    self.clickRange = 5

    self.allModelWithinView = true

    self.x2d = x2d or 0
    self.y2d = y2d or 0

    self.timer = 0
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
    self.drawScreen = {}
    self.pointsWorld = {}
    self.allModelWithinView = true
    for i = 1, #self.points do
        -- Rotations and translations
        local p = self:rotate(self.points[i], self.viewingRotTable)
        p = self:translateXYZ(p, {self.dx, self.dy, self.dz})

        self.pointsWorld[i] = p

        local proj = {0, 0}
        if p[3] and p[3] > 0.001 then -- Translated z is not outside the view (monitor)
            local proj = self:project(p)
            local vx = self.x2d + proj[1]*self.zCompression
            local vy = self.y2d - proj[2]*self.zCompression
            self.drawScreen[i] = {vx, vy, p[3]}
            if self:isWithinView(vx, vy) then
                self.screen[i] = {vx, vy, p[3]}
            else
                self.screen[i] = nil
                self.allModelWithinView = false
            end
        else
            self.drawScreen[i] = nil
            self.screen[i] = nil
            self.allModelWithinView = false
        end
    end
end

function Cool3d:saveToBuffer()
    -- Limit buffer size to 50
    if #self.buffer >= 50 then table.remove(self.buffer, 1) end

    local points = {}
    local lines = {}
    for i, p in ipairs(self.points) do
        table.insert(points, {p[1], p[2], p[3]})
        lines[i] = {}
        if self.lines[i] then
            for _, l in ipairs(self.lines[i]) do
                table.insert(lines[i], l)
            end
        end
    end
    local faces = {}
    local faceColors = {}
    for i, f in ipairs(self.faces) do
        local face = {}
        for _, vi in ipairs(self.faces[i]) do
            table.insert(face, vi)
        end
        faces[i] = face
        faceColors[i] = {self.faceColors[i][1], self.faceColors[i][2], self.faceColors[i][3], self.faceColors[i][4]}
    end

    table.insert(self.buffer, {points, lines, faces, faceColors})
end

function Cool3d:loadFromBuffer()
    local bm = table.remove(self.buffer) -- pop last
    if not bm then return nil end -- Buffer is empty
    self:clear()
    local points, lines, faces, faceColors = bm[1], bm[2], bm[3], bm[4]

    for i, p in ipairs(points) do
        self.points[i] = {p[1], p[2], p[3]}
        self.lines[i] = {}
        if lines[i] then
            for _, l in ipairs(lines[i]) do
                table.insert(self.lines[i], l)
            end
        end
    end
    for i, f in ipairs(faces) do
        local face = {}
        for _, vi in ipairs(faces[i]) do
            table.insert(face, vi)
        end
        self.faces[i] = face
        self.faceColors[i] = {faceColors[i][1], faceColors[i][2], faceColors[i][3], faceColors[i][4]}
    end
end

function Cool3d:draw()
    self:drawModel()
    if self.host:drawAxisMarkerIsOn() then self:drawAxisMarker() end
end

function Cool3d:drawModel()
    if self.host:drawFacesIsOn() then self:drawFaces() end
    if self.host:drawLinesIsOn() then self:drawLines() end
    if self.host:drawVerticesIsOn() then self:drawVertices() end
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

function Cool3d:drawFaces()
    if not self.faces or #self.faces == 0 then return end

    -- build a list of face indices with depth
    local faceOrder = {}
    for i, face in ipairs(self.faces) do
        local depth = self:faceDepth(face)
        faceOrder[#faceOrder+1] = {i = i, depth = depth}
    end

    -- sort back to front, so nearer faces overwrite further ones
    table.sort(faceOrder, function(a,b) return a.depth > b.depth end)

    -- draw
    for _, f in ipairs(faceOrder) do
        local face = self.faces[f.i]
        local poly = {}

        local visible = true
        for _, vi in ipairs(face) do
            local s = self.drawScreen[vi]
            if not s then
                visible = false
                break
            end
            poly[#poly+1] = s[1]
            poly[#poly+1] = s[2]
        end

        if visible then
            local col = self.faceColors[f.i] or {0.4, 0.4, 0.8, 0.6}
            love.graphics.setColor(col[1], col[2], col[3], col[4])
            if self.selectedFaces[f.i] then 
                love.graphics.setColor(1-col[1], 1-col[2], 1-col[3], 1) 
            end
            love.graphics.polygon("fill", poly)
        end
    end

    love.graphics.setColor(1,1,1,1) -- reset
end

function Cool3d:drawLines()
    -- Draw lines by connection indices
    local drawn = {}

    love.graphics.setColor(1,1,1,1) -- white
    for i = 1, #self.lines do
        local a = self.drawScreen[i]
        local links = self.lines[i]

        if a and links then
            for _, k in ipairs(links) do
                local b = self.drawScreen[k]
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

function Cool3d:drawVertices()
    for i = 1, #self.drawScreen do
        if self.drawScreen[i] ~= nil then
            -- Text next to vertices
            local tScaling = self.zCompression*self.textScale/self.drawScreen[i][3]
            if self.selectedVertices[i] then
                if self.host:vertexNumberingIsOn() then
                    -- love.graphics.setColor(1,1,0,1) -- Yellow
                    love.graphics.setColor(0,1,0,1) -- Green
                    love.graphics.print(tostring(i), self.drawScreen[i][1], self.drawScreen[i][2], 0, tScaling, tScaling)
                    love.graphics.setColor(1,1,1,1)
                end
    
                if self.host:vertexCoordsIsOn() then
                    local text = string.format("%.2f", self.points[i][1]) .. " " ..
                        string.format("%.2f", self.points[i][2]) .. " " .. string.format("%.2f", self.points[i][3])
                    local yOffset = love.graphics.getFont():getHeight() * (tScaling)
                    --love.graphics.setColor(1,0.5,0,1) -- Orange
                    love.graphics.setColor(0,0.5,0,1) -- Darker green
                    love.graphics.print(text, self.drawScreen[i][1], self.drawScreen[i][2] + yOffset, 0, tScaling, tScaling)
                    love.graphics.setColor(1,1,1,1)
                end
            end
    
            -- The rectangles drawn at vertices
            local size = math.min(self.zCompression*self.host:getW()/(128*self.drawScreen[i][3]), 25)
            love.graphics.setColor(0,1,1,1) -- Cyan
            if self.selectedVertices[i] then love.graphics.setColor(0,1,0,1) end -- Green if selected
            love.graphics.rectangle("fill", self.drawScreen[i][1]-size/2, self.drawScreen[i][2]-size/2, size, size)
        end
    end
end

function Cool3d:faceDepth(face)
    local sum = 0
    local count = 0
    for _, vi in ipairs(face) do
        local p = self.pointsWorld[vi]
        if p then
            sum = sum + p[3]
            count = count + 1
        end
    end
    return count > 0 and sum / count or 0
end

function Cool3d:readFile(filename)
    if filename == nil then return "No filename given" end
	local contents, err = love.filesystem.read(filename)
	if not contents then return "Could not open file" end

    self:clear()
	--Separate lines
	for line in contents:gmatch("[^\r\n]+") do
        local firstChar = string.sub(line, 1, 1)
        if firstChar == "F" then -- A row containing face data
            -- Each row should be in form "r g b o i1 i2 i3 i4"
            local color = {}
            local facePoints = {}
            local i = 1
            for part in line:sub(2):gmatch("%S+") do
                if i > 4 then table.insert(facePoints, tonumber(part))
                else table.insert(color, tonumber(part)) end
                i = i + 1
            end
            table.insert(self.faceColors, color)
            table.insert(self.faces, facePoints)
        else -- Vertex and line data
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

    for i = 1, #self.faces, 1 do
        local f = self.faces[i]
        local r, g, b, o = tostring(self.faceColors[i][1]), tostring(self.faceColors[i][2]),
            tostring(self.faceColors[i][3]), tostring(self.faceColors[i][4])
        fileText = fileText .. "F " .. r .. " " .. g .. " " .. b .. " " .. o
        for j = 1, #self.faces[i], 1 do
            fileText = fileText .. " " .. tostring(self.faces[i][j])
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
    self.facesCB = {}
    self.faceColorsCB = {}

    -- Collect selected vertex indices
    local selectedIndices = {}
    local selectedSet = {}
    for i = 1, #self.points do
        if self.selectedVertices[i] then
            table.insert(selectedIndices, i)
            selectedSet[i] = true
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

    -- Copy faces whose all vertices are selected
    if self.faces and #self.faces > 0 then
        for fi, face in ipairs(self.faces) do
            local keepFace = true
            local newFace = {}

            for _, vi in ipairs(face) do
                if not selectedSet[vi] then
                    keepFace = false
                    break
                end
                table.insert(newFace, indexMap[vi])
            end

            if keepFace and #newFace >= 3 then
                table.insert(self.facesCB, newFace)
                if self.faceColors and self.faceColors[fi] then
                    table.insert(self.faceColorsCB, {
                        self.faceColors[fi][1],
                        self.faceColors[fi][2],
                        self.faceColors[fi][3],
                        self.faceColors[fi][4],
                    })
                else
                    table.insert(self.faceColorsCB, {1,1,1,1})
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

    -- Rebuild faces for the newly added vertices
    if self.facesCB and #self.facesCB > 0 then
        for fi, face in ipairs(self.facesCB) do
            local newFace = {}
            for _, vi in ipairs(face) do
                table.insert(newFace, baseIndex + vi)
            end

            table.insert(self.faces, newFace)

            if self.faceColorsCB and self.faceColorsCB[fi] then
                table.insert(self.faceColors, {
                    self.faceColorsCB[fi][1],
                    self.faceColorsCB[fi][2],
                    self.faceColorsCB[fi][3],
                    self.faceColorsCB[fi][4],
                })
            else
                table.insert(self.faceColors, {1,1,1,1})
            end
        end
    end
end

function Cool3d:clear()
    self.points = {}
    self.lines = {}
    self.faces = {}
    self.faceColors = {}
    self.selectedVertices = {}
    self.firstSelectedVert = nil
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

function Cool3d:addVertexOnPlane(vx, vy, plane, offset)
    local off = offset or 0
    if plane == "xz" or plane == "zx" then
        self:addVertex(vx, off, vy)
    elseif plane == "xy" or plane == "yx" then
        self:addVertex(vx, vy, off)
    elseif plane == "yz" or plane == "zy" then
        self:addVertex(off, vx, vy)
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

    -- Update faces
    local newFaces = {}
    local newColors = {}
    
    for fi, face in ipairs(self.faces) do
        local newFace = {}
        local keepFace = true
    
        for _, vi in ipairs(face) do
            if vi == number then
                keepFace = false
                break
            elseif vi > number then
                table.insert(newFace, vi - 1)
            else
                table.insert(newFace, vi)
            end
        end
    
        if keepFace and #newFace >= 3 then
            table.insert(newFaces, newFace)
            table.insert(newColors, self.faceColors[fi])
        end
    end
    
    self.faces = newFaces
    self.faceColors = newColors

    -- Remove the vertex itself
    table.remove(self.points, number)
end

function Cool3d:removeFace(index)
    if not self.faces or not self.faces[index] then
        return false, "Face index out of range"
    end

    -- Remove the face and its matching color entry
    table.remove(self.faces, index)
    if self.faceColors then
        table.remove(self.faceColors, index)
    end

    return true
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

function Cool3d:faceExistsBetween(points)
    -- Returns the index if a face has exactly matching vertex set with input points
    -- Else returns nil

    if not points or #points < 3 then return false end
    if not self.faces or #self.faces == 0 then return false end

    local targetCount = #points

    local pointSet = {}
    for _, idx in ipairs(points) do
        if pointSet[idx] then
            -- Duplicate vertex index in input
            return false
        end
        pointSet[idx] = true
    end

    for faceIndex, face in ipairs(self.faces) do
        -- Face must have exactly the same number of vertices
        if #face == targetCount then
            local match = true

            -- Every vertex in the face must appear in the input set
            for _, vi in ipairs(face) do
                if not pointSet[vi] then
                    match = false
                    break
                end
            end

            if match then
                return faceIndex
            end
        end
    end

    return nil
end

function Cool3d:addFace(points, r, g, b, o)
    if #points < 3 then return end
    local face = {}
    local existingReplica = self:faceExistsBetween(points)
    if existingReplica ~= nil then self:removeFace(existingReplica) end
    for _, p in ipairs(points) do
        table.insert(face, p)
    end
    table.insert(self.faces, face)
    table.insert(self.faceColors, {r,g,b,o})
end 

function Cool3d:addFaceForSelected(color)
    local selected = {}
    for i, isSelected in pairs(self.selectedVertices) do
        if isSelected and self.points[i] then
            table.insert(selected, i)
        end
    end

    if #selected < 3 then
        return "At least 3 selected verticesre required to form a face"
    end

    -- Try to order the using screen-space angles to avoid self-intersections
    local allHaveScreen = true
    for _, i in ipairs(selected) do
        if not self.screen[i] then
            allHaveScreen = false
            break
        end
    end

    local ordered = {}

    if allHaveScreen then
        -- Compute centroid in 2D screen space
        local cx, cy = 0, 0
        for _, i in ipairs(selected) do
            local s = self.screen[i]
            cx = cx + s[1]
            cy = cy + s[2]
        end
        cx = cx / #selected
        cy = cy / #selected

        -- Build list with angles
        local temp = {}
        for _, i in ipairs(selected) do
            local s = self.screen[i]
            local angle = math.atan2(s[2] - cy, s[1] - cx)
            table.insert(temp, { index = i, angle = angle })
        end

        table.sort(temp, function(a, b) return a.angle < b.angle end)

        for _, entry in ipairs(temp) do
            table.insert(ordered, entry.index)
        end
    else
        table.sort(selected)
        ordered = selected
    end

    local r, g, b, o = color[1], color[2], color[3], color[4]

    self:addFace(ordered, r, g, b, o)

    return "Face created from selected vertices"
end

function Cool3d:addCircle(centerX, centerY, centerZ, radius, plane, segments, connectLines, addFaces)
    local seg = segments or 16
    if seg < 3 then return "Atleast 3 segments required" end
    local connect = connectLines
    local makeFaces = addFaces
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

    if makeFaces then
        local circleFacePoints = {}
        for i = #self.points-#aux+1, #self.points, 1 do
            table.insert(circleFacePoints, i)
        end
        local color = self.host:getActiveColor()
        local red = color[1] or 1
        local green = color[2] or 1
        local blue = color[3] or 1
        local opaq = color[4] or 0.5
        self:addFace(circleFacePoints, red, green, blue, opaq)
    end

    return "Circle drawn"
end

function Cool3d:addSphere(cx, cy, cz, radius, segments, connectLines, addFaces)
    local connect = connectLines
    local makeFaces = addFaces
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

    if connect or makeFaces then
        local color = self.host:getActiveColor()
        local red = color[1] or 1
        local green = color[2] or 1
        local blue = color[3] or 1
        local opaq = color[4] or 0.5

        -- Triangles between latitude bands
        for lat = 1, seg - 2 do
            for lon = 0, seg - 1 do
                local a = index[lat][lon]
                local b = index[lat][(lon + 1) % seg]
                local c = index[lat + 1][lon]
                local d = index[lat + 1][(lon + 1) % seg]

                -- Connect / add face for first and second triangle
                if connect then
                    self:connect(a, b)
                    self:connect(b, c)
                    self:connect(c, a)

                    self:connect(b, d)
                    self:connect(d, c)
                    self:connect(c, b)
                end
                if makeFaces then
                    self:addFace({a, b, c}, red, green, blue, opaq)
                    self:addFace({b, d, c}, red, green, blue, opaq)
                end
            end
        end

        -- Top cap
        for lon = 0, seg - 1 do
            local a = index[1][lon]
            local b = index[1][(lon + 1) % seg]

            if connect then
                self:connect(top, a)
                self:connect(a, b)
                self:connect(b, top)
            end
            if makeFaces then
                self:addFace({top, a, b}, red, green, blue, opaq)
            end
        end

        -- Bottom cap
        for lon = 0, seg - 1 do
            local a = index[seg - 1][lon]
            local b = index[seg - 1][(lon + 1) % seg]

            if connect then
                self:connect(a, bottom)
                self:connect(bottom, b)
                self:connect(b, a)
            end
            if makeFaces then
                self:addFace({a, bottom, b}, red, green, blue, opaq)
            end
        end
    end

    return "Sphere added"
end

function Cool3d:addRectangle(x1, y1, x2, y2, plane, connectLines, addFaces)
    local verts = {}
    self:addVertexOnPlane(x1, y1, plane)
    self:addVertexOnPlane(x2, y1, plane)
    self:addVertexOnPlane(x2, y2, plane)
    self:addVertexOnPlane(x1, y2, plane)

    local lineIndex = #self.lines 
    if connectLines then
        self:connect(lineIndex-3, lineIndex-2)
        self:connect(lineIndex-2, lineIndex-1)
        self:connect(lineIndex-1, lineIndex)
        self:connect(lineIndex, lineIndex-3)
    end

    if addFaces then
        local c = self.host:getActiveColor()
        self:addFace({lineIndex-3, lineIndex-2, lineIndex-1, lineIndex}, c[1], c[2], c[3], c[4])
    end
end

function Cool3d:addRectangularCuboid(x1, y1, x2, y2, height, plane, connectLines, addFaces)
    local verts = {}
    self:addVertexOnPlane(x1, y1, plane)
    self:addVertexOnPlane(x2, y1, plane)
    self:addVertexOnPlane(x2, y2, plane)
    self:addVertexOnPlane(x1, y2, plane)

    self:addVertexOnPlane(x1, y1, plane, height)
    self:addVertexOnPlane(x2, y1, plane, height)
    self:addVertexOnPlane(x2, y2, plane, height)
    self:addVertexOnPlane(x1, y2, plane, height)

    local lineIndex = #self.lines 
    if connectLines then
        self:connect(lineIndex-7, lineIndex-6)
        self:connect(lineIndex-6, lineIndex-5)
        self:connect(lineIndex-5, lineIndex-4)
        self:connect(lineIndex-4, lineIndex-7)

        self:connect(lineIndex-3, lineIndex-2)
        self:connect(lineIndex-2, lineIndex-1)
        self:connect(lineIndex-1, lineIndex)
        self:connect(lineIndex, lineIndex-3)

        self:connect(lineIndex-7, lineIndex-3)
        self:connect(lineIndex-6, lineIndex-2)
        self:connect(lineIndex-5, lineIndex-1)
        self:connect(lineIndex-4, lineIndex)
    end

    if addFaces then
        local c = self.host:getActiveColor()
        self:addFace({lineIndex-7, lineIndex-6, lineIndex-5, lineIndex-4}, c[1], c[2], c[3], c[4])
        self:addFace({lineIndex-3, lineIndex-2, lineIndex-1, lineIndex}, c[1], c[2], c[3], c[4])
        self:addFace({lineIndex-7, lineIndex-6, lineIndex-2, lineIndex-3}, c[1], c[2], c[3], c[4])
        self:addFace({lineIndex-6, lineIndex-5, lineIndex-1, lineIndex-2}, c[1], c[2], c[3], c[4])
        self:addFace({lineIndex-5, lineIndex-4, lineIndex, lineIndex-1},  c[1], c[2], c[3], c[4])
        self:addFace({lineIndex-7, lineIndex-4, lineIndex, lineIndex-3}, c[1], c[2], c[3], c[4])
    end
end

function Cool3d:extrudeSelectedAroundPivot(px, py, pz, plane, segments)
    segments = segments or 1
    if segments < 2 then
        return "At least 2 segments required"
    end

    plane = plane or "xy"
    plane = string.lower(plane)

    if plane ~= "xy" and plane ~= "yx" and
       plane ~= "xz" and plane ~= "zx" and
       plane ~= "yz" and plane ~= "zy" then
        return "Plane parameter is incorrect"
    end

    -- Collect selected vertices
    local selectedIndices = {}
    local selectedSet = {}
    for i = 1, #self.points do
        if self.selectedVertices[i] then
            table.insert(selectedIndices, i)
            selectedSet[i] = true
        end
    end

    if #selectedIndices == 0 then
        return "No vertices selected"
    end

    -- Positions relative to pivot
    local relPos = {}
    for _, idx in ipairs(selectedIndices) do
        local v = self.points[idx]
        relPos[idx] = { v[1] - px, v[2] - py, v[3] - pz }
    end

    -- Faces to copy (all vertices selected)
    local facesToCopy = {}
    if self.faces and #self.faces > 0 then
        for fi, face in ipairs(self.faces) do
            local keepFace = true
            for _, vi in ipairs(face) do
                if not selectedSet[vi] then
                    keepFace = false
                    break
                end
            end
            if keepFace then
                table.insert(facesToCopy, fi)
            end
        end
    end

    -- Edges of the selection (for bridging faces)
    -- Each (i -> j) only once with i < j.
    local edges = {}
    for _, i in ipairs(selectedIndices) do
        local links = self.lines[i]
        if links then
            for _, j in ipairs(links) do
                if selectedSet[j] then
                    local a, b = i, j
                    if a > b then a, b = b, a end -- normalize
                    edges[a] = edges[a] or {}
                    edges[a][b] = true
                end
            end
        end
    end

    -- Flatten edge table into list { {i,j}, ... }
    local edgeList = {}
    for i, row in pairs(edges) do
        for j, _ in pairs(row) do
            table.insert(edgeList, {i, j})
        end
    end

    -- Create copies of vertices around pivot
    local angleStep = 2 * math.pi / segments

    -- indexMaps[layer][origIndex] = newIndex
    -- layer 0 is the original selection (no new vertices)
    local indexMaps = {}
    indexMaps[0] = {}
    for _, idx in ipairs(selectedIndices) do
        indexMaps[0][idx] = idx
    end

    for layer = 1, segments - 1 do
        local angle = angleStep * layer
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)

        local indexMap = {}

        for _, idx in ipairs(selectedIndices) do
            local rp = relPos[idx]
            local dx, dy, dz = rp[1], rp[2], rp[3]

            local rx, ry, rz
            if plane == "xy" or plane == "yx" then
                -- Rotate around Z
                rx =  cosA * dx - sinA * dy
                ry =  sinA * dx + cosA * dy
                rz =  dz
            elseif plane == "xz" or plane == "zx" then
                -- Rotate around Y
                rx =  cosA * dx - sinA * dz
                ry =  dy
                rz =  sinA * dx + cosA * dz
            elseif plane == "yz" or plane == "zy" then
                -- Rotate around X
                rx =  dx
                ry =  cosA * dy - sinA * dz
                rz =  sinA * dy + cosA * dz
            end

            local newX = px + rx
            local newY = py + ry
            local newZ = pz + rz

            table.insert(self.points, {newX, newY, newZ})
            local newIndex = #self.points
            self.lines[newIndex] = {}
            indexMap[idx] = newIndex
        end

        indexMaps[layer] = indexMap
    end

    -- Copy lines within each copy (so each ring has same internal edges)
    for layer = 1, segments - 1 do
        local indexMap = indexMaps[layer]
        for _, i in ipairs(selectedIndices) do
            local newI = indexMap[i]
            local origLinks = self.lines[i]
            if newI and origLinks then
                for _, j in ipairs(origLinks) do
                    if selectedSet[j] then
                        local newJ = indexMap[j]
                        if newJ then
                            table.insert(self.lines[newI], newJ)
                        end
                    end
                end
            end
        end
    end

    -- Copy faces for each copy (original faces swept around)
    if #facesToCopy > 0 then
        for layer = 1, segments - 1 do
            local indexMap = indexMaps[layer]
            for _, fi in ipairs(facesToCopy) do
                local origFace = self.faces[fi]
                local newFace = {}

                for _, vi in ipairs(origFace) do
                    local newVi = indexMap[vi]
                    if not newVi then
                        newFace = nil
                        break
                    end
                    table.insert(newFace, newVi)
                end

                if newFace and #newFace >= 3 then
                    table.insert(self.faces, newFace)
                    local col = self.faceColors[fi] or {1,1,1,1}
                    table.insert(self.faceColors, {col[1], col[2], col[3], col[4]})
                end
            end
        end
    end

    -- Bridge lines between consecutive layers (including last -> first)
    -- For each selected vertex, connect corresponding vertices on
    -- layer L and L+1, and finally layer (segments-1) back to 0.
    for _, idx in ipairs(selectedIndices) do
        for layer = 0, segments - 2 do
            local a = indexMaps[layer][idx]
            local b = indexMaps[layer + 1][idx]
            if a and b then
                table.insert(self.lines[a], b)
            end
        end

        -- Close the loop: last layer to original layer 0
        local last = indexMaps[segments - 1][idx]
        local first = indexMaps[0][idx] -- original
        if last and first then
            table.insert(self.lines[last], first)
        end
    end

    -- Bridge faces between layers using original edges
    -- For each original edge (i,j) and each pair of layers,
    -- create a quad: [i_L, j_L, j_(L+1), i_(L+1)]
    -- plus closing ring between last and first.
    local color = self.host:getActiveColor() or {1,1,1,1}
    local r, g, b, o =color[1] or 1, color[2] or 1,
        color[3] or 1, color[4] or 0.5

    -- Between layer L and L+1
    for _, edge in ipairs(edgeList) do
        local i, j = edge[1], edge[2]

        for layer = 0, segments - 2 do
            local iA = indexMaps[layer][i]
            local jA = indexMaps[layer][j]
            local iB = indexMaps[layer + 1][i]
            local jB = indexMaps[layer + 1][j]

            if iA and jA and iB and jB then
                self:addFace({iA, jA, jB, iB}, r, g, b, o)
            end
        end

        -- Close ring: last layer <-> original (0)
        local iLast = indexMaps[segments - 1][i]
        local jLast = indexMaps[segments - 1][j]
        local iFirst = indexMaps[0][i]
        local jFirst = indexMaps[0][j]

        if iLast and jLast and iFirst and jFirst then
            self:addFace({iLast, jLast, jFirst, iFirst}, r, g, b, o)
        end
    end

    return "Copied selection around pivot with bridges"
end

function Cool3d:extrudeSelectedTo(px, py, pz, autoselect)
    local selectedIndices = {}
    local selectedSet = {}
    local autoselectVertices = {}

    for i = 1, #self.points do
        if self.selectedVertices[i] then
            table.insert(selectedIndices, i)
            selectedSet[i] = true
        end
    end

    if #selectedIndices == 0 then
        return "No vertices selected"
    end

    -- Compute selection center and translation offset to target
    -- New copy will be translated so its center is at (px, py, pz)
    local xSum, ySum, zSum = 0, 0, 0
    for _, idx in ipairs(selectedIndices) do
        local v = self.points[idx]
        xSum = xSum + v[1]
        ySum = ySum + v[2]
        zSum = zSum + v[3]
    end

    local count = #selectedIndices
    local cx = xSum / count
    local cy = ySum / count
    local cz = zSum / count

    local offX = px - cx
    local offY = py - cy
    local offZ = pz - cz

    -- Build edge list within selection (unique edges i<j)
    local edges = {}
    for _, i in ipairs(selectedIndices) do
        local links = self.lines[i]
        if links then
            for _, j in ipairs(links) do
                if selectedSet[j] then
                    local a, b = i, j
                    if a > b then a, b = b, a end
                    edges[a] = edges[a] or {}
                    edges[a][b] = true
                end
            end
        end
    end

    local edgeList = {}
    for i, row in pairs(edges) do
        for j, _ in pairs(row) do
            table.insert(edgeList, {i, j})
        end
    end

    -- Determine faces fully inside selection (to duplicate)
    local facesToCopy = {}
    if self.faces and #self.faces > 0 then
        for fi, face in ipairs(self.faces) do
            local keepFace = true
            for _, vi in ipairs(face) do
                if not selectedSet[vi] then
                    keepFace = false
                    break
                end
            end
            if keepFace then
                table.insert(facesToCopy, fi)
            end
        end
    end

    -- Create translated copy of all selected vertices
    local indexMap = {}

    for _, idx in ipairs(selectedIndices) do
        local v = self.points[idx]
        local x, y, z = v[1], v[2], v[3]

        local newX = x + offX
        local newY = y + offY
        local newZ = z + offZ

        table.insert(self.points, {newX, newY, newZ})
        local newIndex = #self.points
        if autoselect then
            table.insert(autoselectVertices, newIndex)
        end
        self.lines[newIndex] = {}

        indexMap[idx] = newIndex
    end

    -- Copy internal lines into the new copy
    for _, i in ipairs(selectedIndices) do
        local newI = indexMap[i]
        local links = self.lines[i]

        if newI and links then
            for _, j in ipairs(links) do
                if selectedSet[j] then
                    local newJ = indexMap[j]
                    if newJ then
                        table.insert(self.lines[newI], newJ)
                    end
                end
            end
        end
    end

    -- Copy fully selected faces for the new copy
    if #facesToCopy > 0 then
        for _, fi in ipairs(facesToCopy) do
            local origFace = self.faces[fi]
            local newFace = {}

            for _, vi in ipairs(origFace) do
                local newVi = indexMap[vi]
                if not newVi then
                    newFace = nil
                    break
                end
                table.insert(newFace, newVi)
            end

            if newFace and #newFace >= 3 then
                table.insert(self.faces, newFace)
                local col = self.faceColors[fi] or {1,1,1,1}
                table.insert(self.faceColors, {col[1], col[2], col[3], col[4]})
            end
        end
    end

    -- Bridging lines: connect each original vertex to its copy
    for _, i in ipairs(selectedIndices) do
        local newI = indexMap[i]
        if newI then
            table.insert(self.lines[i], newI)
        end
    end

    -- Bridging faces: for each selected edge (i,j) add quad [i, j, newJ, newI]
    local color = self.host:getActiveColor() or {1,1,1,1}
    local r = color[1] or 1
    local g = color[2] or 1
    local b = color[3] or 1
    local o = color[4] or 0.5

    for _, edge in ipairs(edgeList) do
        local i, j = edge[1], edge[2]
        local newI = indexMap[i]
        local newJ = indexMap[j]

        if newI and newJ then
            self:addFace({i, j, newJ, newI}, r, g, b, o)
        end
    end

    if autoselect then
        -- Automatically replace selection with the newly created vertices
        self:deSelect()
        for _, vi in ipairs(autoselectVertices) do
            self:toggleVertexSelection(vi, true)
        end
    end

    return "Translated copy of selection to pivot with bridges created"
end

function Cool3d:deSelect()
    self.selectedVertices = {}
    self.firstSelectedVert = nil
    self.selectedFaces = {}
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

function Cool3d:toggleFaceSelectionWithinClick(x, y, val)
    if not self.faces or #self.faces == 0 then return end

    local bestFace = nil
    local bestDepth = nil

    for fi, face in ipairs(self.faces) do
        local poly = {}
        local depthSum = 0
        local count = 0
        local allHaveScreen = true

        -- Build 2D polygon from visible vertices
        for _, vi in ipairs(face) do
            local s = self.screen[vi]
            if not s then
                allHaveScreen = false
                break
            end
            poly[#poly + 1] = s[1]
            poly[#poly + 1] = s[2]
            depthSum = depthSum + s[3]
            count = count + 1
        end

        if allHaveScreen and count >= 3 then
            if self:isPointInPolygon(x, y, poly) then
                local depth = depthSum / count -- average depth for sorting

                -- Pick the closest face to camera (smallest depth)
                if (bestFace == nil) or (depth < bestDepth) then
                    bestFace = fi
                    bestDepth = depth
                end
            end
        end
    end

    if bestFace then
        self:toggleFaceSelection(bestFace, val)
    end
end

function Cool3d:toggleFaceSelectionWithinRectangle(x1, y1, x2, y2, val)
    if not self.faces or #self.faces == 0 then return end

    for fi, face in ipairs(self.faces) do
        local allHaveScreen = true
        local anyVertexInside = false

        for _, vi in ipairs(face) do
            local s = self.screen[vi]
            if not s then
                allHaveScreen = false
                break
            end

            if self:isWithinRectangle(x1, y1, x2, y2, s[1], s[2]) then
                anyVertexInside = true
                break
            end
        end

        -- Only consider faces that are visible (all vertices have screen coords)
        -- and have at least one vertex inside the rectangle.
        if allHaveScreen and anyVertexInside then
            self:toggleFaceSelection(fi, val)
        end
    end
end

function Cool3d:getFaceColorWithinClick(x, y)
    if not self.faces or #self.faces == 0 then return end

    local bestFace = nil
    local bestDepth = nil

    for fi, face in ipairs(self.faces) do
        local poly = {}
        local depthSum = 0
        local count = 0
        local allHaveScreen = true

        -- Build 2D polygon from visible vertices
        for _, vi in ipairs(face) do
            local s = self.screen[vi]
            if not s then
                allHaveScreen = false
                break
            end
            poly[#poly + 1] = s[1]
            poly[#poly + 1] = s[2]
            depthSum = depthSum + s[3]
            count = count + 1
        end

        if allHaveScreen and count >= 3 then
            if self:isPointInPolygon(x, y, poly) then
                local depth = depthSum / count -- average depth for sorting

                -- Pick the closest face to camera (smallest depth)
                if (bestFace == nil) or (depth < bestDepth) then
                    bestFace = fi
                    bestDepth = depth
                end
            end
        end
    end

    if bestFace then
        local fc = self.faceColors[bestFace]
        return {fc[1], fc[2], fc[3], fc[4]}
    end
end

function Cool3d:transformModel(dx, dy, dz)
    for i, p in ipairs(self.points) do
        local v = p
        local vx, vy, vz = v[1]+dx, v[2]+dy, v[3]+dz
        self.points[i] = {vx, vy, vz}
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
    for i=#self.faces, 1, -1 do
        if self.selectedFaces[i] then self:removeFace(i) end
    end
    self:deSelect()
end

function Cool3d:setSelectedFacesColor(color)
    for i, f in pairs(self.selectedFaces) do
        if f then self.faceColors[i] = color end
    end
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

function Cool3d:centerModel()
    local x, y, z = self:getModelCenter()
    self:transformModel(-x, -y, -z)
end

function Cool3d:getModelCenter()
    local xSum, ySum, zSum = 0, 0, 0
    local count = 0
    for _, p in pairs(self.points) do
       local x, y, z = p[1], p[2], p[3]
       xSum = xSum + x
       ySum = ySum + y
       zSum = zSum + z
       count = count + 1
    end
    if count == 0 then
        return 0, 0, 0
    end

    local xAvg = xSum / count
    local yAvg = ySum / count
    local zAvg = zSum / count
    return xAvg, yAvg, zAvg
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

function Cool3d:isPointInPolygon(px, py, poly)
    -- poly = {x1, y1, x2, y2, ..., xn, yn}
    local inside = false
    local n = #poly

    if n < 6 then return false end -- need at least 3 points

    local j = n - 1  -- last point's x index (y is at j+1 == n)
    for i = 1, n - 1, 2 do
        local xi, yi = poly[i], poly[i + 1]
        local xj, yj = poly[j], poly[j + 1]

        -- Ray-casting
        local intersect = ((yi > py) ~= (yj > py)) and
            (px < (xj - xi) * (py - yi) / ((yj - yi) + 1e-12) + xi)

        if intersect then
            inside = not inside
        end

        j = i
    end

    return inside
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
function Cool3d:getZCompression() return self.zCompression end
function Cool3d:getFaces() return self.faces end
function Cool3d:getFaceColors() return self.faceColors end
function Cool3d:getSelectedCount()
    local count = 0
    for i, isSelected in pairs(self.selectedVertices) do
        if isSelected and self.points[i] then
            count = count + 1
        end
    end
    for i, isSelected in pairs(self.selectedFaces) do
        if isSelected and self.faces[i] then
            count = count + 1
        end
    end
    return count
end

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

function Cool3d:toggleFaceSelection(number, val)
    if not val then
        -- Deselection is done this way as normally deselected faces
        -- are not stored at all in self.selectedFaces
        self.selectedFaces[number] = nil
        return nil
    end
    self.selectedFaces[number] = true
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