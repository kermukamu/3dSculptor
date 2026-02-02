local cconsole = require("console")
local Console = cconsole.Console
local cmodeler = require("modeler")
local Modeler = cmodeler.Modeler
local cpanel2d = require("panel2d")
local Panel2d = cpanel2d.Panel2d
local ctoolbar = require("toolbar")
local Toolbar = ctoolbar.Toolbar

-- Scene "class"
local Scene = {}
Scene.__index = Scene

function Scene.new(title, screenWidth, screenHeight)
	local self = setmetatable({}, Scene)

	-- Setup window
	love.window.setTitle(title)
    love.window.setMode(screenWidth, screenHeight)
    love.graphics.setBackgroundColor(0, 0, 0, 0) -- Black
    love.graphics.setDefaultFilter("nearest", "nearest")

    local yOffset = 10

    -- Flags
	self.vertexNumbering = true
	self.vertexCoords = true
	self.drawAxisMarker = true
	self.drawVertices = true
	self.toolMode = "selection"
	self.subMode = "rectangle"
	self.circleSegments = 64
	self.sphereSegments = 12

	-- Position console to bottom third
	local consoleW = screenWidth
	local consoleH = screenHeight * (1 / 3)
	local consoleX = 0
	local consoleY = love.graphics.getHeight() - consoleH + yOffset
	self.console = Console.new(consoleX, consoleY, consoleW, consoleH, self)

	-- Position 3d modeler to top left third
	local modelerW = screenWidth * (1 / 2)
	local modelerH = screenHeight * (1 / 3)
	local modelerX = 0
	local modelerY = yOffset
	self.modeler = Modeler.new(modelerX, modelerY, modelerW, modelerH, self)

	-- Position XZ 2D panel to top right third
	local xzPanelW = screenWidth * (1 / 2)
	local xzPanelH = screenHeight * (1 / 3)
	local xzPanelX = love.graphics.getWidth() - xzPanelW
	local xzPanelY = yOffset
	self.xzPanel = Panel2d.new(xzPanelX, xzPanelY, xzPanelW, xzPanelH, "xz", self)

	-- Position XY 2D panel to middle left third
	local xyPanelW = screenWidth * (1 / 2)
	local xyPanelH = screenHeight * (1 / 3)
	local xyPanelX = 0
	local xyPanelY = love.graphics.getHeight()/2 - xyPanelH/2 + yOffset
	self.xyPanel = Panel2d.new(xyPanelX, xyPanelY, xyPanelW, xyPanelH, "xy", self)

	-- Position YZ 2D panel to middle right third
	local yzPanelW = screenWidth * (1 / 2)
	local yzPanelH = screenHeight * (1 / 3)
	local yzPanelX = love.graphics.getWidth() - yzPanelW
	local yzPanelY = love.graphics.getHeight()/2 - yzPanelH/2 + yOffset
	self.yzPanel = Panel2d.new(yzPanelX, yzPanelY, yzPanelW, yzPanelH, "yz", self)

	-- Position Toolbar on top section of modeler
	local toolbarIconSize = screenWidth * (1 / 32)
	local toolbarX = modelerX + modelerW - toolbarIconSize - self.modeler:getFrameLineWidth()*2
	local toolbarY = modelerY
	self.toolbar = Toolbar.new(toolbarX, toolbarY, toolbarIconSize, self)

	self.keyActions = {
		["delete"] = {function() self:getCurrentModel():deleteSelected() end, "Deletes current selection"},
		["c"] = {function() self:getCurrentModel():joinSelectedToNearestSelected() end, "Connects each selected vertex to nearest selected vertex"},
		["s"] = {function() self:byActionTurnSelectionModeOn() end, "Turns selection mode on"},
		["v"] = {function() self:byActionTurnVertexModeOn() end, "Turns vertex mode on"},
		["e"] = {function() self:byActionTurnMoveModeOn() end, "Turns move mode on"},
		["a"] = {function() self:selectAllModel() end, "Selects all"},
		["escape"] = {function() self:deSelectAll() end, "Deselects all"}
    }

	self.activeSection = self.modeler
	return self
end

function Scene:update(dt)
	self.console:update(dt)
	self.modeler:update(dt)
	self.xzPanel:update(dt)
	self.xyPanel:update(dt)
	self.yzPanel:update(dt)
	self.toolbar:update(dt)
end

function Scene:draw()
	self.modeler:draw()
	self.xzPanel:draw()
	self.xyPanel:draw()
	self.yzPanel:draw()
	self.console:draw()
	self.toolbar:draw()
end

function Scene:keyPressed(key)
	if getmetatable(self.activeSection).__index == Console then
		self.activeSection:keyPressed(key)
	else
		local action = self:getModelerKeyActions()[key]
		if action then action[1]() end 
	end
end

function Scene:textInput(t)
	if self.activeSection and self.activeSection.textInput then
		self.activeSection:textInput(t)
	end
end

function Scene:mousePressed(mx, my, button)
	if self:isWithinSection(mx, my, self.modeler.x, self.modeler.y,
		self.modeler.w, self.modeler.h) then
		self.activeSection = self.modeler
	end
	if 
		self:isWithinSection(mx, my, self.xzPanel.x, self.xzPanel.y,
		self.xzPanel.w, self.xzPanel.h) then
		self.activeSection = self.xzPanel
	end
	if
		self:isWithinSection(mx, my, self.xyPanel.x, self.xyPanel.y,
		self.xyPanel.w, self.xyPanel.h) then
		self.activeSection = self.xyPanel
	end
	if
		self:isWithinSection(mx, my, self.yzPanel.x, self.yzPanel.y,
		self.yzPanel.w, self.yzPanel.h) then
		self.activeSection = self.yzPanel
	end
	if
		self:isWithinSection(mx, my, self.console.x, self.console.y,
		self.console.w, self.console.h) then
		self.activeSection = self.console
	end
	if
		self.toolbar:isWithinSection(mx, my) then
		self.activeSection = self.toolbar
	end
	if self.activeSection and self.activeSection.mousePressed then
		self.activeSection:mousePressed(mx, my, button)
	end
end

function Scene:mouseReleased(mx, my, button)
	if self.activeSection and self.activeSection.mouseReleased then
		self.activeSection:mouseReleased(mx, my, button)
	end
end

function Scene:mouseMoved(x, y, dx, dy)
	if self.activeSection and self.activeSection.mouseMoved then
		self.activeSection:mouseMoved(x, y, dx, dy)
	end
end

function Scene:wheelMoved(x, y)
	if self.activeSection and self.activeSection.wheelMoved then
		self.activeSection:wheelMoved(x, y)
	end
end

function Scene:isWithinSection(x, y, secX, secY, secW, secH)
	return (secX < x and x < (secX + secW)) and
			(secY < y and y < (secY + secH))
end

function Scene:selectAllModel()
	return self.modeler:selectAll()
end

function Scene:deSelectAll()
	return self.modeler:deSelectAll()
end

function Scene:byActionTurnVertexModeOn()
	self.toolMode = "vertex"

	-- If already in any vertex submode, shift submode forward
	if self.subMode == "single" then 
		self.subMode = "circle"
	elseif self.subMode == "circle" then 
		self.subMode = "sphere"
	else 
		self.subMode = "single"
	end
end

function Scene:byActionTurnSelectionModeOn()
	self.toolMode = "selection"
	self.subMode = "rectangle"
end

function Scene:byActionTurnMoveModeOn()
	self.toolMode = "move"
	self.subMode = "selected"
end
-- Getters and setters

function Scene:vertexNumberingIsOn() return self.vertexNumbering end
function Scene:vertexCoordsIsOn() return self.vertexCoords end
function Scene:drawVerticesIsOn() return self.drawVertices end
function Scene:drawAxisMarkerIsOn() return self.drawAxisMarker end

function Scene:getToolMode() return self.toolMode end
function Scene:getSubToolMode() return self.subMode end
function Scene:getActiveSection() return self.activeSection end
function Scene:getCircleSegments() return self.circleSegments end
function Scene:getSphereSegments() return self.sphereSegments end

function Scene:getCurrentModel()
	if self.modeler ~= nil then
		return self.modeler:getCurrentModel()
	else 
		return nil 
	end
end

function Scene:getModelerKeyActions()
	if self.modeler ~= nil then
		return self.keyActions
	else 
		return nil 
	end
end

function Scene:setVertexNumbering(value) self.vertexNumbering = value end
function Scene:setVertexCoords(value) self.vertexCoords = value end
function Scene:setDrawVertices(value) self.drawVertices = value end
function Scene:setDrawAxis(value) self.drawAxis = value end
function Scene:setToolMode(mode) self.toolMode = mode end
function Scene:setSubToolMode(mode) self.subMode = mode end


return {Scene = Scene}