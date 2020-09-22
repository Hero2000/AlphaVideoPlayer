//
//  LHVideoGiftVertexShader.vsh
//  ktv
//
//  Created by 曾陆洋 on 2019/12/5.
//

attribute vec4 position;
attribute vec4 textureCoordinate;

varying vec2 textureCoordinateRGB;
varying vec2 textureCoordinateAlpha;

void main() {
    gl_Position = position;
    textureCoordinateAlpha = vec2(textureCoordinate.x, textureCoordinate.y);
    textureCoordinateRGB = vec2(textureCoordinate.x + 0.5, textureCoordinate.y);
}
