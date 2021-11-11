require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

struct Ball
    pos: float2 = float2(50.0, 50.0)
    vel: float2 = float2(0.0, -0.5)
    radius: float = 5.0

var
    ball: Ball = Ball()
    acc: float2 = float2(0.0, 1800.0)

let
    ball_color = make_color(0.7,0.7,1.0)
    default_vel_y: float = 700.0

    acc_x: float = 1000.0
    max_vel_x:float = 500.0

    


// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("dasbox-bball")
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key(VK_LEFT)
        ball.vel.x -= dt * acc_x

    if get_key(VK_RIGHT)
        ball.vel.x += dt * acc_x

    if ball.vel.x > max_vel_x
        ball.vel.x = max_vel_x

    if ball.vel.x < -max_vel_x
        ball.vel.x = -max_vel_x

    ball.vel += dt * acc
    ball.pos += dt * ball.vel

    if (ball.pos.y + ball.radius) > float(get_screen_height())
        ball.vel.y = -default_vel_y

    if (ball.radius) > ball.pos.x
        ball.vel.x *= -1.0
    
    if (ball.pos.x + ball.radius) > float(get_screen_width())
        ball.vel.x *= -1.0

    return


// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    //enable_alpha_blend()

    // draw ball
    fill_circle(ball.pos.x, ball.pos.y,  ball.radius, ball_color)

    return
