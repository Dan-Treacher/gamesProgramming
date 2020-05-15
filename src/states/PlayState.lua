--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    -- This block are all fields of params because they're retrieved from the input to servestate:change parameter table
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {params.ball} -- Setup a table to hold the ball(s) because we may have more than one
    self.powerups = {} -- Setup a table to hold the powerups(s) because we may have more than one
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    -- The starting ball is .balls[1]
    self.balls[1].dx = math.random(-200, 200)  -- This is the initial state, so we'll have only one ball which is at position [1] in the table
    self.balls[1].dy = math.random(-50, -60)

    self.hasKey = false
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    -- Update the positions of all balls in play
    for k, ball in pairs(self.balls) do
        ball:update(dt)
    end

    -- Update the positions of all powerups in play
    for k, powerup in pairs(self.powerups) do
        powerup:update(dt)
    end




    for k, powerup in pairs(self.powerups) do

        -- if the powerup collides with the paddle then remove it from the table (so it's no longer rendered)
        if powerup:collides(self.paddle) then
            if powerup.skin == 9 then
               -- Remove the powerup from the table
                table.remove(self.powerups, k)  -- arg2 is the key for which powerup to remove (as in the one that's collided with the paddle)

                b = Ball(math.random(1,7))  -- Instantiate the Ball object with random skin for any of the seven sprites
                b.x = self.paddle.x + self.paddle.width/2
                b.y = self.paddle.y + 10
                b.dx = math.random(-200, 200)  -- This is the initial state, so we'll have only one ball which is at position [1] in the table
                b.dy = math.random(-50, -60)
                table.insert(self.balls, b)  -- Upon collision of the powerup and the paddle, spawn another ball with it's default parameters
            else
                self.hasKey = true
                table.remove(self.powerups, k)
            end
        end

        -- if the powerup leaves the play area then remove it to avoid the self.powerups table from getting too large
        if powerup.y >= VIRTUAL_HEIGHT then
            table.remove(self.powerups, k)
        end

    end




    for k, ball in pairs(self.balls) do

    if ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        ball.y = self.paddle.y - 8
        ball.dy = -ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

        -- if we hit the paddle on its left side while moving left...
        if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
            ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
        
        -- else if we hit the paddle on its right side while moving right...
        elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
            ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
        end

        gSounds['paddle-hit']:play()
    end

    end





    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        for j, ball in pairs(self.balls) do

        -- only check collision if we're in play
        if brick.inPlay and ball:collides(brick) then


            -- Unlock the brick if you have the key
            if (brick.locked == 1) and (self.hasKey == true) then
                brick.locked = 0
            end


            if brick.locked == 0 then
                
                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- Calculate random number to see which powerup is spawned
                powerupRandomiser = math.random(1,1)
                local p = nil
                if powerupRandomiser == 1 then  -- Randomise the chance of a collision producing a powerup. Set scalar according to generosity
                    gSounds['recover']:play()
                    if self.hasKey == false then  -- If you already have a key, don't bother generating more
                        key = math.random(1, 10)
                        if key == 10 then
                            p = Powerup(key) -- Remember to include this in the dependencies file or it won't know what this class is
                        else
                            p = Powerup(9)
                        end
                        
                    else
                        p = Powerup(9)
                    end
                    -- Need to tell it where to spawn (p.x, p.y) because these are used in the update function, and not set in the initialisation hence it'll crash when looking for those values
                    p.x = brick.x
                    p.y = brick.y

                    table.insert(self.powerups, p)
                end

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health and grow the paddle by on size
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()

                    -- Increment paddle size upwards
                    self.paddle.size = self.paddle.size + 1
                    self.paddle.size = math.min(self.paddle.size, 4)  -- There are only 4 available paddle sizes
                    -- Note the update in the paddle class that handles updating the hitbox size according to self.paddle.size
                end

            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.balls,
                    recoverPoints = self.recoverPoints
                })
            end

            --
            -- collision code for bricks
            --
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 
            --

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if ball.x + 2 < brick.x and ball.dx > 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x - 8
            
            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x + 32
            
            -- top edge if no X collisions, always check
            elseif ball.y < brick.y then
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y - 8
            
            -- bottom edge if no X collisions or top collision, last possibility
            else
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(ball.dy) < 150 then
                ball.dy = ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end

        end

    end

    


    -- if ball goes below bounds, revert to serve state and decrease health
    for k, ball in pairs(self.balls) do

        if ball.y >= VIRTUAL_HEIGHT then

        --if #self.balls > 1 then -- If there is more than one ball in the balls table
        --    table.remove(self.balls, k)

            if #self.balls == 1 then
                self.health = self.health - 1
                gSounds['hurt']:play()

                -- Decrease paddle size
                self.paddle.size = self.paddle.size - 1
                self.paddle.size = math.max(self.paddle.size, 1)  -- Don't want to index 0
                 -- Note the update in the paddle class that handles updating the hitbox size according to self.paddle.size

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            
            else

                table.remove(self.balls, k) -- if there is more than one ball in play, just remove it from the table

            end

        end

    end







    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    -- Need to loop over all the balls in play
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    -- Need to loop over all powerups in play
    for k, powerup in pairs(self.powerups) do
        powerup:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    if self.hasKey == true then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][10], VIRTUAL_WIDTH-117, 1)
    end

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end