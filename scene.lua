local cconsole = require("console")
local Console = cconsole.Console
local cmodeler = require("modeler")
local Modeler = cmodeler.Modeler

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

	-- Position console to bottom third
	local consoleW = screenWidth
	local consoleH = screenHeight * (1 / 3)
	local consoleX = 0
	local consoleY = love.graphics.getHeight() - consoleH + yOffset

	self.console = Console.new(consoleX, consoleY, consoleW, consoleH, self)

	-- Position modeler to top two thirds minus y offset
	local modelerW = screenWidth
	local modelerH = screenHeight * (2 / 3)
	local modelerX = 0
	local modelerY = yOffset

	self.modeler = Modeler.new(modelerX, modelerY, modelerW, modelerH, self)
	return self
end

function Scene:update(dt)
	self.console:update(dt)
	self.modeler:update(dt)
end

function Scene:draw()
	self.modeler:draw()
	self.console:draw()
end

function Scene:keyPressed(key)
	self.console:keyPressed(key)
end

function Scene:textInput(t)
	self.console:textInput(t)
end

function Scene:mousePressed(mx, my, button)
end

return {Scene = Scene}