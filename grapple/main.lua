text = "No collision yet."

local newWorld = function()
	local self = love.physics.newWorld(2000, 2000)
	self:setGravity(0, 100)
	self:setCallback(collision)
	return self
end

local newGround = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 255, 0)
		love.graphics.polygon(love.draw_line, self.shape:getPoints())
	end
	self.body = love.physics.newBody(world, 0, 0, 0)
	self.shape = love.physics.newRectangleShape(self.body, 400, 500, 600, 10)
	self.shape:setData("Ground")
	return self
end

local newCircle = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(0, 0, 255)
		love.graphics.circle(love.draw_line, self.body:getX(), self.body:getY(), 28, 20)
	end
	self.body = love.physics.newBody(world, 300, 200)
	self.shape = love.physics.newCircleShape(self.body, 28)
	self.shape:setRestitution(0.5) -- More bounce
	self.shape:setData("Ball")
	self.body:setMassFromShapes()
	return self
end

local newHook = function()
	local self = {}
	function self:draw()
		love.graphics.setColor(255, 0, 255)
		love.graphics.polygon(love.draw_line, self.shaft:getPoints())
		love.graphics.polygon(love.draw_line, self.cross:getPoints())
		love.graphics.polygon(love.draw_line, self.left_tip:getPoints())
		love.graphics.polygon(love.draw_line, self.right_tip:getPoints())
	end
	self.body = love.physics.newBody(world, 400, 100)

	local shaft_v = {
		-50,   -5,  -- top left
		-50,    5,  -- bottom left
		 35.5,  5,  -- bototm right
		 51,    0,  -- tip (far right)
		 35.5, -5,  -- top right
	}
	self.shaft = love.physics.newPolygonShape(self.body, unpack(shaft_v))
	self.shaft:setData("Grapple Shaft")

	local cross_v = {
		24, -24,  -- top left
		35,   -24,  -- top right
		35,    24,  -- bottom right
		24,  24,  -- bottom left
	}
	self.cross = love.physics.newPolygonShape(self.body, unpack(cross_v))
	self.cross:setData("Grapple Cross Bar")

	local left_tip_v = {
		24, -24,
		35, -24,
		15, -37,
		24, -24,
	}
	self.left_tip = love.physics.newPolygonShape(self.body, unpack(left_tip_v))
	self.left_tip:setData("Grapple Left Tip")

	local right_tip_v = {
		24, 24,
		35, 24,
		15, 37,
		24, 24,
	}
	self.right_tip = love.physics.newPolygonShape(self.body, unpack(right_tip_v))
	self.right_tip:setData("Grapple Right Tip")

	self.body:setMassFromShapes()
	self.body:setMass(0, 0, self.body:getMass()*2, self.body:getInertia())
	return self
end

local newRope = function(segments)
	local self = {}
	function self:draw()
		local last = nil
		for i, segment in ipairs(self.segments) do
			love.graphics.setColor(i * 255 / #self.segments, 255, 0)
			love.graphics.polygon(love.draw_line, segment.shape:getPoints())
			--love.graphics.circle(love.draw_line, 
			--    segment.body:getX(), segment.body:getY(), 
			--	segment.shape:getRadius(), 8)
			--if last then
				--love.graphics.line(last.body:getX(), last.body:getY(), 
					--segment.body:getX(), segment.body:getY())
			--end
			last = segment
		end
	end

	self.segments = {}
	local last = ground
	for i = 1, segments do
		local body = love.physics.newBody(world, 400 + i*19, 25)
		--local shape = love.physics.newCircleShape(body, 1)
		local shape = love.physics.newRectangleShape(body, -1, 0, 20, 2)
		shape:setDensity(20)
		shape:setFriction(0.2)
		shape:setMaskBits(0xfffd)
		shape:setCategoryBits(0x0002)
		shape:setData("Rope")
		local joint = love.physics.newRevoluteJoint(last.body, body, 
			body:getX(), body:getY())
		joint:setLimitsEnabled(true)
		joint:setLimits(-45, 45)
		--joint:setMaxMotorTorque(10)
		last = { body = body, shape = shape, joint = joint }
		self.segments[i] = last

		body:setMassFromShapes()
		--body:setMass(0, 0, 0.00001, 10)
	end

	self.segments[1].joint:setLimitsEnabled(false)

	return self
end

local newGrapple = function()
	local self = {}
	self.body = love.physics.newBody(world, 400, 200)
	self.hook = newHook()
	self.rope = newRope(10)

	-- Connect the hook and the rope
	local last_segment = self.rope.segments[#self.rope.segments]
	last_segment.body:setX(self.hook.body:getX() - 65)
	last_segment.body:setY(self.hook.body:getY())
	--local joint = love.physics.newRevoluteJoint(last_segment.body, 
	    --self.hook.body, 
		--self.hook.body:getX() - 65,
		--self.hook.body:getY())
	--joint:setLimitsEnabled(true)
	--joint:setLimits(-45, 45)
	local joint = love.physics.newDistanceJoint(last_segment.body,
	    self.hook.body,
		last_segment.body:getX(),
		last_segment.body:getY(),
		self.hook.body:getX() - 30,
		self.hook.body:getY())

	function self:draw()
		self.hook:draw()
		self.rope:draw()
	end
	return self
end

local initFont = function()
	local font = love.graphics.newFont(love.default_font, 12)
	love.graphics.setFont(font)
end

function load()
	initFont()

	world = newWorld()
	ground = newGround()
	circle = newCircle()
	grapple = newGrapple()
end

function update(dt)
	world:update(dt)
	world:update(dt)
end

function draw()
	ground:draw()
	circle:draw()
	grapple:draw()

	-- text
	love.graphics.setColor(255, 255, 0)
	love.graphics.draw(text, 50, 50)
end

function keypressed(k)
	if k == love.key_space then
		circle.body:applyImpulse(1000000, -10000000)
	end
end

-- This is called every time a collision occurs.
function collision(a, b, contact)
	local f, r = contact:getFriction(), contact:getRestitution()
	local s = contact:getSeparation()
	local px, py = contact:getPosition()
	local vx, vy = contact:getVelocity()
	local nx, ny = contact:getNormal()

	text = "Last Collision:\n"
	text = text .. "Shapes: " .. a .. " and " .. b .. "\n"
	text = text .. "Position: " .. px .. "," .. py .. "\n"
	text = text .. "Velocity: " .. vx .. "," .. vy .. "\n"
	text = text .. "Normal: " .. nx .. "," .. ny .. "\n"
	text = text .. "Friction: " .. f .. "\n"
	text = text .. "Restitution: " .. r .. "\n"
	text = text .. "Separation: " .. s .. "\n"
end
