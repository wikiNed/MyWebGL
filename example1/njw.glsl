uniform float tile_colorBlend;
vec4 tile_diffuse = vec4(1.0);
bool isWhite(vec3 color)
{
    return all(greaterThan(color, vec3(1.0 - czm_epsilon3)));
}
vec4 tile_diffuse_final(vec4 sourceDiffuse, vec4 tileDiffuse)
{
    vec4 blendDiffuse = mix(sourceDiffuse, tileDiffuse, tile_colorBlend);
    vec4 diffuse = isWhite(tileDiffuse.rgb) ? sourceDiffuse : blendDiffuse;
    return vec4(diffuse.rgb, sourceDiffuse.a);
}
uniform sampler2D u_baseColorTexture;
precision highp float;
uniform vec4 u_baseColorFactor;

uniform float u_metallicFactor;
uniform float u_roughnessFactor;
uniform vec3 u_emissiveFactor;
varying vec3 v_normal;
varying vec3 v_positionEC;
varying vec2 v_texcoord_0;
const float M_PI = 3.141592653589793;
vec3 lambertianDiffuse(vec3 diffuseColor)
{
    return diffuseColor / M_PI;
}

vec3 fresnelSchlick2(vec3 f0, vec3 f90, float VdotH)
{
    return f0 + (f90 - f0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);
}

vec3 fresnelSchlick(float metalness, float VdotH)
{
    return metalness + (vec3(1.0) - metalness) * pow(1.0 - VdotH, 5.0);
}

float smithVisibilityG1(float NdotV, float roughness)
{
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float smithVisibilityGGX(float roughness, float NdotL, float NdotV)
{
    return smithVisibilityG1(NdotL, roughness) * smithVisibilityG1(NdotV, roughness);
}

float GGX(float roughness, float NdotH)
{
    float roughnessSquared = roughness * roughness;
    float f = (NdotH * roughnessSquared - NdotH) * NdotH + 1.0;
    return roughnessSquared / (M_PI * f * f);
}

vec3 SRGBtoLINEAR3(vec3 srgbIn)
{
    return pow(srgbIn, vec3(2.2));
}

vec4 SRGBtoLINEAR4(vec4 srgbIn)
{
    vec3 linearOut = pow(srgbIn.rgb, vec3(2.2));
    return vec4(linearOut, srgbIn.a);
}

vec3 applyTonemapping(vec3 linearIn)
{
    #ifndef HDR
    return czm_acesTonemapping(linearIn);
    #else
    return linearIn;
    #endif
}

vec3 LINEARtoSRGB(vec3 linearIn)
{
    #ifndef HDR
    return pow(linearIn, vec3(1.0/2.2));
    #else
    return linearIn;
    #endif
}

vec2 computeTexCoord(vec2 texCoords, vec2 offset, float rotation, vec2 scale)
{
    rotation = -rotation;
    mat3 transform = mat3(
    cos(rotation) * scale.x, sin(rotation) * scale.x, 0.0,
    -sin(rotation) * scale.y, cos(rotation) * scale.y, 0.0,
    offset.x, offset.y, 1.0);
    vec2 transformedTexCoords = (transform * vec3(fract(texCoords), 1.0)).xy;
    return transformedTexCoords;
}

    #ifdef USE_IBL_LIGHTING
uniform vec2 gltf_iblFactor;
#endif
#ifdef USE_CUSTOM_LIGHT_COLOR
uniform vec3 gltf_lightColor;
#endif
void tile_main()
{
    vec3 ng = normalize(v_normal);
    vec3 positionWC = vec3(czm_inverseView * vec4(v_positionEC, 1.0));
    vec3 n = ng;
    if (gl_FrontFacing == false)
    {
        n = -n;
    }
    vec4 baseColorWithAlpha = SRGBtoLINEAR4(tile_diffuse_final(texture2D(u_baseColorTexture, v_texcoord_0), tile_diffuse));
    baseColorWithAlpha *= u_baseColorFactor;
    vec3 baseColor = baseColorWithAlpha.rgb;
    float metalness = clamp(u_metallicFactor, 0.0, 1.0);
    float roughness = clamp(u_roughnessFactor, 0.04, 1.0);
    vec3 v = -normalize(v_positionEC);
    #ifndef USE_CUSTOM_LIGHT_COLOR
    vec3 lightColorHdr = czm_lightColorHdr;
    #else
    vec3 lightColorHdr = gltf_lightColor;
    #endif
    vec3 l = normalize(czm_lightDirectionEC);
    vec3 h = normalize(v + l);
    float NdotL = clamp(dot(n, l), 0.001, 1.0);
    float NdotV = abs(dot(n, v)) + 0.001;
    float NdotH = clamp(dot(n, h), 0.0, 1.0);
    float LdotH = clamp(dot(l, h), 0.0, 1.0);
    float VdotH = clamp(dot(v, h), 0.0, 1.0);
    vec3 f0 = vec3(0.04);
    vec3 diffuseColor = baseColor * (1.0 - metalness) * (1.0 - f0);
    vec3 specularColor = mix(f0, baseColor, metalness);
    float alpha = roughness * roughness;
    float reflectance = max(max(specularColor.r, specularColor.g), specularColor.b);
    vec3 r90 = vec3(clamp(reflectance * 25.0, 0.0, 1.0));
    vec3 r0 = specularColor.rgb;
    vec3 F = fresnelSchlick2(r0, r90, VdotH);
    float G = smithVisibilityGGX(alpha, NdotL, NdotV);
    float D = GGX(alpha, NdotH);
    vec3 diffuseContribution = (1.0 - F) * lambertianDiffuse(diffuseColor);
    vec3 specularContribution = F * G * D / (4.0 * NdotL * NdotV);
    vec3 color = NdotL * lightColorHdr * (diffuseContribution + specularContribution);
    #if defined(USE_IBL_LIGHTING) && !defined(DIFFUSE_IBL) && !defined(SPECULAR_IBL)
    vec3 r = normalize(czm_inverseViewRotation * normalize(reflect(v, n)));
    float vertexRadius = length(positionWC);
    float horizonDotNadir = 1.0 - min(1.0, czm_ellipsoidRadii.x / vertexRadius);
    float reflectionDotNadir = dot(r, normalize(positionWC));
    r.x = -r.x;
    r = -normalize(czm_temeToPseudoFixed * r);
    r.x = -r.x;
    float inverseRoughness = 1.04 - roughness;
    inverseRoughness *= inverseRoughness;
    vec3 sceneSkyBox = textureCube(czm_environmentMap, r).rgb * inverseRoughness;
    float atmosphereHeight = 0.05;
    float blendRegionSize = 0.1 * ((1.0 - inverseRoughness) * 8.0 + 1.1 - horizonDotNadir);
    float blendRegionOffset = roughness * -1.0;
    float farAboveHorizon = clamp(horizonDotNadir - blendRegionSize * 0.5 + blendRegionOffset, 1.0e-10 - blendRegionSize, 0.99999);
    float aroundHorizon = clamp(horizonDotNadir + blendRegionSize * 0.5, 1.0e-10 - blendRegionSize, 0.99999);
    float farBelowHorizon = clamp(horizonDotNadir + blendRegionSize * 1.5, 1.0e-10 - blendRegionSize, 0.99999);
    float smoothstepHeight = smoothstep(0.0, atmosphereHeight, horizonDotNadir);
    vec3 belowHorizonColor = mix(vec3(0.1, 0.15, 0.25), vec3(0.4, 0.7, 0.9), smoothstepHeight);
    vec3 nadirColor = belowHorizonColor * 0.5;
    vec3 aboveHorizonColor = mix(vec3(0.9, 1.0, 1.2), belowHorizonColor, roughness * 0.5);
    vec3 blueSkyColor = mix(vec3(0.18, 0.26, 0.48), aboveHorizonColor, reflectionDotNadir * inverseRoughness * 0.5 + 0.75);
    vec3 zenithColor = mix(blueSkyColor, sceneSkyBox, smoothstepHeight);
    vec3 blueSkyDiffuseColor = vec3(0.7, 0.85, 0.9);
    float diffuseIrradianceFromEarth = (1.0 - horizonDotNadir) * (reflectionDotNadir * 0.25 + 0.75) * smoothstepHeight;
    float diffuseIrradianceFromSky = (1.0 - smoothstepHeight) * (1.0 - (reflectionDotNadir * 0.25 + 0.25));
    vec3 diffuseIrradiance = blueSkyDiffuseColor * clamp(diffuseIrradianceFromEarth + diffuseIrradianceFromSky, 0.0, 1.0);
    float notDistantRough = (1.0 - horizonDotNadir * roughness * 0.8);
    vec3 specularIrradiance = mix(zenithColor, aboveHorizonColor, smoothstep(farAboveHorizon, aroundHorizon, reflectionDotNadir) * notDistantRough);
    specularIrradiance = mix(specularIrradiance, belowHorizonColor, smoothstep(aroundHorizon, farBelowHorizon, reflectionDotNadir) * inverseRoughness);
    specularIrradiance = mix(specularIrradiance, nadirColor, smoothstep(farBelowHorizon, 1.0, reflectionDotNadir) * inverseRoughness);
    #ifdef USE_SUN_LUMINANCE
    float LdotZenith = clamp(dot(normalize(czm_inverseViewRotation * l), normalize(positionWC * -1.0)), 0.001, 1.0);
    float S = acos(LdotZenith);
    float NdotZenith = clamp(dot(normalize(czm_inverseViewRotation * n), normalize(positionWC * -1.0)), 0.001, 1.0);
    float gamma = acos(NdotL);
    float numerator = ((0.91 + 10.0 * exp(-3.0 * gamma) + 0.45 * pow(NdotL, 2.0)) * (1.0 - exp(-0.32 / NdotZenith)));
    float denominator = (0.91 + 10.0 * exp(-3.0 * S) + 0.45 * pow(LdotZenith,2.0)) * (1.0 - exp(-0.32));
    float luminance = gltf_luminanceAtZenith * (numerator / denominator);
    #endif
    vec2 brdfLut = texture2D(czm_brdfLut, vec2(NdotV, roughness)).rg;
    vec3 IBLColor = (diffuseIrradiance * diffuseColor * gltf_iblFactor.x) + (specularIrradiance * SRGBtoLINEAR3(specularColor * brdfLut.x + brdfLut.y) * gltf_iblFactor.y);
    float maximumComponent = max(max(lightColorHdr.x, lightColorHdr.y), lightColorHdr.z);
    vec3 lightColor = lightColorHdr / max(maximumComponent, 1.0);
    IBLColor *= lightColor;
    #ifdef USE_SUN_LUMINANCE
    color += IBLColor * luminance;
    #else
    color += IBLColor;
    #endif
    #elif defined(DIFFUSE_IBL) || defined(SPECULAR_IBL)
    mat3 fixedToENU = mat3(gltf_clippingPlanesMatrix[0][0], gltf_clippingPlanesMatrix[1][0], gltf_clippingPlanesMatrix[2][0],
    gltf_clippingPlanesMatrix[0][1], gltf_clippingPlanesMatrix[1][1], gltf_clippingPlanesMatrix[2][1],
    gltf_clippingPlanesMatrix[0][2], gltf_clippingPlanesMatrix[1][2], gltf_clippingPlanesMatrix[2][2]);
    const mat3 yUpToZUp = mat3(-1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0);
    vec3 cubeDir = normalize(yUpToZUp * fixedToENU * normalize(reflect(-v, n)));
    #ifdef DIFFUSE_IBL
    #ifdef CUSTOM_SPHERICAL_HARMONICS
    vec3 diffuseIrradiance = czm_sphericalHarmonics(cubeDir, gltf_sphericalHarmonicCoefficients);
    #else
    vec3 diffuseIrradiance = czm_sphericalHarmonics(cubeDir, czm_sphericalHarmonicCoefficients);
    #endif
    #else
    vec3 diffuseIrradiance = vec3(0.0);
    #endif
    #ifdef SPECULAR_IBL
    vec2 brdfLut = texture2D(czm_brdfLut, vec2(NdotV, roughness)).rg;
    #ifdef CUSTOM_SPECULAR_IBL
    vec3 specularIBL = czm_sampleOctahedralProjection(gltf_specularMap, gltf_specularMapSize, cubeDir,  roughness * gltf_maxSpecularLOD, gltf_maxSpecularLOD);
    #else
    vec3 specularIBL = czm_sampleOctahedralProjection(czm_specularEnvironmentMaps, czm_specularEnvironmentMapSize, cubeDir,  roughness * czm_specularEnvironmentMapsMaximumLOD, czm_specularEnvironmentMapsMaximumLOD);
    #endif
    specularIBL *= F * brdfLut.x + brdfLut.y;
    #else
    vec3 specularIBL = vec3(0.0);
    #endif
    color += diffuseIrradiance * diffuseColor + specularColor * specularIBL;
    #endif
    color += u_emissiveFactor;
    color = applyTonemapping(color);
    color = LINEARtoSRGB(color);
    gl_FragColor = vec4(color, 1.0);
}

void tile_color(vec4 tile_featureColor)
{
    tile_diffuse = tile_featureColor;
    tile_main();
    tile_featureColor = czm_gammaCorrect(tile_featureColor);
    gl_FragColor.a *= tile_featureColor.a;
    float highlight = ceil(tile_colorBlend);
    gl_FragColor.rgb *= mix(tile_featureColor.rgb, vec3(1.0), highlight);
}
uniform sampler2D tile_pickTexture;
varying vec2 tile_featureSt;
varying vec4 tile_featureColor;
void main()
{
    tile_color(tile_featureColor);
}