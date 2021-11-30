package main

import "core:fmt"
import "core:c"
import "core:strings"
import "core:math"

import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

window : glfw.WindowHandle;
vao: u32;
vbo: u32;
ebo: u32;
program: Program;

wall_texture: GLTexture;
face_texture: GLTexture;
transform : matrix[4, 4]f32;

x: f32;
y: f32;
blend: f32;

rectangle_vertices := [?]f32 {
    // positions      // colors       // uvs
     0.5,  0.5, 0.0,  1.0, 0.0, 0.0,  2.0, 2.0,
     0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  2.0, 0.0,
    -0.5, -0.5, 0.0,  0.0, 0.0, 1.0,  0.0, 0.0,
    -0.5,  0.5, 0.0,  1.0, 1.0, 0.0,  0.0, 2.0,
};

rectangle_indices := [?]u32 {
    0, 1, 3,
    1, 2, 3,
};

main :: proc() {
    glfw.Init();

    window = glfw.CreateWindow(600, 600, "OdinGL", nil, nil);

    if window == nil {
        fmt.println("Unable to create window, terminating.");
        glfw.Terminate();
    }

    glfw.MakeContextCurrent(window);
    glfw.SetKeyCallback(window, key_callback);
    glfw.SetFramebufferSizeCallback(window, size_callback);

    gl.load_up_to(4, 6, get_proc_address);
    gl.ClearColor(0.2, 0.3, 0.3, 1.0);

    program = load_shaders();

    stbi.set_flip_vertically_on_load(1);
    wall_texture = load_gltexture(load_texture("resources/wall.png"), gl.TEXTURE0);
    face_texture = load_gltexture(load_texture("resources/awesomeface.png"), gl.TEXTURE1);

    gl.GenVertexArrays(1, &vao);
    gl.GenBuffers(1, &vbo);
    gl.GenBuffers(1, &ebo);

    gl.BindVertexArray(vao);
    
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, len(rectangle_vertices) * size_of(f32), &rectangle_vertices, gl.STATIC_DRAW);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), uintptr(3 * size_of(f32)));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(f32), uintptr(6 * size_of(f32)));
    gl.EnableVertexAttribArray(2);
    
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(rectangle_indices) * size_of(u32), &rectangle_indices, gl.STATIC_DRAW);

    gl.ActiveTexture(wall_texture.unit);
    gl.BindTexture(gl.TEXTURE_2D, wall_texture.handle);
    gl.ActiveTexture(face_texture.unit);
    gl.BindTexture(gl.TEXTURE_2D, face_texture.handle);
    
    gl.UseProgram(program.handle);    
    
    gl.Uniform1i(program.uniforms["texture1"].location, 0);
    gl.Uniform1i(program.uniforms["texture2"].location, 1);

    for !glfw.WindowShouldClose(window) {
        gl.Clear(gl.COLOR_BUFFER_BIT);
    
        if glfw.GetKey(window, glfw.KEY_W) == 1 {
            y += 0.01;
        }
        if glfw.GetKey(window, glfw.KEY_S) == 1 {
            y -= 0.01;
        }
        if glfw.GetKey(window, glfw.KEY_D) == 1 {
            x += 0.01;
        }
        if glfw.GetKey(window, glfw.KEY_A) == 1 {
            x -= 0.01;
        }
        if glfw.GetKey(window, glfw.KEY_UP) == 1 {
            blend = min(blend + 0.01, 1.0);
        }
        if glfw.GetKey(window, glfw.KEY_DOWN) == 1 {
            blend = max(blend - 0.01, 0.0);
        }

        time := f32(glfw.GetTime());

        gl.Uniform1f(program.uniforms["time"].location, time);
        gl.Uniform1f(program.uniforms["blend"].location, blend);
        
        transform = translation(x, y) * rotation(time);
        gl.UniformMatrix4fv(program.uniforms["transform"].location, 1, false, &transform[0, 0])

        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, len(rectangle_indices), gl.UNSIGNED_INT, rawptr(uintptr(0)));

        glfw.SwapBuffers(window);
        glfw.PollEvents();
    }

    glfw.Terminate();
}

get_proc_address :: proc(p: rawptr, name: cstring) {
    (cast(^rawptr)p)^ = glfw.GetProcAddress(name);
}

cstr :: proc(str: string) -> cstring {
    return cstring(raw_data(str));
}

load_texture :: proc(filename: string) -> Texture {
    res: Texture;
    res.data = stbi.load(cstr(filename), &res.x, &res.y, &res.channels, 4);
    return res;
}

Texture :: struct {
    x: i32,
    y: i32,
    channels: i32,
    data: ^byte,
}

load_gltexture :: proc(texture: Texture, unit: u32) -> GLTexture {
    res: GLTexture;
    res.texture = texture;
    res.unit = unit;
    gl.GenTextures(1, &res.handle);
    
    gl.ActiveTexture(unit);
    gl.BindTexture(gl.TEXTURE_2D, res.handle);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texture.x, texture.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, texture.data);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    return res;
}

GLTexture :: struct {
    using texture: Texture,
    unit: u32,
    handle: u32,
}

load_shaders :: proc() -> Program {
    res: Program;
    
    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
    fragment_source := string(#load("shaders/fragment.glsl"));
    fragment_source_len := i32(len(fragment_source));
    fragment_source_data := cstr(fragment_source);
    gl.ShaderSource(fragment_shader, 1, &fragment_source_data, &fragment_source_len);
    gl.CompileShader(fragment_shader);

    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
    vertex_source := string(#load("shaders/vertex.glsl"));
    vertex_source_len := i32(len(vertex_source));
    vertex_source_data := cstr(vertex_source);
    gl.ShaderSource(vertex_shader, 1, &vertex_source_data, &vertex_source_len);
    gl.CompileShader(vertex_shader)

    res.handle = gl.CreateProgram();
    gl.AttachShader(res.handle, fragment_shader);
    gl.AttachShader(res.handle, vertex_shader);
    gl.LinkProgram(res.handle);

    gl.DetachShader(res.handle, fragment_shader);
    gl.DetachShader(res.handle, vertex_shader);
    gl.DeleteShader(fragment_shader)
    gl.DeleteShader(vertex_shader);

    res.uniforms = gl.get_uniforms_from_program(res.handle);

    return res;
}

Program :: struct {
    handle: u32,
    uniforms: gl.Uniforms,
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
        glfw.SetWindowShouldClose(window, true);
    }
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    gl.Viewport(0, 0, width, height);
}

rotation :: proc(theta: f32) -> matrix[4, 4]f32 {
    c := math.cos(theta);
    s := math.sin(theta);

    return matrix[4, 4]f32 {
        c,-s, 0, 0,
        s, c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

translation :: proc(x, y: f32) -> matrix[4, 4]f32 {
    return matrix[4, 4]f32 {
        1, 0, 0, x,
        0, 1, 0, y,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
}

min :: proc(a, b: f32) -> f32 {
    if a < b {
        return a;
    }
    return b;
}

max :: proc(a, b: f32) -> f32 {
    if a < b {
        return b;
    }
    return a;
}