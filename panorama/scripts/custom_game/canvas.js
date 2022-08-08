'use strict';

// 五个参数 第一个数组长度 第二个数组 第三个笔画粗细度 第四个为止 第五个颜色
var x = [[10,10],[20,20]];
var color = "#4e6ef2";
UICanvas.DrawSoftLinePointsJS( x.length, x , 2, 10, color);

$.Msg( "mycanvas!" );