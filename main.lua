local cscene = require("scene")
local Scene = cscene.Scene

function love.load()
	local title = "3DSCulptor"
	local screenWidth = 1000
	local screenHeight = 1000
	scene = Scene.new(title, screenWidth, screenHeight)
end

function love.update(dt)
	scene:update(dt)
end

function love.textinput(t)
	scene:textInput(t)
end

function love.keypressed(key)
	scene:keyPressed(key)
end

function love.mousepressed(mx, my, button)
	scene:mousePressed(mx, my, button)
end

function love.draw()
	scene:draw()
end