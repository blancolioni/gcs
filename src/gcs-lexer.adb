with Ada.Text_IO;
with Ada.Characters.Latin_1;
with Ada.Characters.Handling;
with Ada.Strings.Unbounded;

with GCS.Exceptions;
with GCS.File_Manager;
with GCS.Errors;

package body GCS.Lexer is

   use GCS.Constraints, GCS.Positions;

   Debug_Lexer : Boolean := False;

   --  we keep track of the last line, so that we can set
   --  Tok_End_Of_File properly
   Last_Line : Line_Number;

   --  the absolute maximum length of a string, whether or not
   --  Multi_Line_Strings is defined
   Max_String_Length : constant := 8192;

   --  We can set a callback for new (non-blank) lines
   New_Line_Handler : Trap_Handler;

   procedure Set_New_Line_Trap (Handler : Trap_Handler) is
   begin
      New_Line_Handler := Handler;
   end Set_New_Line_Trap;

   Keyword_List : Keyword_Table.Map;

   --  Identifier information
   type Character_Set is array (Character) of Boolean;
   for Character_Set'Component_Size use 1;

   First_Id    : Character_Set;
   Body_Id     : Character_Set;
   Group_Id    : Character_Set;
   Body_Number : Character_Set;
   Symbol_Char : Character_Set;

   function Default_Escape (Item : Character) return Character;

   function Get_Keyword (Text : String) return Token;

   procedure Initialise_Character_Set (Set    : in out Character_Set;
                                       Chars  : String);

   procedure Initialise_Keyword_List (Keywords     : String;
                                      First        : Token);

   procedure Initialise_Symbol_List (Symbols     : String;
                                     First       : Token);

   procedure Issue_Error (Level    : GCS.Errors.Error_Level;
                          Location : File_Position;
                          Message  : String);

   procedure Skip_To (Skip_Up_To : Token_Set);

   ---------
   -- "+" --
   ---------

   function "+" (Left, Right : Token_Set) return Token_Set is
      Toks : Token_Set (1 .. Right'Length);
      Count : Natural := 0;
   begin
      for Tok of Right loop
         if not (Tok <= Left) then
            Count := Count + 1;
            Toks (Count) := Tok;
         end if;
      end loop;
      return Left & Toks (1 .. Count);
   end "+";

   ------------------------------
   -- Initialise_Character_Set --
   ------------------------------

   procedure Initialise_Character_Set (Set    : in out Character_Set;
                                       Chars  : String)
   is
   begin
      Set := (others => False);
      for I in Chars'Range loop
         Set (Chars (I)) := True;
      end loop;
   end Initialise_Character_Set;

   -----------------------------------------------------------------

   -----------
   -- Debug --
   -----------

   procedure Debug (Enabled : Boolean) is
   begin
      Debug_Lexer := Enabled;
   end Debug;

   --------------------
   -- Default_Escape --
   --------------------

   function Default_Escape (Item : Character) return Character is
   begin
      case Item is
         when 'a' =>
            return ASCII.BEL;
         when 'b' =>
            return ASCII.BS;
         when 'f' =>
            return ASCII.FF;
         when 'n' =>
            return ASCII.LF;
         when 'r' =>
            return ASCII.CR;
         when 't' =>
            return ASCII.HT;
         when others =>
            return Item;
      end case;
   end Default_Escape;

   Token_Count : Natural := 0;

   ----------------
   -- Token_Info --
   ----------------

   type Token_Info is
      record
         Tok      : Token;
         Length   : Natural;
         Start    : Column_Count;
         Finish   : Column_Count;
         Indent   : Column_Count;
         Line_No  : Line_Number;
         Text     : String (1 .. Max_Identifier_Length);
         Raw_Text : String (1 .. Max_Identifier_Length);
         S_Text   : Ada.Strings.Unbounded.Unbounded_String;
         Char     : Character;             --  for Tok_Character
      end record;

   type Token_Info_List is array (Lookahead) of Token_Info;

   procedure Get_Symbol (Tok_Info : in out Token_Info);

   ----------------------
   -- Source_File_Info --
   ----------------------

   type Source_File_Info is
      record
         Curr_Token     : Lookahead;
         Prev_Token     : Token;
         Tokens         : Token_Info_List;
      end record;

   Source_File_Stack : array (1 .. Max_Open_Files) of Source_File_Info;

   Source_Files_Open : Natural := 0;

   procedure Open_Lexer;

   ----------
   -- Open --
   ----------

   procedure Open (Name : String) is
   begin
      GCS.File_Manager.Open (Name);

      Open_Lexer;
   end Open;

   -------------------------
   -- Open_Standard_Input --
   -------------------------

   procedure Open_Standard_Input is
   begin
      GCS.File_Manager.Open_Standard_Input;
      Open_Lexer;
   end Open_Standard_Input;

   -----------------
   -- Open_String --
   -----------------

   procedure Open_String (Text : String) is
   begin
      GCS.File_Manager.Open_String (Text);
      Open_Lexer;
   end Open_String;

   ----------------
   -- Open_Lexer --
   ----------------

   procedure Open_Lexer is
   begin

      Source_Files_Open := Source_Files_Open + 1;

      Init_Token_Info :
      declare
         use Ada.Strings.Unbounded;
         Info : Source_File_Info
           renames Source_File_Stack (Source_Files_Open);
      begin
         Last_Line := 0;
         Info := (Tokens     =>
                    (others => (Tok      => Tok_None,
                                Length   => 0,
                                Start    => 1,
                                Finish   => 1,
                                Indent   => 1,
                                Line_No  => 0,
                                S_Text   => To_Unbounded_String (""),
                                Text     => (others => ' '),
                                Raw_Text => (others => ' '),
                                Char     => ' ')),
                  Curr_Token => 0,
                  Prev_Token => Tok_None);

         for I in Lookahead loop
            Scan;
         end loop;

         Info.Curr_Token := 0;

      end Init_Token_Info;
   end Open_Lexer;

   -----------
   -- Close --
   -----------

   procedure Close is
   begin
      GCS.File_Manager.Close;
      Source_Files_Open := Source_Files_Open - 1;
   end Close;

   ------------------
   -- Current_Hash --
   ------------------

   function Current_Hash return File_Hash is
   begin
      return GCS.File_Manager.Current_Hash;
   end Current_Hash;

   ---------
   -- Tok --
   ---------

   function Tok return Token is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Tokens (Info.Curr_Token).Tok;
   end Tok;

   --------------
   -- Tok_Text --
   --------------
   function Tok_Text return String is
   begin
      return Tok_Text (0);
   end Tok_Text;

   --------------
   -- Tok_Text --
   --------------

   function Tok_Text (Ahead : Lookahead) return String is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
      Tok_Info : Token_Info renames Info.Tokens (Info.Curr_Token +
                                                 Ahead);
   begin
      if Tok = Tok_String or else
        (Properties (GCS.Styles.Multi_Characters) and then Tok = Tok_Character)
      then
         return Ada.Strings.Unbounded.To_String (Tok_Info.S_Text);
--       elsif Tok = Tok_Identifier then
--          return Tok_Info.Raw_Text (1 .. Tok_Info.Length);
      elsif Tok = Tok_Character then
         return "'" & Tok_Info.Char & "'";
      else
         return Tok_Info.Text (1 .. Tok_Info.Length);
      end if;
   end Tok_Text;

   ------------------
   -- Tok_Raw_Text --
   ------------------

   function Tok_Raw_Text return String is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
      Tok_Info : Token_Info renames Info.Tokens (Info.Curr_Token);
   begin
      if Tok = Tok_Identifier then
         return Tok_Info.Raw_Text (1 .. Tok_Info.Length);
      else
         return Tok_Text;
      end if;
   end Tok_Raw_Text;

   -------------------------
   -- Tok_Character_Value --
   -------------------------

   function Tok_Character_Value return Character is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
      Tok_Info : Token_Info renames Info.Tokens (Info.Curr_Token);
   begin
      if Tok = Tok_Character then
         return Tok_Info.Char;
      else
         Internal_Error ("tried to get a character from " &
                         "a non-character token");
         return Character'Val (0);
      end if;
   end Tok_Character_Value;

   --------------
   -- Prev_Tok --
   --------------

   function Prev_Tok return Token is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Prev_Token;
   end Prev_Tok;

   --------------
   -- Next_Tok --
   --------------

   function Next_Tok (Ahead : Lookahead := 1) return Token is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Tokens (Info.Curr_Token + Ahead).Tok;
   end Next_Tok;

   --------------
   -- Tok_File --
   --------------

   function Tok_File return Source_File_Type is
   begin
      return GCS.File_Manager.Current_File;
   end Tok_File;

   -------------------
   -- Tok_File_Name --
   -------------------

   function Tok_File_Name return String is
   begin
      return GCS.File_Manager.Current_File_Name;
   end Tok_File_Name;

   --------------
   -- Tok_Line --
   --------------

   function Tok_Line return Line_Number is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Tokens (Info.Curr_Token).Line_No;
   end Tok_Line;

   ----------------
   -- Tok_Column --
   ----------------

   function Tok_Column return Column_Count is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Tokens (Info.Curr_Token).Start;
   end Tok_Column;

   ----------------
   -- Tok_Indent --
   ----------------

   function Tok_Indent return Column_Count is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.Tokens (Info.Curr_Token).Indent;
   end Tok_Indent;

   ------------------
   -- Current_Line --
   ------------------
   function Current_Line return String is
   begin
      return GCS.File_Manager.Current_Line_Text;
   end Current_Line;

   -----------------
   -- Get_Keyword --
   -----------------

   function Get_Keyword (Text : String) return Token is
   begin
      if Text'Length < Keyword_Strings.Max_Length then
         declare
            Key : constant Keyword_Strings.Bounded_String :=
                    Keyword_Strings.To_Bounded_String (Text);
         begin
            if Keyword_List.Contains (Key) then
               return Keyword_List.Element (Key);
            else
               return Tok_Identifier;
            end if;
         end;
      else
         return Tok_Identifier;
      end if;
   end Get_Keyword;

   ----------------
   -- Get_Symbol --
   ----------------

   procedure Get_Symbol (Tok_Info : in out Token_Info) is
      use Tokeniser;
      use GCS.File_Manager;
      State   : Positive := 1;
      Command : State_Command;
      Ch      : Character;
   begin
      Tok_Info.Length := 0;
      loop
         if End_Of_Line or else not Symbol_Char (Current_Character) then
            Ch := ' ';
         else
            Ch := Current_Character;
         end if;

         Command := Get_Command (Ch, State);

         case Command is
            when No_Command =>
               raise GCS.Exceptions.Bad_State_Machine;

            when Accept_And_Skip =>
               Tok_Info.Length := Tok_Info.Length + 1;
               Tok_Info.Text (Tok_Info.Length) := Ch;
               Tok_Info.Tok := Token'Val (Get_Result (Ch, State));
               Skip;
               return;

            when Accept_And_Leave =>
               Tok_Info.Tok := Token'Val (Get_Result (Ch, State));
               return;

            when Skip_And_Change =>
               Tok_Info.Length := Tok_Info.Length + 1;
               Tok_Info.Text (Tok_Info.Length) := Ch;
               State := Get_Result (Ch, State);
               Skip;
         end case;
      end loop;

   exception
      when GCS.Exceptions.Bad_State_Machine =>
         Tok_Info.Tok := Tok_Bad_Character;
         Skip;

   end Get_Symbol;

   ----------
   -- Scan --
   ----------

   procedure Scan is
      use GCS.File_Manager;
      use GCS.Styles;
      Info     : Source_File_Info
        renames Source_File_Stack (Source_Files_Open);
      Dest     : constant Lookahead := Info.Curr_Token;
      Tok_Info : Token_Info renames Info.Tokens (Dest);
   begin

      Info.Prev_Token := Tok_Info.Tok;
      Last_Line := Current_Line;

      Skip_Comments_And_Spaces :
      loop
         GCS.File_Manager.Skip_Spaces;
         if GCS.File_Manager.End_Of_File then
            Tok_Info.Tok     := Tok_End_Of_File;
            Tok_Info.Start   := 0;
            Tok_Info.Indent  := 0;
            Tok_Info.Line_No := Last_Line + 1;
            Tok_Info.Length  := 0;
            Info.Curr_Token := Info.Curr_Token + 1;
            return;
         end if;

         if GCS.File_Manager.Match (Line_Comment_Start) then
            GCS.File_Manager.Next_Line;
         elsif Block_Comment_Start /= "" and then
          GCS.File_Manager.Match (Block_Comment_Start)
         then
            for I in Block_Comment_Start'Range loop
               GCS.File_Manager.Skip;
            end loop;

            while not GCS.File_Manager.End_Of_File and then
              not GCS.File_Manager.Match (Block_Comment_End,
                                          Skip_Match => True)
           loop
               GCS.File_Manager.Skip;
               GCS.File_Manager.Skip_Spaces;
            end loop;
         else
            exit Skip_Comments_And_Spaces;
         end if;
      end loop Skip_Comments_And_Spaces;

      if New_Line_Handler /= null and then
       Last_Line /= Current_Line
      then
         New_Line_Handler (Current_Line, GCS.File_Manager.Current_Line_Text);
      end if;

      Tok_Info.Start   := Current_Column;
      Tok_Info.Indent  := Current_Indent;
      Tok_Info.Line_No := Current_Line;
      Tok_Info.Length  := 0;

      if First_Id (Current_Character) then

         declare
            Group_Character : constant Boolean :=
             Group_Id (Current_Character);
         begin
            loop

               Tok_Info.Length := Tok_Info.Length + 1;
               Tok_Info.Raw_Text (Tok_Info.Length) := Current_Character;
               if Properties (Case_Sensitive_Identifiers) then
                  Tok_Info.Text (Tok_Info.Length) := Current_Character;
               else
                  Tok_Info.Text (Tok_Info.Length) :=
                   Ada.Characters.Handling.To_Lower (Current_Character);
               end if;
               Skip;

               exit when End_Of_Line or else not Body_Id (Current_Character);

               if Group_Character then
                  exit when not Group_Id (Current_Character);
               else
                  exit when Group_Id (Current_Character);
               end if;

            end loop;
         end;

         Tok_Info.Tok  := Get_Keyword (Tok_Info.Text (1 .. Tok_Info.Length));

      elsif Current_Character in '0' .. '9' then

         --  Floating point or integer
         Tok_Info.Tok := Tok_Integer;
         while not End_Of_Line and then Body_Number (Current_Character) loop
            Tok_Info.Length := Tok_Info.Length + 1;
            Tok_Info.Text (Tok_Info.Length) := Current_Character;
            if Current_Character = '.' then
               Tok_Info.Tok := Tok_Float;
            end if;
            Skip;
            if not End_Of_Line and then
             (Current_Character = 'E' or else Current_Character = 'e')
            then
               Tok_Info.Tok := Tok_Float;
               Tok_Info.Length := Tok_Info.Length + 1;
               Tok_Info.Text (Tok_Info.Length) := 'E';
               Skip;
               if not End_Of_Line and then
                (Current_Character = '+' or else Current_Character = '-')
               then
                  Tok_Info.Length := Tok_Info.Length + 1;
                  Tok_Info.Text (Tok_Info.Length) := Current_Character;
                  Skip;
               end if;
            end if;
         end loop;

      elsif Current_Character = Ada.Characters.Latin_1.Apostrophe and then
       Tok_Character /= Tok_None and then
       not Properties (Multi_Characters)
      then
         Skip;
         Tok_Info.Tok := Tok_Character;
         if not End_Of_Line then
            if Current_Character = Escape_Character then
               Skip;
               if End_Of_Line then
                  Error ("bad character constant");
               else
                  Tok_Info.Char := Default_Escape (Current_Character);
                  Skip;
               end if;
            else
               Tok_Info.Char := Current_Character;
               Skip;
            end if;
            if Current_Character = Ada.Characters.Latin_1.Apostrophe then
               Skip;
            elsif Properties (GCS.Styles.Single_Quote_Token) then
               Unskip;
               Unskip;
               Get_Symbol (Tok_Info);
            else
               Error ("bad character constant");
            end if;
         else
            Error ("bad character constant");
         end if;

         if Tok_Info.Tok = Tok_Character then
            Tok_Info.Length := 1;
            Tok_Info.Text (1) := Tok_Info.Char;
         end if;

      elsif Current_Character = Ada.Characters.Latin_1.Quotation or else
       (Properties (Multi_Characters)  and then
        Current_Character = Ada.Characters.Latin_1.Apostrophe)
      then
         Read_String :
         declare
            use Ada.Strings.Unbounded;
            Item      : Unbounded_String;
            Delimiter : constant Character := Current_Character;
            Is_String : constant Boolean :=
             Delimiter = Ada.Characters.Latin_1.Quotation;
            Got_Delimiter : Boolean := False;
            Escaped       : Boolean := False;
         begin
            Tok_Info.Tok := Tok_String;
            Skip;
            loop
               exit when Properties (GCS.Styles.Multi_Line_Strings) and then
                End_Of_File;
               exit when not Properties (GCS.Styles.Multi_Line_Strings)
                and then End_Of_Line;

               if Current_Character = Delimiter and then not Escaped then
                  Skip;
                  if End_Of_File or else
                   End_Of_Line or else
                   Current_Character /= Delimiter or else
                   not Properties (Two_Quote_Escape)
                  then
                     Got_Delimiter := True;
                     exit;
                  end if;
               end if;

               if Current_Character = Escape_Character then
                  Escaped := True;
                  if Hooks (Character_Hook) = null then
                     Skip;
                  end if;
               else
                  Escaped := False;
               end if;

               Tok_Info.Length := Tok_Info.Length + 1;
               if Escaped and then Hooks (Character_Hook) = null then
                  if End_Of_Line then
                     Item := Item & Character'Val (10);
                     Next_Line;
                  elsif End_Of_File then
                     Error ("bad string");
                  else
                     Item := Item & Default_Escape (Current_Character);
                     Skip;
                  end if;
               else
                  Item := Item & Current_Character;
                  Skip;
               end if;

               Escaped := False;

               if Properties (GCS.Styles.Multi_Line_Strings) and then
                End_Of_Line
               then
                  while End_Of_Line and then not End_Of_File loop
                     Next_Line;
                  end loop;
                 --  insert a space if a line boundary is crossed,
                 --  and we don't have one available
                  if Current_Character /= ' ' then
                     Tok_Info.Length := Tok_Info.Length + 1;
                     Item := Item & ' ';
                  end if;
               end if;
            end loop;

            if Is_String or else Hooks (Character_Hook) = null then
               Tok_Info.S_Text := Item;
            else
               Tok_Info.S_Text :=
                Ada.Strings.Unbounded.To_Unbounded_String
                (Hooks (Character_Hook)
                 (Ada.Strings.Unbounded.To_String (Item)));
            end if;

            if Is_String then
               Tok_Info.Tok := Tok_String;
            else
               Tok_Info.Tok := Tok_Character;
            end if;

            if not Got_Delimiter then
               Error ("unterminated string constant");
            elsif Tok_Info.Length = Max_String_Length and then
             Current_Character /= Ada.Characters.Latin_1.Quotation
            then
               Error ("string too long");
            end if;
         end Read_String;

      else
         Get_Symbol (Tok_Info);
      end if;

      Info.Curr_Token := Info.Curr_Token + 1;
      Token_Count := Token_Count + 1;

      if Token_Count > Max_Lookahead then
         Set_Current_Position (Tok_File, Tok_Line, Tok_Column, Tok_Indent);
      end if;

      if Debug_Lexer then
         Ada.Text_IO.Put_Line (Token'Image (Tok) & ' ' & Tok_Text);
      end if;

      Add_Hash (Tok_Text);

   end Scan;

   -------------
   -- Warning --
   -------------
   procedure Warning (Message : String) is
   begin
      GCS.Errors.Warning (Tok_File_Name, Tok_Line, Tok_Column,
                          Message);
   end Warning;

   -----------
   -- Error --
   -----------
   procedure Error (Message : String) is
   begin
      GCS.Errors.Error (Tok_File_Name, Tok_Line, Tok_Column,
                        Message);
   exception
      when Constraint_Error =>
         Ada.Text_IO.Put_Line ("Unable to issue this error: " &
                               Message);

   end Error;

   -----------------
   -- Fatal_Error --
   -----------------
   procedure Fatal_Error (Message : String) is
   begin
      GCS.Errors.Fatal_Error (Tok_File_Name, Tok_Line, Tok_Column,
                              Message);
   end Fatal_Error;

   --------------------
   -- Internal_Error --
   --------------------
   procedure Internal_Error (Message : String) is
   begin
      GCS.Errors.Internal_Error (Tok_File_Name,
                                 Tok_Line, Tok_Column,
                                 Message);
   end Internal_Error;

   -----------------------------
   -- Initialise_Keyword_List --
   -----------------------------

   procedure Initialise_Keyword_List (Keywords     : String;
                                      First        : Token)
   is
      Index, Start    : Positive;
      Current_Keyword : Token;
   begin
      Index := 1;
      Start := 1;
      Current_Keyword := First;
      for I in Keywords'Range loop
         if Keywords (I) = ' ' then
            declare
               Keyword : constant Keyword_Strings.Bounded_String :=
                           Keyword_Strings.To_Bounded_String
                             (Keywords (Start .. I - 1));
            begin
               Keyword_List.Insert (Keyword, Current_Keyword);
            end;

            --  Guard against the last token being used for
            --  a keyword.
            if Current_Keyword /= Token'Last then
               Current_Keyword := Token'Succ (Current_Keyword);
            end if;

            Index := Index + 1;
            Start := I + 1;
         end if;
      end loop;

   end Initialise_Keyword_List;

   ----------------------------
   -- Initialise_Symbol_List --
   ----------------------------

   procedure Initialise_Symbol_List (Symbols     : String;
                                     First       : Token) is

      use Tokeniser;
      Index      : Positive := Symbols'First;
      Last       : Positive := Index;
      Sym        : Token := First;
      State      : Positive;
      Next_State : Positive;
   begin
      Initialise_Character_Set (Symbol_Char, Symbols);
      Symbol_Char (' ') := False;

      Set_Symbol_Characters (Symbols);
      State := New_State;

      while Last <= Symbols'Last loop
         while Last /= Symbols'Last and then
           Symbols (Last) /= ' '
         loop
            Last := Last + 1;
         end loop;
         if Last <= Symbols'Last
           and then Symbols (Last) = ' '
         then
            Last := Last - 1;
         end if;
         State := 1;

         for I in Index .. Last loop
            case Get_Command (Symbols (I), State) is
               when No_Command | Accept_And_Leave =>
                  if I = Last then
                     Set_Command (Symbols (I), State, Accept_And_Skip,
                                  Token'Pos (Sym));
                  else
                     Next_State := New_State;
                     Set_Command (Symbols (I), State, Skip_And_Change,
                                  Next_State);
                     State := Next_State;
                  end if;
               when Accept_And_Skip =>
                  if I = Last then
                     Ada.Text_IO.Put_Line ("Repeated symbol: " &
                                           Symbols (Index .. Last));
                     raise GCS.Exceptions.Repeated_Symbol;
                  else
                     Next_State := New_State;
                     Fill_State (Next_State, Accept_And_Leave,
                                 Get_Result (Symbols (I), State));
                     Set_Command (Symbols (I), State, Skip_And_Change,
                                  Next_State);
                     State := Next_State;
                  end if;
               when Skip_And_Change =>
                  if I = Last then
                     Next_State := Get_Result (Symbols (I), State);
                     Fill_State (Next_State, No_Command,
                                 Accept_And_Leave, Token'Pos (Sym));
                  else
                     State := Get_Result (Symbols (I), State);
                  end if;
            end case;
         end loop;

         Last := Last + 1;
         while Last <= Symbols'Last and then Symbols (Last) = ' ' loop
            Last := Last + 1;
         end loop;

         if Last <= Symbols'Last
           and then Symbols (Last) /= ' '
         then
            Index := Last;
            Sym := Token'Succ (Sym);
         end if;

      end loop;

      if Debug_Lexer then
         Dump_State_Table;
      end if;

   end Initialise_Symbol_List;

   ------------
   -- Expect --
   ------------

   procedure Expect (T          : Token;
                     Skip_Up_To : Token_Set) is
   begin
      if T = Tok then
         Scan;
      else
         Error ("missing " & Token'Image (T));
         Skip_To (Skip_Up_To + T);
         if Tok = T then
            Scan;
         end if;
      end if;
   end Expect;

   ------------
   -- Expect --
   ------------

   procedure Expect (T          : Token;
                     Skip_Up_To : Token)
   is
   begin
      Expect (T, (1 => Skip_Up_To));
   end Expect;

   -------------
   -- Skip_To --
   -------------

   procedure Skip_To (Skip_Up_To : Token_Set) is
   begin
      while Tok /= Tok_End_Of_File and then not (Tok <= Skip_Up_To) loop
         Scan;
      end loop;
   end Skip_To;

   -------------
   -- Skip_To --
   -------------

   procedure Skip_To (Skip_Up_To : Token) is
   begin
      Skip_To (+Skip_Up_To);
   end Skip_To;

   procedure Skip_To (Tok_1, Tok_2 : Token) is
   begin
      Skip_To ((Tok_1, Tok_2));
   end Skip_To;

   procedure Skip_To (Tok_1, Tok_2, Tok_3 : Token) is
   begin
      Skip_To ((Tok_1, Tok_2, Tok_3));
   end Skip_To;

   procedure Skip_To (Tok_1, Tok_2, Tok_3, Tok_4 : Token) is
   begin
      Skip_To ((Tok_1, Tok_2, Tok_3, Tok_4));
   end Skip_To;

   procedure Skip_To (Skip_To_And_Parse : Token_Set;
                      Skip_To_And_Stop  : Token_Set)
   is
   begin
      Skip_To (Skip_To_And_Parse + Skip_To_And_Stop);
      if Tok <= Skip_To_And_Stop then
         Scan;
      end if;
   end Skip_To;

   function Get_Current_Position return GCS.Positions.File_Position is
   begin
      return GCS.Positions.Get_Current_Position;
   end Get_Current_Position;

   procedure Issue_Error (Level    : GCS.Errors.Error_Level;
                          Location : File_Position;
                          Message  : String)
   is
   begin
      GCS.Errors.Error (Level,
                        GCS.File_Manager.Get_File_Name
                        (Get_File (Location)),
                        Get_Line (Location),
                        Get_Column (Location),
                        Message);
   end Issue_Error;

   procedure Warning        (Location   : File_Position;
                             Message    : String)
   is
   begin
      Issue_Error (GCS.Errors.Warning, Location, Message);
   end Warning;

   procedure Error          (Location   : File_Position;
                             Message    : String)
   is
   begin
      Issue_Error (GCS.Errors.Error, Location, Message);
   end Error;

   procedure Fatal_Error    (Location   : File_Position;
                             Message    : String)
   is
   begin
      Issue_Error (GCS.Errors.Fatal, Location, Message);
   end Fatal_Error;

   procedure Internal_Error (Location   : File_Position;
                             Message    : String)
   is
   begin
      Issue_Error (GCS.Errors.Internal, Location, Message);
   end Internal_Error;

begin

   Initialise_Keyword_List (Keywords & ' ', First_Keyword);
   Initialise_Symbol_List (Symbols & ' ',  First_Symbol);

   Initialise_Character_Set (First_Id, Identifier_Start);
   Initialise_Character_Set (Body_Id,  Identifier_Body);
   Initialise_Character_Set (Body_Number, "0123456789._");
   if Properties (GCS.Styles.Ada_Number_Bases) then
      Body_Number ('#') := True;
      for Ch in Character range 'A' .. 'F' loop
         Body_Number (Ch) := True;
      end loop;
      for Ch in Character range 'a' .. 'f' loop
         Body_Number (Ch) := True;
      end loop;
   end if;
   Initialise_Character_Set (Group_Id, Identifier_Group);

end GCS.Lexer;
