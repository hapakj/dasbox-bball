require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

enum BrickType
    Empty
    Wall
    Glass
    ArrowRight
    ArrowLeft
    Jump
    Bomb

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


struct Particle
    pos: float2
    life: int = 0

var
    ball: Ball = Ball()
    acc: float2

    bricks: array<array<BrickType>>
    particles: array<Particle>

    act_brick: int2
    next_brick: int2
    collider_brick: int2

    game_state: GameState = GameState Init
    act_level: int

    wall_texture: ImageHandle
    glass_texture: ImageHandle
    arrow_texture: ImageHandle
    jump_texture: ImageHandle
    bomb_texture: ImageHandle

let
    ball_color = make_color(1.0,1.0,1.0)

    default_vel_y: float = 600.0
    default_acc: float2 = float2(0.0, 1800.0)

    acc_x: float = 1000.0
    max_vel_x:float = 300.0

    climb_vel_y = -450.0
    climb_vel_x = 1.5 * max_vel_x

    arrow_vel = 1000.0
    jump_vel = 900.0

    brick_size: float = 60.0

    level_width: int = 20
    level_height: int = 15

    level_count = 18
    first_level = 1

    particle_count = 32

def reset_particles
    particles |> resize(particle_count)
    for p in particles
        p.life = 0
    
def reset_level
    bricks |> resize(level_width)
    for col in bricks
        col |> resize(level_height)

        for brick in col
            brick = BrickType Empty

    reset_particles()

    ball.vel = float2(0.0)
    ball.pos = float2(0.0)

    acc = default_acc

def lay_brick_h(var y: int; var x1: int; var x2: int; brick_type: BrickType)
    y -= 1
    x1 -= 1
    for x in range(x1, x2)
        if (bricks[x][y] != BrickType Empty) && (bricks[x][y] != brick_type)
            panic("brick type mismatch")
        bricks[x][y] = brick_type

def lay_brick_h(y; x; brick_type)
    lay_brick_h(y, x, x, brick_type)


def lay_brick_v(var x: int; var y1: int; var y2: int; brick_type: BrickType)
    x -= 1
    y1 -= 1
    for y in range(y1, y2)
        if (bricks[x][y] != BrickType Empty) && (bricks[x][y] != brick_type)
            panic("brick type mismatch")
        bricks[x][y] = brick_type

def lay_brick_v(x; y; brick_type)
    lay_brick_v(x, y, y, brick_type)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_resolution(int(brick_size) * level_width, int(brick_size) * level_height)
    set_window_title("Dasbox Bball")

    wall_texture <- create_managed_image("wall.png")
    glass_texture <- create_managed_image("glass.png")
    arrow_texture <- create_managed_image("arrow.png")
    jump_texture <- create_managed_image("jump.png")
    bomb_texture <- create_managed_image("bomb.png")
    return

def reset_acc_and_vel
    if ball.vel.x > max_vel_x
        ball.vel.x = max_vel_x
    if ball.vel.x < -max_vel_x
        ball.vel.x = -max_vel_x

    acc = default_acc
    return

def handle_input(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key(VK_LEFT)
        ball.vel.x -= dt * acc_x

    if get_key(VK_RIGHT)
        ball.vel.x += dt * acc_x

    if get_key(VK_LEFT) ^^ get_key(VK_RIGHT)
        reset_acc_and_vel()

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


def apply_arrow(dir: float)
    ball.pos.x = (float(collider_brick.x) + 0.5) * brick_size + dir * (brick_size * 0.5 + 2.0 * ball.radius)
    ball.pos.y = (float(collider_brick.y) + 0.5) * brick_size
    ball.vel.y = 0.0
    ball.vel.x = dir*arrow_vel
    acc = float2(0.0)

def update_particles
    var dead_particle = -1

    for p_id in range(0,particle_count)
        if particles[p_id].life > 0
            particles[p_id].life--
        
        if particles[p_id].life == 0
            dead_particle = p_id

    if dead_particle != -1
        particles[dead_particle].pos = ball.pos
        particles[dead_particle].life = particle_count

def advance_game(dt: float)
    handle_input(dt)
    let collision = advance_ball(dt)

    if collision != CollisionType None
        reset_acc_and_vel()

    if get_key(VK_LEFT) && get_key(VK_RIGHT)
        if collision == CollisionType Left
            ball.vel.x = climb_vel_x
            ball.vel.y = climb_vel_y
        if collision == CollisionType Right
            ball.vel.x = -climb_vel_x
            ball.vel.y = climb_vel_y

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType Glass))
        bricks[collider_brick.x][collider_brick.y] = BrickType Empty

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType ArrowRight))
        apply_arrow(1.0)

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType ArrowLeft))
        apply_arrow(-1.0)

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType Jump))
        ball.vel.y = -jump_vel

    if ((collision == CollisionType Top) && (safe_brick_type(collider_brick) == BrickType Bomb))
        game_state = GameState Lose

    if (ball.pos.x > float(get_screen_width()))
        game_state = GameState Win

    if (ball.pos.y > float(get_screen_height()))
        game_state = GameState Lose

    update_particles()
    return

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

def draw_brick_flipped(p: int2; image)
    let px1 = float(p.x) * brick_size + 1.0
    let py1 = float(p.y) * brick_size + 1.0

    let px2 = px1 + brick_size - 2.0
    let py2 = py1 + brick_size - 2.0

    draw_quad(image, float2(px2,py1), float2(px2,py2), float2(px1, py2), float2(px1, py1), 0xFFFFFFFF)


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

            if brick == BrickType ArrowLeft
                draw_brick_flipped(int2(x,y), arrow_texture)

            if brick == BrickType Jump
                draw_brick(int2(x,y), jump_texture)

            if brick == BrickType Bomb
                draw_brick(int2(x,y), bomb_texture)


def draw_debug_brick(p: int2; color)
    let px = float(p.x) * brick_size
    let py = float(p.y) * brick_size

    rect(px, py, brick_size, brick_size, color)
    line(px, py, px + brick_size, py + brick_size, color)
    line(px, py + brick_size, px + brick_size, py, color)

    return


def draw_particles
    enable_alpha_blend()

    for p in particles
        let t = float(p.life) / float(particle_count)

        fill_circle(p.pos.x, p.pos.y,  t * ball.radius, make_color(t, 2.0 * max(t - 0.5, 0.0), 0.0, t))

    disable_alpha_blend()


[export]
def draw
    draw_level()

    draw_particles()

    // draw ball
    fill_circle(ball.pos.x, ball.pos.y,  ball.radius, ball_color)

    return


def init_level(level: int)
    set_window_title("Dasbox Bball - Level " + string(level))

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
    elif (level == 6)
        init_level_6()
    elif (level == 7)
        init_level_7()
    elif (level == 8)
        init_level_8()
    elif (level == 9)
        init_level_9()
    elif (level == 10)
        init_level_10()
    elif (level == 11)
        init_level_11()
    elif (level == 12)
        init_level_12()
    elif (level == 13)
        init_level_13()
    elif (level == 14)
        init_level_14()
    elif (level == 15)
        init_level_15()
    elif (level == 16)
        init_level_16()
    elif (level == 17)
        init_level_17()
    elif (level == 18)
        init_level_18()


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


def init_level_6
    reset_level()

    set_ball_pos(int2(16,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(2,2,2,BrickType Wall)

    lay_brick_h(4,6,8,BrickType Wall)
    lay_brick_h(4,10,12,BrickType Wall)
    lay_brick_h(4,14,19,BrickType Wall)

    lay_brick_h(5,7,8,BrickType Wall)
    lay_brick_h(5,10,12,BrickType Wall)
    lay_brick_h(5,14,19,BrickType Wall)

    lay_brick_h(5,9,9,BrickType Bomb)
    lay_brick_h(5,13,13,BrickType Bomb)

    lay_brick_h(8,4,6,BrickType Wall)
    lay_brick_h(8,7,7,BrickType ArrowRight)

    lay_brick_h(9,2,4,BrickType Bomb)
    lay_brick_h(9,5,8,BrickType Wall)
    lay_brick_h(9,9,15,BrickType Bomb)

    lay_brick_h(10,2,2,BrickType Wall)
    lay_brick_h(12,7,20,BrickType Wall)

    lay_brick_h(14,4,4,BrickType ArrowRight)

    lay_brick_v(20,1,12,BrickType Wall)


def init_level_7
    reset_level()

    set_ball_pos(int2(3,13))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(15,1,5,BrickType Wall)
    lay_brick_v(5,11,15,BrickType Wall)

    lay_brick_h(11,5,7,BrickType Wall)
    lay_brick_h(11,8,15,BrickType Glass)
    lay_brick_h(11,17,18,BrickType Jump)

    lay_brick_h(8,1,15,BrickType Wall)
    lay_brick_h(7,1,6,BrickType Wall)

    lay_brick_v(20,4,15,BrickType Wall)

    lay_brick_h(4,5,8,BrickType Wall)
    lay_brick_h(4,10,13,BrickType Wall)
    lay_brick_h(4,16,20,BrickType Wall)


def init_level_8
    reset_level()

    set_ball_pos(int2(3,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(4,2,4,BrickType Wall)
    lay_brick_h(4,7,7,BrickType Wall)
    lay_brick_h(4,11,15,BrickType Wall)

    lay_brick_h(5,2,4,BrickType Wall)
    lay_brick_h(5,6,8,BrickType Wall)
    lay_brick_h(5,10,12,BrickType Wall)

    lay_brick_h(8,2,14,BrickType Bomb)

    lay_brick_h(10,17,17,BrickType ArrowLeft)
    lay_brick_h(13,6,6,BrickType ArrowRight)

    lay_brick_v(20,1,12,BrickType Wall)
    lay_brick_v(19,12,12,BrickType Wall)
    lay_brick_v(20,14,15,BrickType Wall)


def init_level_9
    reset_level()

    set_ball_pos(int2(5,10))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(15,5,6,BrickType Jump)

    lay_brick_h(12,2,3,BrickType Wall)
    lay_brick_h(11,2,3,BrickType Wall)
    lay_brick_h(10,2,3,BrickType Wall)
    lay_brick_h(9,2,4,BrickType Wall)
    lay_brick_h(8,2,2,BrickType Wall)
    lay_brick_h(8,3,3,BrickType Jump)
    lay_brick_h(8,4,5,BrickType Wall)

    lay_brick_h(11,7,11,BrickType Wall)
    lay_brick_h(10,9,11,BrickType Wall)
    lay_brick_h(10,14,16,BrickType Wall)

    lay_brick_h(10,18,18,BrickType Jump)

    lay_brick_v(20,1,3,BrickType Wall)
    lay_brick_v(20,5,15,BrickType Wall)

    lay_brick_h(7,5,7,BrickType Wall)
    lay_brick_h(7,8,8,BrickType Bomb)
    lay_brick_h(7,9,9,BrickType Glass)

    lay_brick_h(7,10,16,BrickType Wall)
    lay_brick_h(6,12,16,BrickType Wall)

    lay_brick_h(4,5,5,BrickType ArrowRight)


def init_level_10
    reset_level()

    set_ball_pos(int2(18,5))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,1,13,BrickType Wall)
    lay_brick_v(20,15,15,BrickType Wall)

    lay_brick_h(12,17,19,BrickType Bomb)

    lay_brick_h(11,17,19,BrickType Glass)
    lay_brick_h(10,17,19,BrickType Glass)
    lay_brick_h(9,17,19,BrickType Glass)

    lay_brick_v(16,4,12,BrickType Wall)
    lay_brick_v(15,4,5,BrickType Wall)

    lay_brick_v(12,4,5,BrickType Wall)
    lay_brick_v(11,4,5,BrickType Wall)

    lay_brick_h(5,13,14,BrickType Bomb)

    lay_brick_h(14,7,7,BrickType ArrowRight)


def init_level_11
    reset_level()

    set_ball_pos(int2(3,13))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(15,1,6,BrickType Wall)

    lay_brick_h(15,9,9,BrickType Jump)
    lay_brick_h(12,11,11,BrickType Jump)
    lay_brick_h(9,14,14,BrickType Jump)
    lay_brick_h(7,17,17,BrickType Jump)

    lay_brick_v(20,5,15,BrickType Wall)


def init_level_12
    reset_level()

    set_ball_pos(int2(3,13))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,4,15,BrickType Wall)
    lay_brick_v(16,1,6,BrickType Wall)

    lay_brick_h(15,1,4,BrickType Wall)
    lay_brick_h(15,6,7,BrickType Wall)
    lay_brick_h(15,10,10,BrickType Wall)
    lay_brick_h(15,12,12,BrickType Wall)
    lay_brick_h(15,14,16,BrickType Wall)

    lay_brick_h(15,18,18,BrickType Jump)

    lay_brick_h(12,2,2,BrickType Wall)
    lay_brick_h(12,3,3,BrickType Jump)
    lay_brick_h(12,4,4,BrickType Wall)

    lay_brick_h(12,7,7,BrickType Wall)
    lay_brick_h(12,10,10,BrickType Wall)
    lay_brick_h(12,13,16,BrickType Wall)

    lay_brick_h(9,5,6,BrickType Wall)
    lay_brick_h(9,8,8,BrickType Wall)
    lay_brick_h(9,10,10,BrickType Wall)
    lay_brick_h(9,12,12,BrickType Wall)
    lay_brick_h(9,14,14,BrickType Wall)
    lay_brick_h(9,16,17,BrickType Wall)

    lay_brick_h(9,18,18,BrickType Jump)

    lay_brick_h(9,19,19,BrickType Wall)


def init_level_13
    reset_level()

    set_ball_pos(int2(7,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(2,1,6,BrickType Wall)
    lay_brick_h(3,1,6,BrickType Wall)
    lay_brick_h(4,1,6,BrickType Wall)
    lay_brick_h(5,1,6,BrickType Wall)

    lay_brick_h(4,7,7,BrickType Glass)
    lay_brick_h(5,7,7,BrickType ArrowRight)

    lay_brick_v(20,1,12,BrickType Wall)
    
    lay_brick_h(2,17,20,BrickType Wall)
    lay_brick_h(3,18,20,BrickType Wall)
    lay_brick_h(4,19,20,BrickType Wall)

    lay_brick_h(7,17,17,BrickType ArrowLeft)

    lay_brick_h(9,5,19,BrickType Bomb)

    lay_brick_h(15,3,3,BrickType Jump)
    lay_brick_h(15,8,8,BrickType Jump)
    lay_brick_h(15,13,13,BrickType Jump)

    lay_brick_h(15,17,20,BrickType Wall)

    lay_brick_v(3,12,14,BrickType Glass)


def init_level_14
    reset_level()

    set_ball_pos(int2(18,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,1,12,BrickType Wall)
    lay_brick_v(20,15,15,BrickType Wall)

    lay_brick_h(4,15,20,BrickType Wall)
    lay_brick_h(4,11,11,BrickType Wall)

    lay_brick_h(5,8,12,BrickType Wall)
    lay_brick_h(5,5,6,BrickType Wall)

    lay_brick_h(5,7,7,BrickType Bomb)
    lay_brick_h(7,12,18,BrickType Bomb)

    lay_brick_v(6,10,15,BrickType Wall)
    lay_brick_v(7,10,15,BrickType Wall)

    lay_brick_h(15,18,18,BrickType Jump)
    lay_brick_h(15,13,13,BrickType Jump)

    lay_brick_v(13,14,14,BrickType Glass)
    lay_brick_v(12,12,14,BrickType Glass)
    lay_brick_v(11,11,12,BrickType Glass)


def init_level_15
    reset_level()

    set_ball_pos(int2(3,6))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,1,10,BrickType Wall)
    lay_brick_v(20,13,15,BrickType Wall)

    lay_brick_v(2,2,5,BrickType Wall)
    lay_brick_h(8,1,6,BrickType Wall)

    lay_brick_v(5,5,8,BrickType Wall)
    lay_brick_v(6,5,8,BrickType Wall)
    lay_brick_v(17,5,9,BrickType Wall)

    lay_brick_h(9,2,16,BrickType Bomb)

    lay_brick_h(5,7,9,BrickType Glass)
    lay_brick_h(4,9,9,BrickType Glass)
    lay_brick_h(4,11,12,BrickType Glass)
    lay_brick_h(4,14,14,BrickType Glass)
    lay_brick_h(4,16,17,BrickType Glass)

    lay_brick_h(13,18,19,BrickType Glass)
    lay_brick_h(14,16,19,BrickType Glass)
    lay_brick_h(14,11,13,BrickType Glass)

    lay_brick_h(10,19,19,BrickType Wall)
    lay_brick_h(10,18,18,BrickType ArrowLeft)


def init_level_16
    reset_level()

    set_ball_pos(int2(2,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,1,9,BrickType Wall)
    lay_brick_v(20,12,15,BrickType Wall)

    lay_brick_h(4,6,6,BrickType Wall)

    lay_brick_h(5,1,7,BrickType Wall)
    lay_brick_h(5,10,10,BrickType Wall)
    lay_brick_h(5,12,12,BrickType Wall)
    lay_brick_h(5,15,16,BrickType Wall)

    lay_brick_h(6,7,7,BrickType Wall)
    lay_brick_h(6,8,9,BrickType Bomb)
    lay_brick_h(6,10,10,BrickType Wall)
    lay_brick_h(6,11,11,BrickType Bomb)
    lay_brick_h(6,12,12,BrickType Wall)
    lay_brick_h(6,13,14,BrickType Bomb)
    lay_brick_h(6,15,15,BrickType Wall)

    lay_brick_h(9,5,5,BrickType Glass)
    lay_brick_h(9,8,8,BrickType Glass)
    lay_brick_h(9,10,11,BrickType Glass)
    lay_brick_h(9,14,14,BrickType Glass)
    lay_brick_h(9,16,20,BrickType Wall)

    lay_brick_v(16,9,13,BrickType Wall)

    lay_brick_h(14,3,3,BrickType ArrowRight)


def init_level_17
    reset_level()

    set_ball_pos(int2(16,13))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_h(15,1,5,BrickType Wall)
    lay_brick_h(15,7,8,BrickType Glass)
    lay_brick_h(15,11,11,BrickType Glass)
    lay_brick_h(15,13,13,BrickType Glass)
    lay_brick_h(15,14,20,BrickType Wall)

    lay_brick_h(14,3,3,BrickType Jump)

    lay_brick_v(20,1,12,BrickType Wall)
    lay_brick_v(19,10,14,BrickType Glass)
    lay_brick_v(16,5,10,BrickType Wall)

    lay_brick_h(10,5,7,BrickType Wall)

    lay_brick_h(10,10,10,BrickType Jump)
    lay_brick_h(7,7,7,BrickType Jump)

    lay_brick_h(4,4,4,BrickType ArrowRight)


def init_level_18
    reset_level()

    set_ball_pos(int2(2,2))

    lay_brick_h(1,1,20,BrickType Wall)
    lay_brick_v(1,1,15,BrickType Wall)

    lay_brick_v(20,1,3,BrickType Wall)
    lay_brick_v(20,6,15,BrickType Wall)

    lay_brick_v(6,1,12,BrickType Wall)

    lay_brick_h(4,2,3,BrickType Wall)
    lay_brick_h(4,4,4,BrickType Glass)
    lay_brick_h(4,5,5,BrickType Wall)

    lay_brick_h(8,2,2,BrickType Wall)
    lay_brick_h(8,3,3,BrickType Glass)
    lay_brick_h(8,4,4,BrickType Bomb)
    lay_brick_h(8,5,11,BrickType Wall)

    lay_brick_h(12,2,2,BrickType Wall)
    lay_brick_h(12,3,3,BrickType Bomb)
    lay_brick_h(12,4,4,BrickType Glass)
    lay_brick_h(12,5,6,BrickType Wall)

    lay_brick_h(15,2,5,BrickType Glass)
    lay_brick_h(15,6,9,BrickType Wall)
    lay_brick_h(14,8,9,BrickType Wall)
    lay_brick_v(10,14,15,BrickType Jump)

    lay_brick_h(11,7, BrickType ArrowRight)

    lay_brick_h(11,18,19,BrickType Wall)

    lay_brick_h(10,11,12,BrickType Wall)
    lay_brick_h(10,14,15,BrickType Wall)
    lay_brick_h(10,18,19,BrickType Wall)

    lay_brick_h(9,11,12,BrickType Wall)
    lay_brick_h(9,14,BrickType Jump)

    lay_brick_h(7,9,BrickType Jump)

    lay_brick_h(3,10,BrickType ArrowRight)

    

