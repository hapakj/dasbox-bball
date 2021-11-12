require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

enum BrickType
    Empty
    Wall
    Glass
    ArrowRight
    Jump

enum CollisionType
    None
    Left
    Right
    Top
    Bottom

enum GameState
    Init
    InGame
    Win
    Lose

struct Ball
    pos: float2 = float2(0.0, 0.0)
    vel: float2 = float2(0.0, 0.0)
    radius: float = 5.0

var
    ball: Ball = Ball()
    acc: float2

    bricks: array<array<BrickType>>

    act_brick: int2
    next_brick: int2
    collider_brick: int2

    game_state: GameState = GameState Init
    act_level: int

    wall_texture: ImageHandle
    glass_texture: ImageHandle
    arrow_texture: ImageHandle
    jump_texture: ImageHandle

let
    ball_color = make_color(0.7,0.7,1.0)
    default_vel_y: float = 600.0

    default_acc: float2 = float2(0.0, 1800.0)

    acc_x: float = 1000.0
    max_vel_x:float = 500.0

    arrow_vel = 1500.0
    jump_vel = 1000.0

    brick_size: float = 60.0

    level_width: int = 20
    level_height: int = 15

    level_count = 5
    first_level = 1

    
def reset_level
    bricks |> resize(level_width)
    for col in bricks
        col |> resize(level_height)

        for brick in col
            brick = BrickType Empty

    ball.vel = float2(0.0)
    ball.pos = float2(0.0)

    acc = default_acc

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

    wall_texture <- create_managed_image("wall.png")
    glass_texture <- create_managed_image("glass.png")
    arrow_texture <- create_managed_image("arrow.png")
    jump_texture <- create_managed_image("jump.png")
    return


def handle_input(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key(VK_LEFT)
        ball.vel.x -= dt * acc_x

    if get_key(VK_RIGHT)
        ball.vel.x += dt * acc_x

    if get_key(VK_LEFT) || get_key(VK_RIGHT)
        if ball.vel.x > max_vel_x
            ball.vel.x = max_vel_x
        if ball.vel.x < -max_vel_x
            ball.vel.x = -max_vel_x

        acc = default_acc
    return


def safe_brick_type(b : int2)
    if (b.x >= 0 && b.x < level_width && b.y >= 0 && b.y < level_height)
        return bricks[b.x][b.y]
    return BrickType Empty


def advance_ball(dt: float)
    act_brick = int2(ball.pos.x / brick_size, ball.pos.y / brick_size)

    let next_vel = ball.vel + dt * acc
    let next_pos = ball.pos + dt * next_vel

    next_brick = int2(next_pos.x / brick_size, next_pos.y / brick_size)
    collider_brick = next_brick

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
    
    return collision


def advance_game(dt: float)
    handle_input(dt)
    let collision = advance_ball(dt)

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType Glass))
        bricks[collider_brick.x][collider_brick.y] = BrickType Empty

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType ArrowRight))
        ball.pos.x = float(collider_brick.x + 1) * brick_size + 2.0 * ball.radius
        ball.pos.y = (float(collider_brick.y) + 0.5) * brick_size
        ball.vel.y = 0.0
        ball.vel.x = arrow_vel
        acc = float2(0.0)

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType Jump))
        ball.vel.y = -jump_vel

    if (ball.pos.x > float(get_screen_width()))
        game_state = GameState Win

    if (ball.pos.y > float(get_screen_height()))
        game_state = GameState Lose

[export]
def act(dt: float)
    if game_state == GameState InGame
        advance_game(dt)

    elif game_state == GameState Init
        act_level = first_level
        init_level(act_level)
        game_state = GameState InGame

    elif game_state == GameState Win
        act_level++;
        if (act_level > level_count)
            act_level = first_level

        init_level(act_level)
        game_state = GameState InGame

    elif game_state == GameState Lose
        init_level(act_level)
        game_state = GameState InGame

    return


def draw_brick(p: int2; image)
    let px1 = float(p.x) * brick_size + 1.0
    let py1 = float(p.y) * brick_size + 1.0

    let px2 = px1 + brick_size - 2.0
    let py2 = py1 + brick_size - 2.0

    draw_quad(image, float2(px1,py1), float2(px1,py2), float2(px2, py2), float2(px2, py1), 0xFFFFFFFF)


def draw_level
    for x in range(0, level_width)
        for y in range(0, level_height)
            let brick = bricks[x][y]

            if brick == BrickType Wall
                draw_brick(int2(x,y), wall_texture)

            if brick == BrickType Glass
                draw_brick(int2(x,y), glass_texture)

            if brick == BrickType ArrowRight
                draw_brick(int2(x,y), arrow_texture)

            if brick == BrickType Jump
                draw_brick(int2(x,y), jump_texture)


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


def init_level(level: int)
    if (level == 0)
        init_level_test()
    elif (level == 1)
        init_level_1()
    elif (level == 2)
        init_level_2()
    elif (level == 3)
        init_level_3()
    elif (level == 4)
        init_level_4()
    elif (level == 5)
        init_level_5()


def set_ball_pos(pos: int2)
    ball.pos = float2((float(pos.x-1) + 0.5) * brick_size, (float(pos.y-1) + 0.5) * brick_size)

def init_level_test
    reset_level()

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_h(15,1,20,BrickType Wall)

    lay_brick_v(1,1,15,BrickType Wall)
    lay_brick_v(20,1,15,BrickType Wall)

def init_level_1
    reset_level()

    set_ball_pos(int2(3,11))

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


def init_level_2
    reset_level()

    set_ball_pos(int2(3,9))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(2,11,15,BrickType Wall)
    lay_brick_v(3,11,15,BrickType Wall)
    lay_brick_v(4,11,15,BrickType Wall)

    lay_brick_v(7,12,15,BrickType Wall)
    lay_brick_v(8,12,15,BrickType Wall)

    lay_brick_h(12,9,10,BrickType Wall)
    lay_brick_h(11,10,13,BrickType Wall)
    lay_brick_h(11,15,20,BrickType Wall)

    lay_brick_v(20,1,8,BrickType Wall)
    lay_brick_v(20,11,15,BrickType Wall)


def init_level_3
    reset_level()

    set_ball_pos(int2(3,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(4,2,6,BrickType Wall)
    lay_brick_h(4,8,9,BrickType Glass)
    lay_brick_h(4,10,13,BrickType Wall)

    lay_brick_v(11,5,15,BrickType Wall)

    lay_brick_h(11,12,14,BrickType Wall)
    lay_brick_h(12,12,14,BrickType Wall)

    lay_brick_v(20,2,11,BrickType Wall)
    lay_brick_v(20,13,15,BrickType Wall)

    lay_brick_h(11,15,15,BrickType Glass)
    lay_brick_h(12,15,15,BrickType ArrowRight)


def init_level_4
    reset_level()

    set_ball_pos(int2(6,10))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(12,2,13,BrickType Wall)
    lay_brick_h(13,2,6,BrickType Wall)
    lay_brick_h(14,2,6,BrickType Wall)
    lay_brick_h(15,2,6,BrickType Wall)

    lay_brick_h(8,10,12,BrickType Wall)
    lay_brick_h(8,15,20,BrickType Wall)

    lay_brick_v(20,1,5,BrickType Wall)
    lay_brick_v(20,8,15,BrickType Wall)

    lay_brick_h(11,8,8,BrickType Jump)


def init_level_5
    reset_level()

    set_ball_pos(int2(3,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(4,2,4,BrickType Wall)
    lay_brick_h(5,2,4,BrickType Wall)
    lay_brick_h(6,2,4,BrickType Wall)

    lay_brick_h(4,5,10,BrickType Glass)
    lay_brick_h(5,5,10,BrickType Glass)
    lay_brick_h(6,5,10,BrickType Glass)

    lay_brick_h(4,11,20,BrickType Wall)
    lay_brick_h(5,11,20,BrickType Wall)
    lay_brick_h(6,11,20,BrickType Wall)

    lay_brick_v(20,1,9,BrickType Wall)
    lay_brick_v(11,7,10,BrickType Wall)

    lay_brick_h(12,14,20,BrickType Wall)
    lay_brick_h(13,14,20,BrickType Wall)
    lay_brick_h(14,14,20,BrickType Wall)
    lay_brick_h(15,14,20,BrickType Wall)
    
    lay_brick_h(14,5,8, BrickType Wall)
    lay_brick_h(14,9,11, BrickType Glass)
    lay_brick_h(14,12,12, BrickType Jump)



