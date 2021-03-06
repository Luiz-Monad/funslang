% Fragment shader for drawing Mandelbrot sets
% Author: Ben Challenor
% Based on Julia.frag (GLSL) by 3Dlabs

let maxIterations = 50 in

\ (zoom, centerX, centerY, innerColor, outerColor1, outerColor2) ->
\ () ->
\ ([posX, posY]) ->

% starting values
let cReal = posX * zoom + centerX in
let cImag = posY * zoom + centerY in

% iteration function
let f (r, i, iter) =
  let rnew = r * r - i * i + cReal in
  let inew = 2 * r * i + cImag in
  let len2 = rnew * rnew + inew * inew in
    (len2 < 4.0, (rnew, inew, iter+1)) in

% iterate
let (rnew, inew, iter) = iterate f maxIterations (0, 0, 0) in

let basecolor =
  if iter == maxIterations
    then innerColor
    else zipWith (mix (iter / maxIterations)) outerColor1 outerColor2  in

  pad basecolor
