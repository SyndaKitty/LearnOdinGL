#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 col;
layout (location = 2) in vec2 uv;
uniform mat4 transform;
out vec4 vertexColor;
out vec2 vertexUV;

void main()
{
    gl_Position = transform * vec4(pos, 1.0);
    vertexColor = vec4(col, 1.0);
    vertexUV = uv;
}