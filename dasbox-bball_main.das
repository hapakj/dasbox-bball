require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

enum BrickType
    Empty
    Wall
    Glass

enum CollisionType
    None
    Left
    Right
    Top
    Bottom

struct Ball
    pos: float2 = float2(100.0, 600.0)
    vel: float2 = float2(0.0, -0.5)
    radius: float = 5.0

var
    ball: Ball = Ball()
    acc: float2 = float2(0.0, 1800.0)

    bricks: array<array<BrickType>>

    act_brick: int2
    next_brick: int2

let
    ball_color = make_color(0.7,0.7,1.0)
    default_vel_y: float = 700.0

    acc_x: float = 1000.0
    max_vel_x:float = 500.0

    brick_size: float = 60.0

    level_width: int = 20
    level_height: int = 15

    
def clear_level
    bricks |> resize(level_width)
    for col in bricks
        col |> resize(level_height)

        for brick in col
            brick = BrickType Empty

def lay_brick_h(var y: int; var x1: int; var x2: int; brick_type: BrickType)
    y -= 1
    x1 -= 1
    for x in range(x1, x2)
        bricks[x][y] = brick_type

def lay_brick_v(var x: int; var y1: int; var y2: int; brick_type: BrickType)
    x -= 1
    y1 -= 1
    for y in range(y1, y2)
        bricks[x][y] = brick_type



// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_resolution(int(brick_size) * level_width, int(brick_size) * level_height)
    set_window_title("dasbox-bball")

    init_level_1()
    return


def handle_input(dt: float)
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
    return


def safe_brick_type(b : int2)
    if (b.x >= 0 && b.x < level_width && b.y >= 0 && b.y < level_height)
        return bricks[b.x][b.y]
    return BrickType Empty

[export]
def act(dt: float)
    handle_input(dt)

    act_brick = int2(ball.pos.x / brick_size, ball.pos.y / brick_size)

    let next_vel = ball.vel + dt * acc
    let next_pos = ball.pos + dt * next_vel

    next_brick = int2(next_pos.x / brick_size, next_pos.y / brick_size)

    var collision = CollisionType None

    if (safe_brick_type(next_brick) == BrickType Empty)
        ball.vel = next_vel
        ball.pos = next_pos
    else
        var collision_h = CollisionType None
        var collision_v = CollisionType None

        if (next_brick.x < act_brick.x)
            collision_h = CollisionType Left

        if (next_brick.x > act_brick.x)
            collision_h = CollisionType Right

        if (next_brick.y > act_brick.y)
            collision_v = CollisionType Top

        if (next_brick.y < act_brick.y)
            collision_v = CollisionType Bottom

        if ((collision_h != CollisionType None) && (collision_v != CollisionType None))
            if (abs(next_vel.y) > abs(next_vel.x))
                collision = collision_v
            else
                collision = collision_h
        elif (collision_v != CollisionType None)
            collision = collision_v
        else
            collision = collision_h

    if collision == CollisionType Top
        ball.vel.y = -default_vel_y

    if collision == CollisionType Bottom
        ball.vel.y = abs(ball.vel.y)

    if collision == CollisionType Left
        ball.vel.x = abs(ball.vel.x)

    if collision == CollisionType Right
        ball.vel.x = -abs(ball.vel.x)
    
    return


def draw_level
    for x in range(0, level_width)
        for y in range(0, level_height)
            let brick = bricks[x][y]

            let px = float(x) * brick_size
            let py = float(y) * brick_size

            if brick == BrickType Wall
                fill_rect(px+1.0, py+1.0, brick_size-2.0, brick_size-2.0, make_color(0.6,0.0,0.0))

            if brick == BrickType Glass
                fill_rect(px+1.0, py+1.0, brick_size-2.0, brick_size-2.0, make_color(0.6,0.6,0.6))


def draw_debug_brick(p: int2; color)
    let px = float(p.x) * brick_size
    let py = float(p.y) * brick_size

    rect(px, py, brick_size, brick_size, color)
    line(px, py, px + brick_size, py + brick_size, color)
    line(px, py + brick_size, px + brick_size, py, color)

    return


[export]
def draw
    draw_level()

    // draw ball
    fill_circle(ball.pos.x, ball.pos.y,  ball.radius, ball_color)

    return


def init_level_test
    clear_level()

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_h(15,1,20,BrickType Wall)

    lay_brick_v(1,1,15,BrickType Wall)
    lay_brick_v(20,1,15,BrickType Wall)


def init_level_1
    clear_level()

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_h(15,1,20,BrickType Wall)
    lay_brick_h(14,1,20,BrickType Wall)

    lay_brick_v(1,1,15,BrickType Wall)
    lay_brick_v(20,1,11,BrickType Wall)

    lay_brick_h(13,5,13,BrickType Wall)
    lay_brick_h(12,8,13,BrickType Wall)
    lay_brick_h(11,10,13,BrickType Wall)
    lay_brick_h(10,12,15,BrickType Wall)
    lay_brick_h(10,18,20,BrickType Wall)

    lay_brick_h(10,16,17,BrickType Glass)