{
module Parser(parseVShader, parseFShader) where
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
  LITERAL_BOOL { TOK_LITERAL_BOOL }
  LITERAL_INT { TOK_LITERAL_INT }
  LITERAL_FLOAT { TOK_LITERAL_FLOAT }
  IDENTIFIER { TOK_IDENTIFIER }
  COMMA { TOK_COMMA }
  VERTICAL_BAR { TOK_VERTICAL_BAR }
  LBRACKET { TOK_LBRACKET }
  RBRACKET { TOK_RBRACKET }
  LPAREN { TOK_LPAREN }
  RPAREN { TOK_RPAREN }
  OP_SUBSCRIPT { TOK_OP_SUBSCRIPT }
  OP_SWIZZLE { TOK_OP_SWIZZLE }
  OP_APPEND { TOK_OP_APPEND }
  OP_TRANSPOSE { TOK_OP_TRANSPOSE }
  OP_MUL { TOK_OP_MUL }
  OP_DIV { TOK_OP_DIV }
  OP_LINEAR_MUL { TOK_OP_LINEAR_MUL }
  OP_SCALE_MUL { TOK_OP_SCALE_MUL }
  OP_SCALE_DIV { TOK_OP_SCALE_DIV }
  OP_ADD { TOK_OP_ADD }
  OP_SUBNEG { TOK_OP_SUBNEG }
  OP_LT { TOK_OP_LT }
  OP_GT { TOK_OP_GT }
  OP_LTE { TOK_OP_LTE }
  OP_GTE { TOK_OP_GTE }
  OP_EQ { TOK_OP_EQ }
  OP_NEQ { TOK_OP_NEQ }
  OP_ID { TOK_OP_ID }
  OP_NID { TOK_OP_NID }
  OP_AND { TOK_OP_AND }
  OP_XOR { TOK_OP_XOR }
  OP_OR { TOK_OP_OR }
  IF { TOK_IF }
  THEN { TOK_THEN }
  ELSE { TOK_ELSE }
  LET { TOK_LET }
  EQUALS { TOK_EQUALS }
  IN { TOK_IN }
  UPTO { TOK_UPTO }
  TYPESPECIFIER { TOK_TYPESPECIFIER }
  UNIFORM { TOK_UNIFORM }
  TEXTURE { TOK_TEXTURE }
  FUN { TOK_FUN }
  KERNEL { TOK_KERNEL }
  VSHADER { TOK_VSHADER }
  FSHADER { TOK_FSHADER }

%name parseVShader vshader
%name parseFShader fshader


%%

--------------------------------------------------------------------------------
-- Grammar
--------------------------------------------------------------------------------

---
--- Types
---

texture_type
  : TEXTURE1D
  | TEXTURE2D
  | TEXTURE3D
  | TEXTURECUBE
  | texture_type LITERAL_INT
  ;

boolean_type
  : BOOL
  | boolean_type LITERAL_INT
  ;

integral_type
  : INT
  | integral_type LITERAL_INT
  ;

floating_type
  : FLOAT
  | floating_type LITERAL_INT
  ;

arithboolean_type
  : boolean_type
  | integral_type
  | floating_type
  ;

basic_type
  : boolean_type
  | integral_type
  | floating_type
  | texture_type
  ;


---
--- Expressions
---

--- single expressions (i.e. not n-tuples)

arr_inner_expr
  : single_expr
  | arr_inner_expr COMMA single_expr
  ;

arr_constructor_expr
  : LBRACKET arr_inner_expr RBRACKET
  ;

arr_comprehension_expr
  : LBRACKET single_expr VERTICAL_BAR generator RBRACKET
  ;

primary_expr
  : LITERAL_INT
  | LITERAL_BOOL
  | LITERAL_FLOAT
  | LPAREN RPAREN
  | arr_constructor_expr
  | arr_comprehension_expr
  | IDENTIFIER
  | LPAREN expr RPAREN
  ;

postfix_expr
  : postfix_expr OP_SUBSCRIPT primary_expr
  | postfix_expr OP_SWIZZLE primary_expr
  | postfix_expr OP_APPEND primary_expr
  | postfix_expr OP_TRANSPOSE
  | primary_expr
  ;

prefix_expr
  : OP_SUBNEG postfix_expr
  | IDENTIFIER postfix_expr
  | postfix_expr
  ;

multiplicative_expr
  : multiplicative_expr OP_MUL prefix_expr
  | multiplicative_expr OP_DIV prefix_expr
  | multiplicative_expr OP_LINEAR_MUL prefix_expr
  | multiplicative_expr OP_SCALE_MUL prefix_expr
  | multiplicative_expr OP_SCALE_DIV prefix_expr
  | prefix_expr
  ;

additive_expr
  : additive_expr OP_ADD multiplicative_expr
  | additive_expr OP_SUBNEG multiplicative_expr
  | multiplicative_expr
  ;

relational_expr
  : relational_expr OP_LT additive_expr
  | relational_expr OP_GT additive_expr
  | relational_expr OP_LTE additive_expr
  | relational_expr OP_GTE additive_expr
  | additive_expr
  ;

equality_expr
  : equality_expr OP_EQ relational_expr
  | equality_expr OP_NEQ relational_expr
  | relational_expr
  ;

identity_expr
  : identity_expr OP_ID equality_expr
  | identity_expr OP_NID equality_expr
  | equality_expr
  ;

logical_and_expr
  : logical_and_expr OP_AND identity_expr
  | identity_expr
  ;

logical_xor_expr
  : logical_xor_expr OP_XOR logical_and_expr
  | logical_and_expr
  ;

logical_or_expr
  : logical_or_expr OP_OR logical_xor_expr
  | logical_xor_expr
  ;

single_expr
  : IF expr THEN expr ELSE expr
  | LET pattern EQUALS expr IN expr
  | logical_or_expr
  ;

--- n-tuple expressions

expr
  : single_expr
  | expr COMMA single_expr
  ;


---
--- Generators
---

generator
  : IDENTIFIER EQUALS expr UPTO expr
  ;


---
--- Patterns (for let-bindings)
---

arr_inner_pattern
  : single_pattern
  | arr_inner_pattern COMMA single_pattern
  ;

arr_constructor_pattern
  : LBRACKET arr_inner_pattern RBRACKET
  ;

primary_pattern
  : arr_constructor_pattern
  | IDENTIFIER
  | LPAREN pattern RPAREN
  ;

single_pattern
  : primary_pattern
  ;

pattern
  : single_pattern
  | pattern COMMA single_pattern
  ;

---
--- Uniform declarations
---

uniform_decl
  : UNIFORM IDENTIFIER TYPESPECIFIER arithboolean_type
  ;

uniform_decls
  : uniform_decl
  | uniform_decls uniform_decl
  ;


---
--- Texture declarations
---

texture_decl
  : TEXTURE IDENTIFIER TYPESPECIFIER texture_type
  ;

texture_decls
  : texture_decl
  | texture_decls texture_decl
  ;


---
--- Top-level let bindings
---

let_binding
  : LET pattern EQUALS expr
  ;

let_bindings
  : let_binding
  | let_bindings let_binding
  ;


---
--- Function definitions
---

fun_param
  : IDENTIFIER TYPESPECIFIER basic_type
  ;

fun_params
  : fun_param
  | fun_params COMMA fun_param
  ;

fun_def
  : FUN IDENTIFIER LPAREN fun_params RPAREN EQUALS expr
  ;

fun_defs
  : fun_def
  | fun_defs fun_def
  ;


---
--- Vertex shader kernel
---

vkernel_param
  : IDENTIFIER TYPESPECIFIER arithboolean_type
  ;

vkernel_params
  : vkernel_param
  | vkernel_params COMMA vkernel_param
  ;

vkernel
  : KERNEL VSHADER LPAREN RPAREN EQUALS expr
  | KERNEL VSHADER LPAREN vkernel_params RPAREN EQUALS expr
  ;


---
--- Fragment shader kernel
---

fkernel_param
  : IDENTIFIER TYPESPECIFIER floating_type
  ;

fkernel_params
  : fkernel_param
  | fkernel_params COMMA fkernel_param
  ;

fkernel
  : KERNEL FSHADER LPAREN RPAREN EQUALS expr
  | KERNEL FSHADER LPAREN fkernel_params RPAREN EQUALS expr
  ;


---
--- Shaders
---

vshader
  : uniform_decls texture_decls let_bindings fun_defs vkernel
  ;

fshader
  : uniform_decls texture_decls let_bindings fun_defs fkernel
  ;
