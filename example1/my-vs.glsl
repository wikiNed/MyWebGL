uniform mat4 czm_instanced_modifiedModelView;
uniform mat4 czm_instanced_nodeTransform;
mat3 czm_instanced_modelViewInverseTranspose;
mat4 czm_instanced_modelView;
attribute vec4 czm_modelMatrixRow0;
attribute vec4 czm_modelMatrixRow1;
attribute vec4 czm_modelMatrixRow2;
attribute float a_batchId;
attribute vec2 a_tex_trs_2;
attribute vec2 a_tex_trs_1;
attribute vec2 a_tex_trs_0;
precision highp float;

uniform mat4 u_projectionMatrix;

attribute vec3 a_position;
varying vec3 v_positionEC;
attribute vec3 a_normal;
varying vec3 v_normal;
attribute vec2 a_texcoord_0;
varying vec2 v_texcoord_0;
void czm_instancing_main()
{
    vec3 weightedPosition = a_position;
    vec3 weightedNormal = a_normal;
    vec4 position = vec4(weightedPosition, 1.0);
    position = czm_instanced_modelView * position;
    v_positionEC = position.xyz;
    gl_Position = u_projectionMatrix * position;
    v_normal = czm_instanced_modelViewInverseTranspose * weightedNormal;
    v_texcoord_0 = a_texcoord_0;
}
void tile_main()
{
    mat4 czm_instanced_model = mat4(czm_modelMatrixRow0.x, czm_modelMatrixRow1.x, czm_modelMatrixRow2.x, 0.0, czm_modelMatrixRow0.y, czm_modelMatrixRow1.y, czm_modelMatrixRow2.y, 0.0, czm_modelMatrixRow0.z, czm_modelMatrixRow1.z, czm_modelMatrixRow2.z, 0.0, czm_modelMatrixRow0.w, czm_modelMatrixRow1.w, czm_modelMatrixRow2.w, 1.0);
    czm_instanced_modelView = czm_instanced_modifiedModelView * czm_instanced_model * czm_instanced_nodeTransform;
    czm_instanced_modelViewInverseTranspose = mat3(czm_instanced_modelView);
    czm_instancing_main();
}
void tile_color(vec4 tile_featureColor)
{
    tile_main();
}

uniform vec4 tile_textureStep;
vec2 computeSt(float batchId)
{
    float stepX = tile_textureStep.x;
    float centerX = tile_textureStep.y;
    return vec2(centerX + (batchId * stepX), 0.5);
}
uniform bool tile_translucentCommand;
uniform sampler2D tile_batchTexture;
varying vec4 tile_featureColor;
varying vec2 tile_featureSt;
void cesium_origin_main()
{
    vec2 st = computeSt(a_batchId);
    vec4 featureProperties = texture2D(tile_batchTexture, st);
    tile_color(featureProperties);
    float show = ceil(featureProperties.a);
    gl_Position *= show;
    bool isStyleTranslucent = (featureProperties.a != 1.0);
    if (czm_pass == czm_passTranslucent)
    {
        if (!isStyleTranslucent && !tile_translucentCommand)
        {
            gl_Position *= 0.0;
        }
    }
    else
    {
        if (isStyleTranslucent)
        {
            gl_Position *= 0.0;
        }
    }
    tile_featureColor = featureProperties;
    tile_featureSt = st;
}attribute float a_height;
varying vec2 v_tex_trs_0;
varying vec2 v_tex_trs_1;
varying vec2 v_tex_trs_2;
varying float v_height;
varying float v_fragmentY;
void main(){
    cesium_origin_main();
    v_tex_trs_0 = a_tex_trs_0;
    v_tex_trs_1 = a_tex_trs_1;
    v_tex_trs_2 = a_tex_trs_2;
    v_height = a_height;
    v_fragmentY = a_position.z;
}
