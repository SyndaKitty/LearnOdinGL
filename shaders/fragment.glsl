#version 330 core
out vec4 FragColor;
in vec4 vertexColor;
in vec2 vertexUV;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform float time;
uniform float blend;

void main()
{
    vec4 tex1 = texture(texture1, vertexUV);
	vec4 tex2 = texture(texture2, vertexUV);
	FragColor = mix(tex1, tex2, min(blend, tex2.a));

	if (tex1.a < 0.1) discard;
}