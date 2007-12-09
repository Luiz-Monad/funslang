module Representation where

data Token
  = TOK_BOOL
  | TOK_INT
  | TOK_FLOAT
  --
  | TOK_TEXTURE1D
  | TOK_TEXTURE2D
  | TOK_TEXTURE3D
  | TOK_TEXTURECUBE
  --
  | TOK_LITERAL_BOOL !Bool
  | TOK_LITERAL_INT !Integer     -- arbitrary precision
  | TOK_LITERAL_FLOAT !Double    -- better than machine precision
  --
  | TOK_IDENTIFIER !String
  --
  | TOK_COMMA
  | TOK_RANGE_DOTS
  | TOK_LBRACKET
  | TOK_RBRACKET
  | TOK_LPAREN
  | TOK_RPAREN
  --
  | TOK_OP_SUBSCRIPT
  | TOK_OP_SWIZZLE
  | TOK_OP_APPEND
  | TOK_OP_TRANSPOSE
  | TOK_OP_NOT
  | TOK_OP_MUL
  | TOK_OP_DIV
  | TOK_OP_LINEAR_MUL
  | TOK_OP_SCALE_MUL
  | TOK_OP_SCALE_DIV
  | TOK_OP_ADD
  | TOK_OP_NEG_OP_SUB
  | TOK_OP_LT
  | TOK_OP_GT
  | TOK_OP_LTE
  | TOK_OP_GTE
  | TOK_OP_EQ
  | TOK_OP_NEQ
  | TOK_OP_ID
  | TOK_OP_NID
  | TOK_OP_AND
  | TOK_OP_OR
  --
  | TOK_IF
  | TOK_THEN
  | TOK_ELSE
  | TOK_LET
  | TOK_EQUALS
  | TOK_IN
  --
  | TOK_TYPESPECIFIER
  | TOK_RARROW
  | TOK_LAMBDA
  
  deriving (Eq, Show)


data Type
  = UnitType
  | IntType
  | FloatType
  | BoolType
  | Texture1DType
  | Texture2DType
  | Texture3DType
  | TextureCubeType
  | TupleType ![Type]
  | ArrayType !Type !Integer
  | FunType !Type !Type
  
  deriving (Show, Eq)


type TypedIdent = (String, Type)


data Expr
  = UnitExpr
  | IntExpr !Integer
  | FloatExpr !Double
  | BoolExpr !Bool
  | VarExpr !String
  | AppOpExpr !Operator !Expr
  | AppExpr !Expr !Expr
  | ArrayExpr ![Expr]
  | ArrayCompExpr !Expr !String !Expr !Expr
  | TupleExpr ![Expr]
  | IfExpr !Expr !Expr !Expr
  | LetExpr !Patt !Expr !Expr
  | LambdaExpr ![TypedIdent] !Expr
  
  deriving (Show, Eq)


data Patt
  = VarPatt !String
  | ArrayPatt ![Patt]
  | TuplePatt ![Patt]
  
  deriving (Show, Eq)


data ProgramKind
  = VertProgram
  | FragProgram
  
  deriving (Show, Eq)


data Program
  = Program !Expr
  
  deriving (Show, Eq)


data Operator
  = OpSubscript
  | OpSwizzle
  | OpAppend
  | OpTranspose
  | OpNeg
  | OpNot
  | OpMul
  | OpDiv
  | OpLinearMul
  | OpScaleMul
  | OpScaleDiv
  | OpAdd
  | OpSub
  | OpLessThan
  | OpLessThanEqual
  | OpGreaterThan
  | OpGreaterThanEqual
  | OpEqual
  | OpNotEqual
  | OpIdentical
  | OpNotIdentical
  | OpAnd
  | OpOr
  
  deriving (Show, Eq)
