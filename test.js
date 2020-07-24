//3dTile设置按时间进行颜色渲染，存在渲染效率低的问题
function colorByHeight() {
    var num=1;
    var count=0;
    setInterval(()=>{
        num = Math.abs(Math.sin(count));
        count+=0.005;
        tileset.style = new Cesium.Cesium3DTileStyle({
            color: {
                conditions: [
                    ["${Height} >= 300", `rgba(45,194,255,${num})`],
                    ["${Height} >= 200", `rgba(33,88,151,${num})`],
                    ["${Height} >= 100", `rgba(101,105,204,${num})`],
                    ["${Height} >= 50", `rgba(174,97,238,${num})`],
                    ["${Height} >= 25", `rgba(59,252,242,${num})`],
                    ["${Height} >= 10", `rgba(35,248,192,${num})`],
                    ["${Height} >= 5", `rgba(27,198,76,${num})`],
                    ["true", `rgba(15,127,68,${num})`],
                ],
            },
        });
    },32);
}

//光效 测试失败
var blurX = new Cesium.PostProcessStage({
    name : 'blur_x_direction',
    fragmentShader : fragmentShaderSource,
    uniforms: {
        width : width,
        height : height,
        colorTexture1:"Bright"
    }
});

var fragmentShaderSource = "uniform float height;\n" +
    "uniform float width;\n" +
    "uniform sampler2D colorTexture1;\n" +
    "\n" +
    "varying vec2 v_textureCoordinates;\n" +
    "\n" +
    "const int SAMPLES = 9;\n" +
    "void main()\n" +
    "{\n" +
    "vec2 st = v_textureCoordinates;\n" +
    "float wr = float(1.0 / width);\n" +
    "float hr = float(1.0 / height);\n" +
    "vec4 result = vec4(0.0);\n" +
    "int count = 0;\n" +
    "for(int i = -SAMPLES; i <= SAMPLES; ++i){\n" +
    "for(int j = -SAMPLES; j <= SAMPLES; ++j){\n" +
    "vec2 offset = vec2(float(i) * wr, float(j) * hr);\n" +
    "result += texture2D(colorTexture1, st + offset);\n" +
    "++count;\n" +
    "}\n" +
    "}\n" +
    "result = result / float(count);\n" +
    "gl_FragColor = result;\n" +
    "}";

viewer.scene.postProcessStages.add(
    new Cesium.PostProcessStage({
        fragmentShader: fragmentShaderSource1,
    })
);
//雾气效果代码
var fragmentShaderSource1 = "  uniform sampler2D colorTexture;\n" +
    "  uniform sampler2D depthTexture;\n" +
    "  varying vec2 v_textureCoordinates;\n" +
    "  void main(void)\n" +
    "  {\n" +
    "      vec4 origcolor=texture2D(colorTexture, v_textureCoordinates);\n" +
    "      vec4 fogcolor=vec4(0.8,0.8,0.8,0.5);\n" +
    "\n" +
    "      float depth = czm_readDepth(depthTexture, v_textureCoordinates);\n" +
    "      vec4 depthcolor=texture2D(depthTexture, v_textureCoordinates);\n" +
    "\n" +
    "      float f=(depthcolor.r-0.2)/0.5;\n" +
    "      if(depth<10.0) f=0.0;\n" +
    "      else if(depth>100000.0) f=0.0;\n" +
    "      gl_FragColor = mix(origcolor,fogcolor,f);\n" +
    "   }";

//下雪效果代码
var fragmentShaderSource2 = " uniform sampler2D colorTexture; //输入的场景渲染照片\n" +
    " varying vec2 v_textureCoordinates;\n" +
    " \n" +
    " float snow(vec2 uv,float scale)\n" +
    " {\n" +
    "     float time = czm_frameNumber / 60.0;\n" +
    "     float w=smoothstep(1.,0.,-uv.y*(scale/10.));if(w<.1)return 0.;\n" +
    "     uv+=time/scale;uv.y+=time*2./scale;uv.x+=sin(uv.y+time*.5)/scale;\n" +
    "     uv*=scale;vec2 s=floor(uv),f=fract(uv),p;float k=3.,d;\n" +
    "     p=.5+.35*sin(11.*fract(sin((s+p+scale)*mat2(7,3,6,5))*5.))-f;d=length(p);k=min(d,k);\n" +
    "     k=smoothstep(0.,k,sin(f.x+f.y)*0.01);\n" +
    "     return k*w;\n" +
    " }\n" +
    " \n" +
    " void main(void){\n" +
    "     vec2 resolution = czm_viewport.zw;\n" +
    "     vec2 uv=(gl_FragCoord.xy*2.-resolution.xy)/min(resolution.x,resolution.y);\n" +
    "     vec3 finalColor=vec3(0);\n" +
    "     //float c=smoothstep(1.,0.3,clamp(uv.y*.3+.8,0.,.75));\n" +
    "     float c = 0.0;\n" +
    "     c+=snow(uv,30.)*.0;\n" +
    "     c+=snow(uv,20.)*.0;\n" +
    "     c+=snow(uv,15.)*.0;\n" +
    "     c+=snow(uv,10.);\n" +
    "     c+=snow(uv,8.);\n" +
    "     c+=snow(uv,6.);\n" +
    "     c+=snow(uv,5.);\n" +
    "     finalColor=(vec3(c)); //屏幕上雪的颜色\n" +
    "     gl_FragColor = mix(texture2D(colorTexture, v_textureCoordinates), vec4(finalColor,1), 0.5);  //将雪和三维场景融合\n" +
    " \n" +
    " }";

//下雨效果代码
var fragmentShaderSource3 = "uniform sampler2D colorTexture;//输入的场景渲染照片\n" +
    " varying vec2 v_textureCoordinates;\n" +
    " \n" +
    " float hash(float x){\n" +
    "     return fract(sin(x*133.3)*13.13);\n" +
    " }\n" +
    " \n" +
    " void main(void){\n" +
    " \n" +
    "     float time = czm_frameNumber / 60.0;\n" +
    "     vec2 resolution = czm_viewport.zw;\n" +
    " \n" +
    "     vec2 uv=(gl_FragCoord.xy*2.-resolution.xy)/min(resolution.x,resolution.y);\n" +
    "     vec3 c=vec3(.6,.7,.8);\n" +
    " \n" +
    "     float a=-.4;\n" +
    "     float si=sin(a),co=cos(a);\n" +
    "     uv*=mat2(co,-si,si,co);\n" +
    "     uv*=length(uv+vec2(0,4.9))*.3+1.;\n" +
    " \n" +
    "     float v=1.-sin(hash(floor(uv.x*100.))*2.);\n" +
    "     float b=clamp(abs(sin(20.*time*v+uv.y*(5./(2.+v))))-.95,0.,1.)*20.;\n" +
    "     c*=v*b; //屏幕上雨的颜色\n" +
    " \n" +
    "     gl_FragColor = mix(texture2D(colorTexture, v_textureCoordinates), vec4(c,1), 0.5); //将雨和三维场景融合\n" +
    "}";

