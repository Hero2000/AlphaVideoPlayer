//
//  LHVideoGiftFragmentShader.fsh
//  ktv
//
//  Created by 曾陆洋 on 2019/12/5.
//

varying highp vec2 textureCoordinateRGB;
varying highp vec2 textureCoordinateAlpha;

uniform sampler2D inputImageTexture;

void main() {
    highp vec4 rgbColor = texture2D(inputImageTexture, textureCoordinateRGB);
    highp vec4 alphaColor = texture2D(inputImageTexture, textureCoordinateAlpha);
    gl_FragColor = vec4(rgbColor.r, rgbColor.g, rgbColor.b, alphaColor.r);
}
