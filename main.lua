--[[
    GD50 2018
    Pong Remake

    -- Main Program --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Originally programmed by Atari in 1972. Features two
    paddles, controlled by players, with the goal of getting
    the ball past your opponent's edge. First to 10 points wins.

    This version is built to more closely resemble the NES than
    the original Pong machines or the Atari 2600 in terms of
    resolution, though in widescreen (16:9) so it looks nicer on 
    modern systems.
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

require 'Line'

-- size of our actual window
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- paddle movement speed
PADDLE_SPEED = 200

PADDLE_WIDTH = 5
PADDLE_HEIGHT = 40

FIRST_POINT = false
ballX = nil
ballY = nil

COUNTER = 0

SECOND_POINT = false
secondBallX = nil
secondBallY = nil

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]

function love.load()
    -- seteo el tipo de interpolación de los gráficos
    love.graphics.setDefaultFilter('linear', 'nearest')

    -- seteo el título de la ventana del juego
    love.window.setTitle('Hello Pong!')

    -- defino fuente y tamaño de letra

    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- Efectos de sonido
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }

    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true
    })

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(10, VIRTUAL_HEIGHT/2 - 10, PADDLE_WIDTH, PADDLE_HEIGHT)
    player2 = Paddle(VIRTUAL_WIDTH - 15, VIRTUAL_HEIGHT/2 - 10, PADDLE_WIDTH, PADDLE_HEIGHT)
    -- button = Button(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT/2 - 10, 5, 40)

    -- place a ball in the middle of the screen (x, y, ancho y alto)
    ball = Ball(VIRTUAL_WIDTH / 2 - 8, VIRTUAL_HEIGHT / 2 - 8, 16, 16)

    -- initialize score variables
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- player who won the game; not set to a proper value until we reach
    -- that state in the game
    winningPlayer = 0

    -- the state of our game; can be any of the following:
    -- 0. 'open' (Acá quiero elegir la dificultad para variar la velocidad y el tamaño del paddle)
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    gameState = 'start'
end

--[[
    Called whenever we change the dimensions of our window, as by dragging
    out its bottom corner, for example. In this case, we only need to worry
    about calling out to `push` to handle the resizing. Takes in a `w` and
    `h` variable representing width and height, respectively.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Called every frame, passing in `dt` since the last frame. `dt`
    is short for `deltaTime` and is measured in seconds. Multiplying
    this by any changes we wish to make in our game will allow our
    game to perform consistently across all hardware; otherwise, any
    changes we make will be applied as fast as possible and will vary
    across system hardware.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            -- ball.dx = math.random(140, 200)
            ball.dx = 100
        else
            -- ball.dx = -math.random(140, 200)
            ball.dx = -100
        end
    elseif gameState == 'play' then
        -- deteshtly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if ball:collides(player1) then
            ball.dx = -ball.dx * 1
            ball.x = player1.x + 17

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end
        if ball:collides(player2) then
            ball.dx = -ball.dx * 1
            ball.x = player2.x - 16

            -- keep velocity going in the same direction, but randomize it
            if ball.dy < 0 then
                ball.dy = -math.random(10, 150)
            else
                ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if ball.y <= 0 then
            ball.y = 0
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- -4 to account for the ball's size
        if ball.y >= VIRTUAL_HEIGHT - 4 then
            ball.y = VIRTUAL_HEIGHT - 4
            ball.dy = -ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == 10 then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end

        -- if we reach the right edge of the screen, go back to serve
        -- and update the score and serving player
        if ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player1Score == 10 then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity
                ball:reset()
            end
        end

        watchingArea = ball.x < VIRTUAL_WIDTH/2
        watchingDirection = ball.dx < 0
        
        if watchingArea and watchingDirection then
            if FIRST_POINT == false then
                ballX = ball.x
                ballY = ball.y
                FIRST_POINT = true
            end
            if COUNTER <= 10 then
                COUNTER = COUNTER + 1
            end
    
            if FIRST_POINT == true and SECOND_POINT == false and COUNTER == 10 then
                secondBallX = ball.x
                secondBallY = ball.y
                SECOND_POINT = true
            end
            
            if FIRST_POINT and SECOND_POINT and COUNTER == 10 then
                print("FIRST POINT", ballX, ballY)
                print("SECOND POINT", secondBallX, secondBallY)
                angle = nil
                leftTrajectory = ballX - PADDLE_WIDTH
                isTrajectoryUp = false

                if ballY > secondBallY then
                    angle = math.atan(ballY - secondBallY ,ballX - secondBallX)
                    isTrajectoryUp = true
                else
                    angle = math.atan(secondBallY - ballY ,ballX - secondBallX)
                    isTrajectoryUp = false
                end 

                verticalTrajectory = math.floor((leftTrajectory * math.sin(angle))/ math.sin(1.5707963268-angle))
                finalPoint = nil
                if isTrajectoryUp then
                    finalPoint = ballY - verticalTrajectory
                else
                    finalPoint = ballY + verticalTrajectory
                end

                player1Position = math.floor(player1.y + PADDLE_HEIGHT/2)

                if player1Position > finalPoint then
                    player1.dy = -PADDLE_SPEED
                elseif player1Position < finalPoint then
                    player1.dy = PADDLE_SPEED
                else
                    player1.dy = 0
                end

                player1:update(dt)
                print("arctan", angle)
                print("ANGLE", angle*(180/3.1416))
                print("final", finalPoint)
                -- calcular ángulo y punto final
                
            end 
        else

            -- reacomodo el paddle cuando la bola no está en la zona que debo monitorear
            player1Position = math.floor(player1.y + PADDLE_HEIGHT/2)
            if player1Position > VIRTUAL_HEIGHT/2 then
                player1.dy = -PADDLE_SPEED
            elseif player1Position < VIRTUAL_HEIGHT/2 then
                player1.dy = PADDLE_SPEED
            else
                player1.dy = 0
            end
            player1:update(dt)
            FIRST_POINT = false
            SECOND_POINT = false
            COUNTER = 0
            finalPoint = nil
            isTrajectoryUp = false
            angle = nil
        end

    end

    --
    -- paddles can move no matter what state we're in
    --
    -- player 1
    -- if love.keyboard.isDown('w') then
    --     player1.dy = -PADDLE_SPEED 
    -- elseif love.keyboard.isDown('s') then
    --     player1.dy = PADDLE_SPEED
    -- else
    --     player1.dy = 0
    -- end

    -- player 2
    if love.keyboard.isDown('up') then
        player2.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('down') then
        player2.dy = PADDLE_SPEED
    else
        player2.dy = 0
    end

    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    if gameState == 'play' then
        ball:update(dt)
    end

    player1:update(dt)
    player2:update(dt)
end

--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            gameState = 'serve'

            ball:reset()

            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    end
end

--[[
    Called each frame after update; is responsible simply for
    drawing all of our game objects and more to the screen.
]]
function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:apply('start')

    love.graphics.clear(20/255, 20/255, 31/255, 255/255)
    
    -- render different things depending on which part of the game we're in
    if gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Welcome to Pong!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to begin!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'serve' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Player ' .. tostring(servingPlayer) .. "'s serve!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Press Enter to serve!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Player ' .. tostring(winningPlayer) .. ' wins!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to restart!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    -- show the score before ball is rendered so it can move over the text
    displayScore()
    
    player1:render()
    player2:render()
    ball:render()

    -- display FPS for debugging; simply comment out to remove
    displayFPS()

    -- end our drawing to push
    push:apply('end')
end

--[[
    Simple function for rendering the scores.
]]
function displayScore()
    -- score display
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50,
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
end
