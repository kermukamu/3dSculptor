-- cool3d "class"
local Cool3d = {}
Cool3d.__index = Cool3d

function Cool3d.new(x2d, y2d, modelDistance, host)
	local self = setmetatable({}, Cool3d)
    self.host = host

	self.points = {} -- AKA vertices
	self.lines = {}
	self.lineWidth = 1 or 1
	self.dz = modelDistance
	self.angleXZ = 0
    self.angleYZ = 0
    self.rotSpeedXZ = 1
    self.rotSpeedYZ = 0
    self.timer = 0
    self.zSpeed = 0.2

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
        for j = 1, #self.lines[i] do
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

function Cool3d:translate_x(xyz, dx)
    local x = xyz[1]
    local y = xyz[2]
    local z = xyz[3]
    return {x + dx, y, z}
end

function Cool3d:translate_y(xyz, dy)
    local x = xyz[1]
    local y = xyz[2]
    local z = xyz[3]
    return {x, y + dy, z}
end

function Cool3d:translate_z(xyz, dz)
	local x = xyz[1]
	local y = xyz[2]
	local z = xyz[3]
	return {x, y, z + dz}
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

    local screen = {}
    local zvals  = {}

    for i = 1, #self.points do
        -- Rotations and translations
        local p = self:rotate_xz(self.points[i], self.angleXZ)
        p = self:rotate_yz(p, self.angleYZ)
        p = self:translate_z(p, self.dz)

        local z = p[3]
        zvals[i] = z

        local proj = {0, 0}
        if z and z > 0.001 then
            local proj = self:project(p)
            screen[i] = { cx + proj[1] * 250, cy + proj[2] * 250}
        else
            screen[i] = nil
        end

        -- Text next to vertices
        if self.host.vertexNumbering and z and z > 0.001 then
            local scaling = 1/(p[3] * self.dz)
            love.graphics.setColor(1,1,0,1)
            love.graphics.print(tostring(i), screen[i][1], screen[i][2], 0, scaling, scaling)
            love.graphics.setColor(1,1,1,1)
        end

        if self.host.vertexCoords and z and z > 0.001 then
            local scaling = 1/(p[3] * self.dz)
            local text = tostring(self.points[i][1]) .. " " ..
                tostring(self.points[i][2]) .. " " .. tostring(self.points[i][3])
            local yOffset = love.graphics.getFont():getHeight() * (scaling)
            love.graphics.setColor(1,0.5,0,1)
            love.graphics.print(text, screen[i][1], screen[i][2] + yOffset, 0, scaling, scaling)
            love.graphics.setColor(1,1,1,1)
        end
    end
 
    -- Draw lines by connection indices
    local drawn = {}

    for i = 1, #self.lines do
        local a = screen[i]
        local links = self.lines[i]

        if a and links then
            for _, k in ipairs(links) do
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

function Cool3d:drawAxis()
    love.graphics.setLineWidth(self.lineWidth)

    local w, h = love.graphics.getDimensions()
    local screen = {}
    local zvals  = {}

    local points = {{0, 0, 0}, {0.25, 0, 0}, {0, 0.25, 0}, {0, 0, 0.25}}
    local lines = {{2, 3, 4}}

    for i = 1, #points do
        -- Rotations and translations
        local p = self:rotate_xz(points[i], self.angleXZ)
        p = self:rotate_yz(p, self.angleYZ)
        p = self:translate_z(p, self.dz)

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

function Cool3d:connect(v1, v2)
    table.insert(self.lines[v1], v2)
end

return { Cool3d = Cool3d}