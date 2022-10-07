attribute vec3 VertexNormal;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

varying vec3 normal;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    normal = VertexNormal;
    return projection * view * model * vertex_position;
}