local cconsole = require("console")
local Console = cconsole.Console
local cmodeler = require("modeler")
local Modeler = cmodeler.Modeler
local cpanel2d = require("panel2d")
local Panel2d = cpanel2d.Panel2d
local cswitchbar = require("switchbar")
local Switchbar = cswitchbar.Switchbar
local ctoolbar = require("toolbar")
local Toolbar = ctoolbar.Toolbar
local ccolortool = require("colortool")
local ColorTool = ccolortool.ColorTool

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
	self.drawLines = true
	self.drawFaces = true
	self.toolMode = "selection"
	self.subMode = "rectangle"
	self.circleSegments = 64
	self.sphereSegments = 12
	self.activeColor = {0.4, 0.4, 0.8, 0.6} -- Default

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

	-- Position flag switch bar on top of modeler
	local switchbarIconSize = screenHeight * (1 / 32)
	local switchbarX = modelerX + modelerW/8
	local switchbarY = modelerY
	self.switchbar = Switchbar.new(switchbarX, switchbarY, switchbarIconSize, self)

	-- Position Toolbar on top right section of modeler
	local toolbarIconSize = screenWidth * (1 / 32)
	local toolbarX = modelerX + modelerW - toolbarIconSize - self.modeler:getFrameLineWidth()*2
	local toolbarY = modelerY
	self.toolbar = Toolbar.new(toolbarX, toolbarY, toolbarIconSize, self)

	-- Position color tool on bottom right corner of modeler
	local colorToolIconSize = screenWidth * (1 / 32)
	local colorToolX = modelerX + modelerW - colorToolIconSize - self.modeler:getFrameLineWidth()*2
	local colorToolY = modelerY + modelerH - colorToolIconSize - self.modeler:getFrameLineWidth()*2 - yOffset
	self.colorTool = ColorTool.new(colorToolX, colorToolY, colorToolIconSize, self)

	self.keyActions = {
		["delete"] = {function() self:getCurrentModel():deleteSelected() end, "Deletes current selection"},
		["c"] = {function() self:byActionC() end, "Use while holding left ctrl to copy selected"},
		["s"] = {function() self:byActionTurnSelectionModeOn() end, "Turns selection mode on"},
		["v"] = {function() self:byActionV() end, "Turns vertex mode on"},
		["j"] = {function() self:byActionJ() end, "Joins selected vertices or disconnects them if left alt is held down"},
		["f"] = {function() self:byActionF() end, "Creates a face between selected vertices"},
		["e"] = {function() self:byActionTurnMoveModeOn() end, "Turns move selected mode on"},
		["a"] = {function() self:selectAllModel() end, "Selects all"},
		["escape"] = {function() self:deSelectAll() end, "Deselects all"}
    }

	self.activeSection = self.modeler

	-- Load example model
	self:getCurrentModel():readFile("3d/gem.txt")
	return self
end

function Scene:update(dt)
	self.console:update(dt)
	self.modeler:update(dt)
	self.xzPanel:update(dt)
	self.xyPanel:update(dt)
	self.yzPanel:update(dt)
	self.switchbar:update(dt)
	self.toolbar:update(dt)
	self.colorTool:update(dt)
	self.activeColor = self.colorTool:getSelectedColor()
end

function Scene:draw()
	self.modeler:draw()
	self.xzPanel:draw()
	self.xyPanel:draw()
	self.yzPanel:draw()
	self.console:draw()
	self.switchbar:draw()
	self.toolbar:draw()
	self.colorTool:draw()
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
	if self.switchbar:isWithinSection(mx, my) then
		self.activeSection = self.switchbar
	elseif self.toolbar:isWithinSection(mx, my) then
		self.activeSection = self.toolbar
	elseif self.colorTool:isWithinSection(mx, my) then
		self.activeSection = self.colorTool
	elseif self:isWithinSection(mx, my, self.modeler.x, self.modeler.y,
		self.modeler.w, self.modeler.h) then
		self.activeSection = self.modeler
	elseif self:isWithinSection(mx, my, self.xzPanel.x, self.xzPanel.y,
		self.xzPanel.w, self.xzPanel.h) then
		self.activeSection = self.xzPanel
	elseif self:isWithinSection(mx, my, self.xyPanel.x, self.xyPanel.y,
		self.xyPanel.w, self.xyPanel.h) then
		self.activeSection = self.xyPanel
	elseif self:isWithinSection(mx, my, self.yzPanel.x, self.yzPanel.y,
		self.yzPanel.w, self.yzPanel.h) then
		self.activeSection = self.yzPanel
	elseif self:isWithinSection(mx, my, self.console.x, self.console.y,
		self.console.w, self.console.h) then
		self.activeSection = self.console
	else
		self.activeSection = nil
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

function Scene:byActionV()
	if love.keyboard.isDown("lctrl") then
		if self.activeSection and self.activeSection.paste then
			self.activeSection:paste()
		end
	else
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
end

function Scene:byActionC()
	if love.keyboard.isDown("lctrl") then
		if self.activeSection and self.activeSection.copy then
			self.activeSection:copy()
		end
	end
end

function Scene:byActionJ()
	if love.keyboard.isDown("lalt") then
		self:getCurrentModel():disconnectSelected()
	else
		self:getCurrentModel():joinSelected()
	end
end

function Scene:byActionF()
	self:getCurrentModel():addFaceForSelected(self.activeColor)
end

function Scene:byActionTurnSelectionModeOn()
	self.toolMode = "selection"
	self.subMode = "rectangle"
end

function Scene:byActionTurnMoveModeOn()
	self.toolMode = "move selected"
		-- If already in any vertex submode, shift submode forward
	if self.subMode == "translate" then 
		self.subMode = "rotate"
	else 
		self.subMode = "translate"
	end
end
-- Getters and setters

function Scene:vertexNumberingIsOn() return self.vertexNumbering end
function Scene:vertexCoordsIsOn() return self.vertexCoords end
function Scene:drawVerticesIsOn() return self.drawVertices end
function Scene:drawLinesIsOn() return self.drawLines end
function Scene:drawFacesIsOn() return self.drawFaces end
function Scene:drawAxisMarkerIsOn() return self.drawAxisMarker end

function Scene:getToolMode() return self.toolMode end
function Scene:getSubToolMode() return self.subMode end
function Scene:getActiveSection() return self.activeSection end
function Scene:getCircleSegments() return self.circleSegments end
function Scene:getSphereSegments() return self.sphereSegments end
function Scene:getActiveColor() return self.activeColor end

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
function Scene:setDrawLines(value) self.drawLines = value end
function Scene:setDrawFaces(value) self.drawFaces = value end
function Scene:setDrawAxis(value) self.drawAxisMarker = value end
function Scene:setToolMode(mode) self.toolMode = mode end
function Scene:setSubToolMode(mode) self.subMode = mode end


return {Scene = Scene}