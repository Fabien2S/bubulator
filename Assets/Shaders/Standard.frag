uniform vec3 lightDirection;
uniform vec3 lightColor;
uniform vec3 ambientColor;

varying vec3 normal;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    float diffuseStrength = max(dot(normal, lightDirection), 0);
    vec3 diffuseColor = diffuseStrength * lightColor;
    vec4 result =  Texel(texture, texture_coords) * vec4(ambientColor + diffuseColor, 1) * color;
    if(result.a < .5)
        discard;
    return result;
}