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
	self.angleXZ = 0
    self.angleYZ = 0
    self.rotSpeedXZ = 0.2
    self.rotSpeedYZ = 0
    self.timer = 0
    self.zSpeed = 0.2

    self.screen = {}
    self.zvals  = {}
    self.selectedVertices = {}

    self.x2d = x2d or 0
    self.y2d = y2d or 0
    self.axisX = 250
    self.axisY = 250
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

function Cool3d:rotate_xz(xyz, angle)
	local x = xyz[1]
	local y = xyz[2]
	local z = xyz[3]
    local c = math.cos(angle);
    local s = math.sin(angle);
    return {x*c - z*s, y, x*s + z*c}
end

function Cool3d:rotate_yz(xyz, angle)
    local x = xyz[1]
    local y = xyz[2]
    local z = xyz[3]
    local c = math.cos(angle);
    local s = math.sin(angle);
    return {x, y*c - z*s, y*s + z*c}
end

function Cool3d:update(dt)
    self.timer = self.timer + 1 * dt
    --self.dz = math.sin(self.zSpeed * self.timer) + 3
    self.angleXZ = (self.angleXZ + math.pi * self.rotSpeedXZ * dt)
    self.angleYZ = (self.angleYZ + math.pi * self.rotSpeedYZ * dt)
end

function Cool3d:draw()
    self:drawModel()
    if self.host.drawAxis then self:drawAxis() end
end

function Cool3d:drawModel()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(self.lineWidth)

    local w, h = love.graphics.getDimensions()
    local cx, cy = self.x2d, self.y2d

    -- Screen and zvals will be reset every time the model is drawn. 
    -- The table will have the transformed, rotated and projected vertices (2D)
    -- The z values of transformed vertices are also stored in self as they are needed elsewhere
    self.screen = {}
    self.zvals  = {}

    for i = 1, #self.points do
        -- Rotations and translations
        local p = self:rotate_xz(self.points[i], self.angleXZ)
        p = self:rotate_yz(p, self.angleYZ)
        p = self:translate_xyz(p, {self.dx, self.dy, self.dz})

        local z = p[3]
        self.zvals[i] = z

        local proj = {0, 0}
        if z and z > 0.001 then
            local proj = self:project(p)
            self.screen[i] = { cx + proj[1] * 250, cy + proj[2] * 250}
        else
            self.screen[i] = nil
        end

        -- Text next to vertices
        if self.host.vertexNumbering and z and z > 0.001 then
            local scaling = 1/(p[3] * self.dz)
            love.graphics.setColor(1,1,0,1)
            if self.selectedVertices[i] then love.graphics.setColor(0,1,0,1) end -- Green if vertex is selected
            love.graphics.print(tostring(i), self.screen[i][1], self.screen[i][2], 0, scaling, scaling)
            love.graphics.setColor(1,1,1,1)
        end

        if self.host.vertexCoords and z and z > 0.001 then
            local scaling = 1/(p[3] * self.dz)
            local text = tostring(self.points[i][1]) .. " " ..
                tostring(self.points[i][2]) .. " " .. tostring(self.points[i][3])
            local yOffset = love.graphics.getFont():getHeight() * (scaling)
            love.graphics.setColor(1,0.5,0,1)
            if self.selectedVertices[i] then love.graphics.setColor(0,0.5,0,1) end -- Darker green if vertex is selected
            love.graphics.print(text, self.screen[i][1], self.screen[i][2] + yOffset, 0, scaling, scaling)
            love.graphics.setColor(1,1,1,1)
        end
    end
 
    -- Draw lines by connection indices
    local drawn = {}

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

function Cool3d:drawAxis()
    love.graphics.setLineWidth(self.lineWidth)

    local w, h = love.graphics.getDimensions()
    local screen = {} -- Unlike in drawModel(), locals are used
    local zvals  = {}

    local points = {{0, 0, 0}, {0.25, 0, 0}, {0, 0.25, 0}, {0, 0, 0.25}}
    local lines = {{2, 3, 4}}

    for i = 1, #points do
        -- Rotations and translations
        local p = self:rotate_xz(points[i], self.angleXZ)
        p = self:rotate_yz(p, self.angleYZ)
        p = self:translate_xyz(p, {self.dx, self.dy, self.dz})

        local z = p[3]
        zvals[i] = z

        local proj = {0, 0}
        if z and z > 0.001 then
            local proj = self:project(p)
            screen[i] = {self.axisX + proj[1] * 250, self.axisY + proj[2] * 250}
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

function Cool3d:addVertex(x, y, z)
    table.insert(self.points, {x, y, z})
    table.insert(self.lines, {})
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
    local connect = connectLines or true
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

function Cool3d:mousePressed(mx, my, button)
    if not love.keyboard.isDown("lshift") then self:deSelect() end
    if button == 1 then -- left click
        self:selectVerticesWithin(mx, my)
    end
end

function Cool3d:deSelect()
    self.selectedVertices = {}
end

function Cool3d:selectVerticesWithin(x, y)
    for i=1, #self.screen, 1 do
        if self.screen[i] == nil then 
            -- Silly lua doesn't support continue...
        elseif self:isWithinCircle(x, y, self.screen[i][1], self.screen[i][2], 15/self.zvals[i]) then
            self.selectedVertices[i] = true
        end
    end
end

function Cool3d:isWithinCircle(px, py, cx, cy, r)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (r * r)
end

function Cool3d:deleteSelected()
    for i=1, #self.points, 1 do
        if self.selectedVertices[i] then self:removeVertex(i) end
    end
    self:deSelect()
end

function Cool3d:joinToFirstSelected()
    local firstVert = nil
    local otherV = {}
    for k, v in pairs(self.selectedVertices) do
        if v == true and (firstVert == nil) then
            firstVert = k
        elseif v == true then
            self:connect(firstVert, k)
        end
    end
end

return { Cool3d = Cool3d}