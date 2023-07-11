with GCS.Lexer;
with GCS.Styles;
with GCS.Ada_Tokens;                    use GCS.Ada_Tokens;


package GCS.Ada_Lexical is
  new GCS.Lexer (Token              => Token,
                 Tok_None           => Tok_None,
                 Tok_End_Of_File    => Tok_End_Of_File,
                 Tok_Bad_Character  => Tok_Bad_Character,
                 Tok_Identifier     => Tok_Identifier,
                 Tok_String         => Tok_String,
                 Tok_Character      => Tok_Character,
                 Tok_Integer        => Tok_Integer,
                 Tok_Float          => Tok_Float,
                 First_Keyword      => Tok_Abort,
                 Keywords           => "abort abs abstract accept access " &
                                       "aliased all and array at begin " &
                                       "body case constant declare delay " &
                                       "delta digits do else elsif end " &
                                       "entry exception exit for function " &
                                       "generic goto if in is limited " &
                                       "loop mod new not null of or " &
                                       "others out package pragma private " &
                                       "procedure protected raise range " &
                                       "record rem renames requeue return " &
                                       "reverse select separate subtype " &
                                       "tagged task terminate then type " &
                                       "until use when while with xor",
                 First_Symbol       => Tok_Semi,
                 Symbols            => "; ) := .. : <> << >> , => + - * / " &
                                       "<= >= /= = > < ** & ( . '",

                 Identifier_Start   => "abcdefghijklmnopqrstuvwxyz" &
                                       "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                 Identifier_Body    => "abcdefghijklmnopqrstuvwxyz" &
                                       "ABCDEFGHIJKLMNOPQRSTUVWXYZ" &
                                       "0123456789" &
                                       "_",
                 Line_Comment_Start => "--",
                 Properties         => GCS.Styles.Ada_Property_List);
