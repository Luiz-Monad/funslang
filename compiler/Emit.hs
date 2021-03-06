-- This module emits GLSL code for the given dataflow graph.
-- Note:
-- - Real and Bool types are both packed as floats.
-- - Uniforms are packed in a single float array, arranged as a depth first
--   search of the uniforms tuple.
-- - Varyings/attributes are packed in groups of "maxPackingSize" into
--   float vectors. If there leftover varyings, they are packed into the
--   smallest float vector/scalar that will hold all of them.

module Emit(emit) where

import qualified Data.Map as Map
import qualified Data.IntMap as IntMap
import qualified Data.List as List
import Data.Graph
import Control.Exception
import Control.Monad.Error

import Representation
import Dataflow



emit :: ShaderKind -> InterpretState -> DFGraph -> Either CompileError String
emit sk si (g, result_ns, mvn) = do
  let vs = topSort g
  dflines <- mapM (\v -> case IntMap.lookup v mvn of Just n -> emitNode (sk, si) n; Nothing -> return $ "// node " ++ show v ++ " is not required") vs
  return $
    unlines $
      emitGlobalDecls sk si ++
      ["","void main()", "{"] ++
      emitTempDecls mvn ++
      [""] ++
      dflines ++
      [""] ++
      emitCopyOut sk si result_ns ++
      ["}"]


-- The names that GLSL gives to Funslang varyings.
emitVaryingQualifier :: ShaderKind -> String
emitVaryingQualifier ShaderKindVertex = "attribute"
emitVaryingQualifier ShaderKindFragment = "varying"

-- The size of the largest vector available for packing vertex attributes.
maxPackingSize :: Int
maxPackingSize = 4

-- Emits a vector type with n components.
emitPackingType :: Int -> String
emitPackingType 1 = "float"
emitPackingType n = assert (n > 0 && n <= maxPackingSize) "vec" ++ show n


-- These emit variable names.

emitRootNameUniform :: ShaderKind -> String
emitRootNameUniform ShaderKindVertex = "VertexUniforms"
emitRootNameUniform ShaderKindFragment = "FragmentUniforms"

emitNameUniform :: ShaderKind -> Int -> String
emitNameUniform sk i = emitRootNameUniform sk ++ "[" ++ show i ++ "]"

emitRootNameVarying :: ShaderKind -> String
emitRootNameVarying ShaderKindVertex = "VertexVaryings"
emitRootNameVarying ShaderKindFragment = "FragmentVaryings"

emitNameVarying :: ShaderKind -> Int -> Int -> String
emitNameVarying sk num_total i =
  let (d, m) = i `divMod` maxPackingSize in
    emitRootNameVarying sk ++ show (maxPackingSize * d) ++
      if i == (num_total - 1) && m == 0
        then "" -- no need to subscript: it's the last element, and that element is packed into a float
        else "[" ++ show m ++ "]"

emitNameTexture :: Int -> String
emitNameTexture i = "Tex" ++ show i

emitNameDFVertex :: Vertex -> String
emitNameDFVertex v = "t" ++ show v

emitNameDF :: DF -> String
emitNameDF n = emitNameDFVertex (nodeID n)

emitNameDFReal :: DFReal -> String
emitNameDFReal df = emitNameDF $ DFReal df

emitNameDFBool :: DFBool -> String
emitNameDFBool df = emitNameDF $ DFBool df

-- Unnecessary while GLSL textures are not first class values.
--emitNameDFTex :: DFTex -> String
--emitNameDFTex df = emitNameDF $ DFTex df

emitNameDFSample :: DFSample -> String
emitNameDFSample df = emitNameDF $ DFSample df


-- Emits a function call (using emitted strings).
emitStrFun :: String -> [String] -> String
emitStrFun f args = f ++ "(" ++ (concat $ List.intersperse ", " args) ++ ")"

-- Emits an assignment (using emitted strings).
emitStrAssign :: String -> String -> String
emitStrAssign d a = d ++ " = " ++ a ++ ";"


-- Emits a unary prefix operator, assigning its result.
emitUnOpAssign :: DF -> String -> DF -> String
emitUnOpAssign d op r = emitStrAssign (emitNameDF d) (op ++ " " ++ emitNameDF r)

-- Emits a binary infix operator, assigning its result.
emitBinOpAssign :: DF -> DF -> String -> DF -> String
emitBinOpAssign d l op r = emitStrAssign (emitNameDF d) (emitNameDF l ++ " " ++ op ++ " " ++ emitNameDF r)

-- Emits a function call, assigning its result.
emitFunAssign :: DF -> String -> [DF] -> String
emitFunAssign d f args = emitStrAssign (emitNameDF d) (emitStrFun f $ map emitNameDF args)


-- Emits uniforms declaration.
emitUniformsDecl :: ShaderKind -> InterpretState -> String
emitUniformsDecl sk si =
  let n = num_uniforms si in
    if n <= 0
      then "// no uniforms"
      else "uniform float " ++ emitNameUniform sk n ++ ";"

-- Emits varying declarations (for both input and output).
emitVaryingsDecls :: ShaderKind -> InterpretState -> [String]
emitVaryingsDecls ShaderKindVertex si = emitVaryingsDecls' ShaderKindVertex (num_varyings si) ++ emitVaryingsDecls' ShaderKindFragment (num_generic_outputs si)
emitVaryingsDecls ShaderKindFragment si = emitVaryingsDecls' ShaderKindFragment (num_varyings si)

emitVaryingsDecls' :: ShaderKind -> Int -> [String]
emitVaryingsDecls' sk num_total = emitVaryingsDecls'' sk num_total 0 []

emitVaryingsDecls'' :: ShaderKind -> Int -> Int -> [String] -> [String]
emitVaryingsDecls'' sk num_total num_packed acc =
  let num_left = num_total - num_packed in
    if num_left <= 0
      then acc
      else
        let num_now = min num_left maxPackingSize in
        let decl = emitVaryingQualifier sk ++ " " ++ emitPackingType num_now ++ " " ++ emitRootNameVarying sk ++ show num_packed ++ ";" in
          emitVaryingsDecls'' sk num_total (num_packed + num_now) (decl : acc)

-- Emits texture declarations.
emitTextureDecls :: InterpretState -> [String]
emitTextureDecls si = map emitTextureDecl (textures si)

emitTextureDecl :: (TexKind, Int) -> String
emitTextureDecl (tk, i) = "uniform sampler" ++ show tk ++ " " ++ emitNameTexture i ++ ";"

-- Emits all relevant global declarations.
emitGlobalDecls :: ShaderKind -> InterpretState -> [String]
emitGlobalDecls sk si = emitUniformsDecl sk si : emitTextureDecls si ++ emitVaryingsDecls sk si

-- Emits temporary declarations.
emitTempDecls :: IntMap.IntMap DF -> [String]
emitTempDecls mvn =
  let mtl = accumTempDecls mvn in
    map emitTempDecl (Map.assocs mtl)

emitTempDecl :: (String, [String]) -> String
emitTempDecl (t, []) = "// no " ++ t
emitTempDecl (t, xs) = concat $ t : " " : List.intersperse ", " xs ++ [";"]

-- Takes a mapping from locations to nodes,
-- and returns a mapping from GLSL types to GLSL locations.
-- This allows all decls of a single GLSL type to be made together.
accumTempDecls :: IntMap.IntMap DF -> Map.Map String [String]
accumTempDecls mvn = let (mtl, _) = IntMap.mapAccumWithKey accumTempDecls' (Map.empty) mvn in mtl

-- The sampler case below must remain commented out until GLSL allows
-- textures as first class values. If this ever occurs, it will be trivial to support:
-- just change the DFTexCond in emitNode below to make it like DFRealCond/DFBoolCond.
accumTempDecls' :: Map.Map String [String] -> Vertex -> DF -> (Map.Map String [String], ())
accumTempDecls' mtl v (DFReal _) = (Map.alter (accumTempDecls'' v) "float" mtl, ())
accumTempDecls' mtl v (DFBool _) = (Map.alter (accumTempDecls'' v) "bool" mtl, ())
accumTempDecls' mtl v (DFTex dft) = (Map.alter (accumTempDecls'' v) ("//sampler" ++ show (getTexKindOfDFTex dft)) mtl, ())
accumTempDecls' mtl v (DFSample _) = (Map.alter (accumTempDecls'' v) "vec4" mtl, ())

accumTempDecls'' :: Vertex -> Maybe [String] -> Maybe [String]
accumTempDecls'' v (Just ls) = Just (emitNameDFVertex v : ls)
accumTempDecls'' v Nothing = Just [emitNameDFVertex v]


-- Takes a list of coordinates and wraps them as a single GLSL type.
emitWrappedCoords :: [String] -> String
emitWrappedCoords [p] = p
emitWrappedCoords [p,q] = "vec2(" ++ p ++ ", " ++ q ++ ")"
emitWrappedCoords [p,q,r] = "vec3(" ++ p ++ ", " ++ q ++ ", " ++ r ++ ")"
emitWrappedCoords _ = error "bad coords in emitWrappedCoords!"


-- Emits the operation represented by a DF.
emitNode :: (ShaderKind, InterpretState) -> DF -> Either CompileError String

emitNode (_, _) n@(DFReal (DFRealLiteral _ d)) = return $ emitStrAssign (emitNameDF n) $ show d
emitNode (sk, si) n@(DFReal (DFRealVarying _ i)) = return $ emitStrAssign (emitNameDF n) $ emitNameVarying sk (num_varyings si) i
emitNode (sk, _) n@(DFReal (DFRealUniform _ i)) = return $ emitStrAssign (emitNameDF n) $ emitNameUniform sk i

emitNode (_, _) n@(DFReal (DFRealCond _ cond p q)) = return $ emitStrAssign (emitNameDF n) $ (emitNameDFBool cond) ++ " ? " ++ (emitNameDFReal p) ++ " : " ++ (emitNameDFReal q)

emitNode (_, _) n@(DFReal (DFRealAdd _ p q)) = return $ emitBinOpAssign n (DFReal p) "+" (DFReal q)
emitNode (_, _) n@(DFReal (DFRealSub _ p q)) = return $ emitBinOpAssign n (DFReal p) "-" (DFReal q)
emitNode (_, _) n@(DFReal (DFRealMul _ p q)) = return $ emitBinOpAssign n (DFReal p) "*" (DFReal q)
emitNode (_, _) n@(DFReal (DFRealDiv _ p q)) = return $ emitBinOpAssign n (DFReal p) "/" (DFReal q)
emitNode (_, _) n@(DFReal (DFRealNeg _ p)) = return $ emitUnOpAssign n "-" (DFReal p)
emitNode (_, _) n@(DFReal (DFRealRcp _ p)) = return $ emitStrAssign (emitNameDF n) $ "1 / " ++ (emitNameDFReal p)
emitNode (_, _) n@(DFReal (DFRealRsq _ p)) = return $ emitFunAssign n "inversesqrt" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealAbs _ p)) = return $ emitFunAssign n "abs" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealMin _ p q)) = return $ emitFunAssign n "min" [DFReal p, DFReal q]
emitNode (_, _) n@(DFReal (DFRealMax _ p q)) = return $ emitFunAssign n "max" [DFReal p, DFReal q]
emitNode (_, _) n@(DFReal (DFRealFloor _ p)) = return $ emitFunAssign n "floor" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealCeiling _ p)) = return $ emitFunAssign n "ceil" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealRound _ p)) = return $ emitStrAssign (emitNameDF n) ("float(int(" ++ emitNameDFReal p ++ " + (" ++ emitNameDFReal p ++ " < 0 ? -0.5 : 0.5)))")
emitNode (_, _) n@(DFReal (DFRealTruncate _ p)) = return $ emitStrAssign (emitNameDF n) ("float(int(" ++ emitNameDFReal p ++ "))")
emitNode (_, _) n@(DFReal (DFRealFract _ p)) = return $ emitFunAssign n "fract" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealExp _ p)) = return $ emitFunAssign n "exp" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealExp2 _ p)) = return $ emitFunAssign n "exp2" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealLog _ p)) = return $ emitFunAssign n "log" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealLog2 _ p)) = return $ emitFunAssign n "log2" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealPow _ p q)) = return $ emitFunAssign n "pow" [DFReal p, DFReal q]
emitNode (_, _) n@(DFReal (DFRealSin _ p)) = return $ emitFunAssign n "sin" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealCos _ p)) = return $ emitFunAssign n "cos" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealTan _ p)) = return $ emitFunAssign n "tan" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealASin _ p)) = return $ emitFunAssign n "asin" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealACos _ p)) = return $ emitFunAssign n "acos" [DFReal p]
emitNode (_, _) n@(DFReal (DFRealATan _ p)) = return $ emitFunAssign n "atan" [DFReal p]

emitNode (_, _) n@(DFReal (DFRealChannelR _ p)) = return $ emitStrAssign (emitNameDF n) (emitNameDFSample p ++ ".r")
emitNode (_, _) n@(DFReal (DFRealChannelG _ p)) = return $ emitStrAssign (emitNameDF n) (emitNameDFSample p ++ ".g")
emitNode (_, _) n@(DFReal (DFRealChannelB _ p)) = return $ emitStrAssign (emitNameDF n) (emitNameDFSample p ++ ".b")
emitNode (_, _) n@(DFReal (DFRealChannelA _ p)) = return $ emitStrAssign (emitNameDF n) (emitNameDFSample p ++ ".a")

emitNode (_, _) n@(DFBool (DFBoolLiteral _ b)) = return $ emitStrAssign (emitNameDF n) $ show b
emitNode (sk, si) n@(DFBool (DFBoolVarying _ i)) = return $ emitStrAssign (emitNameDF n) $ "bool(" ++ emitNameVarying sk (num_varyings si) i ++ ")"
emitNode (sk, _) n@(DFBool (DFBoolUniform _ i)) = return $ emitStrAssign (emitNameDF n) $ "bool(" ++ emitNameUniform sk i ++ ")"

emitNode (_, _) n@(DFBool (DFBoolCond _ cond p q)) = return $ emitStrAssign (emitNameDF n) $ (emitNameDFBool cond) ++ " ? " ++ (emitNameDFBool p) ++ " : " ++ (emitNameDFBool q)

emitNode (_, _) n@(DFBool (DFBoolLessThan _ p q)) = return $ emitBinOpAssign n (DFReal p) "<" (DFReal q)
emitNode (_, _) n@(DFBool (DFBoolLessThanEqual _ p q)) = return $ emitBinOpAssign n (DFReal p) "<=" (DFReal q)
emitNode (_, _) n@(DFBool (DFBoolGreaterThan _ p q)) = return $ emitBinOpAssign n (DFReal p) ">" (DFReal q)
emitNode (_, _) n@(DFBool (DFBoolGreaterThanEqual _ p q)) = return $ emitBinOpAssign n (DFReal p) ">=" (DFReal q)

emitNode (_, _) n@(DFBool (DFBoolEqualReal _ p q)) = return $ emitBinOpAssign n (DFReal p) "==" (DFReal q)
emitNode (_, _) n@(DFBool (DFBoolNotEqualReal _ p q)) = return $ emitBinOpAssign n (DFReal p) "!=" (DFReal q)
emitNode (_, _) n@(DFBool (DFBoolEqualBool _ p q)) = return $ emitBinOpAssign n (DFBool p) "==" (DFBool q)
emitNode (_, _) n@(DFBool (DFBoolNotEqualBool _ p q)) = return $ emitBinOpAssign n (DFBool p) "!=" (DFBool q)
emitNode (_, _) n@(DFBool (DFBoolEqualTex _ p q)) = return $ emitBinOpAssign n (DFTex p) "==" (DFTex q)
emitNode (_, _) n@(DFBool (DFBoolNotEqualTex _ p q)) = return $ emitBinOpAssign n (DFTex p) "!=" (DFTex q)

emitNode (_, _) n@(DFBool (DFBoolAnd _ p q)) = return $ emitBinOpAssign n (DFBool p) "&&" (DFBool q)
emitNode (_, _) n@(DFBool (DFBoolOr _ p q)) = return $ emitBinOpAssign n (DFBool p) "||" (DFBool q)
emitNode (_, _) n@(DFBool (DFBoolNot _ p)) = return $ emitUnOpAssign n "!" (DFBool p)

emitNode (_, _) n@(DFTex (DFTexConstant _ _ _)) = return $ "// noting texture: " ++ show n
emitNode (_, _) (DFTex (DFTexCond _ _ _ _)) = throwError $ TargetError $ TargetErrorGLSLDynamicTextureSelection

emitNode (_, _) n@(DFSample (DFSampleTex _ (DFTexConstant _ tk i) coords)) = return $ emitStrAssign (emitNameDF n) (emitStrFun ("texture" ++ show tk) [emitNameTexture i, emitWrappedCoords $ map emitNameDFReal coords])
emitNode (_, _) (DFSample (DFSampleTex _ _ _)) = throwError $ TargetError $ TargetErrorGLSLDynamicTextureSelection


-- Emits copy out code to save results.
emitCopyOut :: ShaderKind -> InterpretState -> [DF] -> [String]
emitCopyOut ShaderKindVertex si (x:y:z:w : output_varyings) =
  (emitStrAssign "gl_Position" $ "vec4(" ++ emitNameDF x ++ ", " ++ emitNameDF y ++ ", " ++ emitNameDF z ++ ", " ++ emitNameDF w ++ ")") :
  zipWith (\n i -> emitStrAssign (emitNameVarying ShaderKindFragment (num_generic_outputs si) i) (emitNameDF n)) output_varyings [0..]
emitCopyOut ShaderKindVertex _ _ = undefined
emitCopyOut ShaderKindFragment _ (r:g:b:a:[]) =
  (emitStrAssign "gl_FragColor" $ "vec4(" ++ emitNameDF r ++ ", " ++ emitNameDF g ++ ", " ++ emitNameDF b ++ ", " ++ emitNameDF a ++ ")") :
  []
emitCopyOut ShaderKindFragment si (cond:rest) =
  ("if (!" ++ emitNameDF cond ++ ") discard;") :
  emitCopyOut ShaderKindFragment si rest
emitCopyOut ShaderKindFragment _ _ = undefined
