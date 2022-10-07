uniform mat4 projection;
uniform mat4 view;

varying vec3 pos;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    pos = vertex_position.xyz;
    return projection * mat4(mat3(view)) * vertex_position;
}