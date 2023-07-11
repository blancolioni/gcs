package GCS.Ada_Tokens is

   pragma Pure (GCS.Ada_Tokens);

   type Token is
      (Tok_None, Tok_Bad_Character,
       Tok_Identifier,

       Tok_Integer, Tok_Character, Tok_String, Tok_Float,

       Tok_Abort, Tok_Abs, Tok_Abstract, Tok_Accept, Tok_Access,
       Tok_Aliased, Tok_All, Tok_And, Tok_Array, Tok_At, Tok_Begin,
       Tok_Body, Tok_Case, Tok_Constant, Tok_Declare, Tok_Delay,
       Tok_Delta, Tok_Digits, Tok_Do, Tok_Else, Tok_Elsif, Tok_End,
       Tok_Entry, Tok_Exception, Tok_Exit, Tok_For, Tok_Function,
       Tok_Generic, Tok_Goto, Tok_If, Tok_In, Tok_Is, Tok_Limited,
       Tok_Loop, Tok_Mod, Tok_New, Tok_Not, Tok_Null, Tok_Of, Tok_Or,
       Tok_Others, Tok_Out, Tok_Package, Tok_Pragma, Tok_Private,
       Tok_Procedure, Tok_Protected, Tok_Raise, Tok_Range,
       Tok_Record, Tok_Rem, Tok_Renames, Tok_Requeue, Tok_Return,
       Tok_Reverse, Tok_Select, Tok_Separate, Tok_Subtype,
       Tok_Tagged, Tok_Task, Tok_Terminate, Tok_Then, Tok_Type,
       Tok_Until, Tok_Use, Tok_When, Tok_While, Tok_With, Tok_Xor,

       Tok_Semi, Tok_Right_Paren, Tok_Becomes, Tok_Dot_Dot,
       Tok_Colon, Tok_Box, Tok_Start_Label, Tok_End_Label,
       Tok_Comma, Tok_Arrow,
       Tok_Plus, Tok_Minus, Tok_Asterisk, Tok_Slash,
       Tok_Less_Equal, Tok_Greater_Equal,
       Tok_Not_Equal, Tok_Equal, Tok_Greater, Tok_Less,
       Tok_Power, Tok_Ampersand,
       Tok_Left_Paren, Tok_Dot, Tok_Apostrophe,

       Tok_End_Of_File);


end GCS.Ada_Tokens;
