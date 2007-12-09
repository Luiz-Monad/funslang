{
module Parser(parser) where
import Representation
import Lexer
}

--------------------------------------------------------------------------------
-- Directives
--------------------------------------------------------------------------------

%tokentype { Token }

%token
  BOOL { TOK_BOOL }
  INT { TOK_INT }
  FLOAT { TOK_FLOAT }
  TEXTURE1D { TOK_TEXTURE1D }
  TEXTURE2D { TOK_TEXTURE2D }
  TEXTURE3D { TOK_TEXTURE3D }
  TEXTURECUBE { TOK_TEXTURECUBE }
  LITERAL_BOOL { TOK_LITERAL_BOOL $$ }
  LITERAL_INT { TOK_LITERAL_INT $$ }
  LITERAL_FLOAT { TOK_LITERAL_FLOAT $$ }
  IDENTIFIER { TOK_IDENTIFIER $$ }
  COMMA { TOK_COMMA }
  LBRACKET { TOK_LBRACKET }
  RBRACKET { TOK_RBRACKET }
  LPAREN { TOK_LPAREN }
  RPAREN { TOK_RPAREN }
  OP_SUBSCRIPT { TOK_OP_SUBSCRIPT }
  OP_SWIZZLE { TOK_OP_SWIZZLE }
  OP_APPEND { TOK_OP_APPEND }
  OP_TRANSPOSE { TOK_OP_TRANSPOSE }
  OP_NOT { TOK_OP_NOT }
  OP_MUL { TOK_OP_MUL }
  OP_DIV { TOK_OP_DIV }
  OP_LINEAR_MUL { TOK_OP_LINEAR_MUL }
  OP_SCALE_MUL { TOK_OP_SCALE_MUL }
  OP_SCALE_DIV { TOK_OP_SCALE_DIV }
  OP_ADD { TOK_OP_ADD }
  OP_NEG_OP_SUB { TOK_OP_NEG_OP_SUB }
  OP_LT { TOK_OP_LT }
  OP_GT { TOK_OP_GT }
  OP_LTE { TOK_OP_LTE }
  OP_GTE { TOK_OP_GTE }
  OP_EQ { TOK_OP_EQ }
  OP_NEQ { TOK_OP_NEQ }
  OP_ID { TOK_OP_ID }
  OP_NID { TOK_OP_NID }
  OP_AND { TOK_OP_AND }
  OP_OR { TOK_OP_OR }
  IF { TOK_IF }
  THEN { TOK_THEN }
  ELSE { TOK_ELSE }
  LET { TOK_LET }
  EQUALS { TOK_EQUALS }
  IN { TOK_IN }
  TYPESPECIFIER { TOK_TYPESPECIFIER }
  RARROW { TOK_RARROW }
  UNIFORM { TOK_UNIFORM }
  TEXTURE { TOK_TEXTURE }
  FUN { TOK_FUN }
  KERNEL { TOK_KERNEL }
  VERTEX { TOK_VERTEX }
  FRAGMENT { TOK_FRAGMENT }

%name parser program

%error { parseError }

%%

--------------------------------------------------------------------------------
-- Grammar
--------------------------------------------------------------------------------
-- Note:
-- Right recursion is avoided where possible.
-- This means that in some places, lists are constructed backwards and reversed.
--------------------------------------------------------------------------------

---
--- Types
---

tuple_type_inner :: { [Type] }
  : type COMMA type { $3:$1:[] }
  | tuple_type_inner COMMA type { $3:$1 }
  ;

tuple_type :: { Type }
  : LPAREN tuple_type_inner RPAREN { TupleType (reverse $2) }
  ;

array_type :: { Type }
  : primary_type LITERAL_INT { ArrayType $1 $2 } --todo: error on zero
  ;

primary_type :: { Type }
  : LPAREN RPAREN { UnitType }
  | INT { IntType }
  | FLOAT { FloatType }
  | BOOL { BoolType }
  | TEXTURE1D { Texture1DType }
  | TEXTURE2D { Texture2DType }
  | TEXTURE3D { Texture3DType }
  | TEXTURECUBE { TextureCubeType }
  | tuple_type { $1 }
  | array_type { $1 }
  | LPAREN type RPAREN { $2 }
  ;

type :: { Type } -- right recursion for right associativity
  : primary_type RARROW type { FunType $1 $3 }
  | primary_type { $1 }
  ;


---
--- Expressions
---

tuple_expr_inner :: { [Expr] }
  : expr COMMA expr { $3:$1:[] }
  | tuple_expr_inner COMMA expr { $3:$1 }
  ;

tuple_expr :: { Expr }
  : LPAREN tuple_expr_inner RPAREN { TupleExpr (reverse $2) }
  ;

array_expr_inner :: { [Expr] }
  : expr { $1:[] }
  | array_expr_inner COMMA expr { $3:$1 }
  ;

array_expr :: { Expr }
  : LBRACKET array_expr_inner RBRACKET { ArrayExpr (reverse $2) }
  ;

primary_expr :: { Expr }
  : LPAREN RPAREN { UnitExpr }
  | LITERAL_INT { IntExpr $1 }
  | LITERAL_FLOAT { FloatExpr $1 }
  | LITERAL_BOOL { BoolExpr $1 }
  | IDENTIFIER { VarExpr $1 }
  | tuple_expr { $1 }
  | array_expr { $1 }
  | LPAREN expr RPAREN { $2 }
  ;

postfix_expr :: { Expr }
  : postfix_expr OP_SUBSCRIPT primary_expr { AppOpExpr OpSubscript (TupleExpr [$1,$3]) }
  | postfix_expr OP_SWIZZLE primary_expr { AppOpExpr OpSwizzle (TupleExpr [$1,$3]) }
  | postfix_expr OP_APPEND primary_expr { AppOpExpr OpAppend (TupleExpr [$1,$3]) }
  | postfix_expr OP_TRANSPOSE { AppOpExpr OpTranspose $1 }
  | primary_expr { $1 }
  ;

prefix_expr :: { Expr }
  : OP_NEG_OP_SUB postfix_expr { AppOpExpr OpNeg $2 }
  | OP_NOT postfix_expr { AppOpExpr OpNot $2 }
  | IDENTIFIER postfix_expr { AppFnExpr $1 $2 }
  | postfix_expr { $1 }
  ;

multiplicative_expr :: { Expr }
  : multiplicative_expr OP_MUL prefix_expr { AppOpExpr OpMul (TupleExpr [$1,$3]) }
  | multiplicative_expr OP_DIV prefix_expr { AppOpExpr OpDiv (TupleExpr [$1,$3]) }
  | multiplicative_expr OP_LINEAR_MUL prefix_expr { AppOpExpr OpLinearMul (TupleExpr [$1,$3]) }
  | multiplicative_expr OP_SCALE_MUL prefix_expr { AppOpExpr OpScaleMul (TupleExpr [$1,$3]) }
  | multiplicative_expr OP_SCALE_DIV prefix_expr { AppOpExpr OpScaleDiv (TupleExpr [$1,$3]) }
  | prefix_expr { $1 }
  ;

additive_expr :: { Expr }
  : additive_expr OP_ADD multiplicative_expr { AppOpExpr OpAdd (TupleExpr [$1,$3]) }
  | additive_expr OP_NEG_OP_SUB multiplicative_expr { AppOpExpr OpSub (TupleExpr [$1,$3]) }
  | multiplicative_expr { $1 }
  ;

relational_expr :: { Expr }
  : relational_expr OP_LT additive_expr { AppOpExpr OpLessThan (TupleExpr [$1,$3]) }
  | relational_expr OP_GT additive_expr { AppOpExpr OpGreaterThan (TupleExpr [$1,$3]) }
  | relational_expr OP_LTE additive_expr { AppOpExpr OpLessThanEqual (TupleExpr [$1,$3]) }
  | relational_expr OP_GTE additive_expr { AppOpExpr OpGreaterThanEqual (TupleExpr [$1,$3]) }
  | additive_expr { $1 }
  ;

equality_expr :: { Expr }
  : equality_expr OP_EQ relational_expr { AppOpExpr OpEqual (TupleExpr [$1,$3]) }
  | equality_expr OP_NEQ relational_expr { AppOpExpr OpNotEqual (TupleExpr [$1,$3]) }
  | relational_expr { $1 }
  ;

identity_expr :: { Expr }
  : identity_expr OP_ID equality_expr { AppOpExpr OpIdentical (TupleExpr [$1,$3]) }
  | identity_expr OP_NID equality_expr { AppOpExpr OpNotIdentical (TupleExpr [$1,$3]) }
  | equality_expr { $1 }
  ;

logical_and_expr :: { Expr }
  : logical_and_expr OP_AND identity_expr { AppOpExpr OpAnd (TupleExpr [$1,$3]) }
  | identity_expr { $1 }
  ;

logical_or_expr :: { Expr }
  : logical_or_expr OP_OR logical_and_expr { AppOpExpr OpOr (TupleExpr [$1,$3]) }
  | logical_and_expr { $1 }
  ;

expr :: { Expr }
  : IF expr THEN expr ELSE expr { IfExpr $2 $4 $6 }
  | LET patt EQUALS expr IN expr { LetExpr $2 $4 $6 }
  | logical_or_expr { $1 }
  ;


---
--- Patterns (for let-bindings)
---

tuple_patt_inner :: { [Patt] }
  : patt COMMA patt { $3:$1:[] }
  | tuple_patt_inner COMMA patt { $3:$1 }
  ;

tuple_patt :: { Patt }
  : LPAREN tuple_patt_inner RPAREN { TuplePatt (reverse $2) }
  ;

array_patt_inner :: { [Patt] }
  : patt { $1:[] }
  | array_patt_inner COMMA patt { $3:$1 }
  ;

array_patt :: { Patt }
  : LBRACKET array_patt_inner RBRACKET { ArrayPatt (reverse $2) }
  ;

primary_patt :: { Patt }
  : IDENTIFIER { VarPatt $1 }
  | tuple_patt { $1 }
  | array_patt { $1 }
  | LPAREN patt RPAREN { $2 }
  ;

patt :: { Patt }
  : primary_patt { $1 }
  ;


---
--- Auxiliary declarations
---

uniform_decl :: { AuxDecl }
  : UNIFORM IDENTIFIER TYPESPECIFIER type { UniformDecl ($2,$4) }
  ;

texture_decl :: { AuxDecl }
  : TEXTURE IDENTIFIER TYPESPECIFIER type { TextureDecl ($2,$4) }
  ;

let_decl :: { AuxDecl }
  : LET patt EQUALS expr { LetDecl $2 $4 }
  ;

fun_param :: { TypedIdent }
  : IDENTIFIER TYPESPECIFIER type { ($1,$3) }
  ;

fun_params :: { [TypedIdent] }
  : fun_param { [$1] }
  | fun_params COMMA fun_param { $3:$1 }
  ;

fun_decl :: { AuxDecl }
  : FUN IDENTIFIER LPAREN fun_params RPAREN EQUALS expr { FunDecl $2 (reverse $4) $7 }
  ;

aux_decl :: { AuxDecl }
  : uniform_decl { $1 }
  | texture_decl { $1 }
  | let_decl { $1 }
  | fun_decl { $1 }
  ;

aux_decls :: { [AuxDecl] }
  : aux_decl { [$1] }
  | aux_decls aux_decl { $2:$1 }
  ;

aux_decls_opt :: { [AuxDecl] }
  : {- empty -} { [] }
  | aux_decls { reverse $1 }
  ;


---
--- Kernel declarations
---

vkernel_param :: { TypedIdent }
  : IDENTIFIER TYPESPECIFIER type { ($1,$3) }
  ;

vkernel_params :: { [TypedIdent] }
  : vkernel_param { [$1] }
  | vkernel_params COMMA vkernel_param { $3:$1 }
  ;

vkernel :: { (ProgramKind, KernelDecl) }
  : KERNEL VERTEX LPAREN RPAREN EQUALS expr { (VertProgram, KernelDecl [] $6) }
  | KERNEL VERTEX LPAREN vkernel_params RPAREN EQUALS expr { (VertProgram, KernelDecl (reverse $4) $7) }
  ;

fkernel_param :: { TypedIdent }
  : IDENTIFIER TYPESPECIFIER type { ($1,$3) }
  ;

fkernel_params :: { [TypedIdent] }
  : fkernel_param { [$1] }
  | fkernel_params COMMA fkernel_param { $3:$1 }
  ;

fkernel :: { (ProgramKind, KernelDecl) }
  : KERNEL FRAGMENT LPAREN RPAREN EQUALS expr { (FragProgram, KernelDecl [] $6) }
  | KERNEL FRAGMENT LPAREN fkernel_params RPAREN EQUALS expr { (FragProgram, KernelDecl (reverse $4) $7) }
  ;


---
--- Program
---

program :: { Program }
  : aux_decls_opt vkernel { let (kind, kernel) = $2 in Program kind $1 kernel }
  | aux_decls_opt fkernel { let (kind, kernel) = $2 in Program kind $1 kernel }
  ;


--------------------------------------------------------------------------------
-- Trailer
--------------------------------------------------------------------------------

{
parseError :: [Token] -> a
parseError []     = error ("Parse error at end of input")
parseError (t:ts) = error ("Parse error at token: " ++ show t)
}