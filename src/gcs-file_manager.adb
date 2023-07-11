with Ada.Containers.Indefinite_Doubly_Linked_Lists;
with Ada.Exceptions;
with Ada.Strings.Unbounded;            use Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with GCS.Exceptions;

with Ada.Text_IO;
with Ada.Characters.Latin_1;           use Ada.Characters.Latin_1;

package body GCS.File_Manager is

   Tab_Size : constant := 8;

   package String_Lists is
     new Ada.Containers.Indefinite_Doubly_Linked_Lists (String);

   Include_Paths : String_Lists.List;
   File_Prefix   : Unbounded_String;

   procedure Add_Include_Path (Path : String) is
   begin
      Include_Paths.Append (Path);
   end Add_Include_Path;

   type Single_File_Info is
      record
         Name     : Unbounded_String;
      end record;

   All_File_Info : array (Source_File_Type range 1 .. Max_Open_Files)
     of Single_File_Info;
   Next_File : Source_File_Type := 1;

   subtype Line_String is String (1 .. Max_Line_Length);

   type Source_File_Info is
      record
         Name         : Unbounded_String;
         Line_No      : Line_Number;
         Curr_Line    : Line_String;
         Line_Ptr     : Column_Number;
         Indent       : Column_Number;
         Line_Length  : Column_Count;
         Stdin        : Boolean := False;
         From_String  : Boolean := False;
         File         : Ada.Text_IO.File_Type;
         End_Of_File  : Boolean;
         Index        : Source_File_Type;
         Hash         : File_Hash := 0;
      end record;

   Source_Files_Open : Natural := 0;
   Source_File_Stack : array (1 .. Max_Open_Files) of Source_File_Info;

   Tok_File   : Source_File_Type;
   Tok_Line   : Line_Number;
   Tok_Col    : Column_Count;
   Tok_Indent : Column_Count;

   procedure Open (Name        : String;
                   Stdin       : Boolean := False;
                   From_String : Boolean := False);

   --------------
   -- Add_Hash --
   --------------

   procedure Add_Hash (Text : String) is
      Hash : File_Hash renames Source_File_Stack (Source_Files_Open).Hash;
   begin
      for I in Text'Range loop
         Hash := Hash * 13 + Character'Pos (Text (I));
      end loop;
   end Add_Hash;

   ------------------
   -- Current_Hash --
   ------------------

   function Current_Hash return File_Hash is
   begin
      return Source_File_Stack (Source_Files_Open).Hash;
   end Current_Hash;

   -----------
   -- Close --
   -----------

   procedure Close is
   begin

      if Source_Files_Open = 0 then
         raise GCS.Exceptions.File_Close_Error;
      end if;

      if not Source_File_Stack (Source_Files_Open).Stdin and then
        not Source_File_Stack (Source_Files_Open).From_String
      then
         Ada.Text_IO.Close (Source_File_Stack (Source_Files_Open).File);
      end if;
      Source_Files_Open := Source_Files_Open - 1;
   end Close;

   -----------------------
   -- Current_Character --
   -----------------------

   function Current_Character return Character is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      if End_Of_File or else End_Of_Line then
         raise GCS.Exceptions.File_Manager_Error;
      else
         return Info.Curr_Line (Info.Line_Ptr);
      end if;
   end Current_Character;

   --------------------
   -- Current_Column --
   --------------------

   function Current_Column   return Column_Number is
   begin
      return Source_File_Stack (Source_Files_Open).Line_Ptr;
   end Current_Column;

   ------------------
   -- Current_File --
   ------------------

   function Current_File return Source_File_Type is
   begin
      return Source_File_Stack (Source_Files_Open).Index;
   end Current_File;

   -----------------------
   -- Current_File_Name --
   -----------------------
   function Current_File_Name return String is
   begin
      return To_String (Source_File_Stack (Source_Files_Open).Name);
   end Current_File_Name;

   ------------------------
   -- Current_File_Title --
   ------------------------
   function Current_File_Title return String is
      S           : constant String := Current_File_Name;
      First, Last : Natural;
   begin
      Last := S'Last;
      while Last > 0 and then S (Last) /= '.' loop
         Last := Last - 1;
      end loop;
      if Last > 0 then
         Last := Last - 1;
      end if;

      First := Last;
      while First > 0 and then
        S (First) /= '/' and then S (First) /= '\'
      loop
         First := First - 1;
      end loop;

      return S (First + 1 .. Last);
   end Current_File_Title;

   --------------------
   -- Current_Indent --
   --------------------

   function Current_Indent   return Column_Number is
   begin
      return Source_File_Stack (Source_Files_Open).Indent;
   end Current_Indent;

   ------------------
   -- Current_Line --
   ------------------

   function Current_Line return Line_Number is
   begin
      return Source_File_Stack (Source_Files_Open).Line_No;
   end Current_Line;

   -----------------------
   -- Current_Line_Text --
   -----------------------

   function Current_Line_Text return String is
      File_Info : Source_File_Info
        renames Source_File_Stack (Source_Files_Open);
   begin
      return File_Info.Curr_Line (1 .. File_Info.Line_Length);
   end Current_Line_Text;

   -----------------
   -- End_Of_File --
   -----------------

   function End_Of_File return Boolean is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      return Info.End_Of_File;
   end End_Of_File;

   ------------------
   --  End_Of_Line --
   ------------------

   function End_Of_Line return Boolean is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      if End_Of_File then
         raise GCS.Exceptions.File_Manager_Error;
      else
         return Info.Line_Ptr > Info.Line_Length;
      end if;
   end End_Of_Line;

   --------------------------
   -- Get_Current_Position --
   --------------------------

   procedure Get_Current_Position (File   : out Source_File_Type;
                                   Line   : out Line_Number;
                                   Col    : out Column_Count;
                                   Indent : out Column_Count)
   is
   begin
      File   := Tok_File;
      Line   := Tok_Line;
      Col    := Tok_Col;
      Indent := Tok_Indent;
   end Get_Current_Position;

   -------------------
   -- Get_File_Name --
   -------------------

   function Get_File_Name (F : Source_File_Type) return String is
   begin
      if F >= Next_File or else F = 0 then
         return "?" & Source_File_Type'Image (F) & "?";
      end if;
      return To_String (All_File_Info (F).Name);
   end Get_File_Name;

   ----------
   -- Open --
   ----------

   procedure Open (Name : String) is
   begin
      Open (Name, False);
   end Open;

   ----------
   -- Open --
   ----------

   procedure Open (Name        : String;
                   Stdin       : Boolean := False;
                   From_String : Boolean := False)
   is
      use Ada.Text_IO;
      First_File : Boolean;
   begin
      if Source_Files_Open = Max_Open_Files then
         raise GCS.Exceptions.Too_Many_Files;
      end if;

      if Source_Files_Open = 0
        and then not Stdin
        and then not From_String
      then
         --  This is the first file.  Use its prefix
         --  to find everything else.

         --  2000-12-14:fraser: but we've just been given a full
         --  path, we don't want to use the file prefix!  See below.
         First_File  := True;
         File_Prefix := Null_Unbounded_String;
         for I in reverse Name'Range loop
            if Name (I) = '/' or else Name (I) = '\' then
               File_Prefix := To_Unbounded_String (Name (Name'First .. I));
               exit;
            end if;
         end loop;

      else
         First_File := False;
      end if;

      if Source_Files_Open > 0 and then
        Source_File_Stack (Source_Files_Open).From_String
      then
         --  2009-06-09:fraser: reuse this source file.  Unlike
         --  normal source files, strings cannot be suspended and
         --  return to later
         null;
      else
         Source_Files_Open := Source_Files_Open + 1;
      end if;

      Source_File_Stack (Source_Files_Open).Stdin := False;
      Source_File_Stack (Source_Files_Open).From_String := False;

      begin
         --  2000-12-14:fraser: don't use file prefix if we have a
         --  full path. Actually, I'm not all that sure that the
         --  concept of a file prefix even belongs here, but hey.
         if (not Stdin and not From_String) and then
           (First_File or else
            Name (Name'First) = '/' or else
            (GNAT.OS_Lib.Directory_Separator = '\' and then
             Name (Name'First + 1) = ':'))
         then
            Open (Source_File_Stack (Source_Files_Open).File, In_File, Name);
         elsif not Stdin and not From_String then
            --  2006-05-06: Try to open the file using the prefix.  If that
            --  fails, try just opening the file.
            begin
               Open (Source_File_Stack (Source_Files_Open).File, In_File,
                     To_String (File_Prefix) & Name);
            exception
               when Ada.Text_IO.Name_Error =>
                  Open (Source_File_Stack (Source_Files_Open).File, In_File,
                        Name);
            end;
         elsif Stdin then
            Source_File_Stack (Source_Files_Open).Stdin := True;
         elsif From_String then
            Source_File_Stack (Source_Files_Open).From_String := True;
         end if;

         Source_File_Stack (Source_Files_Open).End_Of_File := False;

      exception
         when others =>
            --  restore state, then tell the caller
            Source_Files_Open := Source_Files_Open - 1;

            Ada.Exceptions.Raise_Exception
              (GCS.Exceptions.File_Open_Fail'Identity,
               Name);
      end;

      --  Store information in the file history
      if not From_String and not Stdin then
         All_File_Info (Next_File) :=
           (Name => To_Unbounded_String (Name));
      else
         All_File_Info (Next_File) :=
           (Name => To_Unbounded_String ("user input"));
      end if;
      Next_File := Next_File + 1;

      Init_Source_File :
      declare
         Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
      begin
         Info.Name             := All_File_Info (Next_File - 1).Name;
         Info.Line_No          := 0;

         if From_String then
            Info.Curr_Line (1 .. Name'Length) := Name;
            Info.Line_Ptr := 1;
            Info.Indent := 1;
            Info.Line_Length := Name'Length;
         else
            Info.Curr_Line        := (others => ' ');
            Info.Line_Ptr         := 1;
            Info.Indent           := 1;
            Info.Line_Length      := 0;
         end if;
         Info.End_Of_File      := False;
         Info.Index            := Next_File - 1;
      end Init_Source_File;

      Set_Current_Position
        (File   => Next_File - 1,
         Line   => 1,
         Col    => 1,
         Indent => 1);

   end Open;

   -------------------------
   -- Open_Standard_Input --
   -------------------------

   procedure Open_Standard_Input is
   begin
      Open ("", True);
   end Open_Standard_Input;

   -----------------
   -- Open_String --
   -----------------

   procedure Open_String (Text : String) is
   begin
      Open (Text, From_String => True);
   end Open_String;

   ----------
   -- Skip --
   ----------

   procedure Skip is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      if End_Of_File then
         raise GCS.Exceptions.File_Manager_Error;
      elsif End_Of_Line then
         Next_Line;
      else
         if Info.Curr_Line (Info.Line_Ptr) = HT then
            Info.Indent :=
              Info.Indent + Tab_Size - (Info.Indent - 1) mod Tab_Size;
         else
            Info.Indent := Info.Indent + 1;
         end if;
         Info.Line_Ptr := Info.Line_Ptr + 1;
      end if;
   end Skip;

   -----------------
   -- Skip_Spaces --
   -----------------

   procedure Skip_Spaces is
   begin
      if End_Of_File then
         return;
      end if;

      while not End_Of_File and then
        (End_Of_Line or else Current_Character = ' '
        or else Current_Character = HT or else Current_Character = FF)
      loop
         Skip;
      end loop;
   end Skip_Spaces;

   ---------------
   -- Next_Line --
   ---------------

   procedure Next_Line is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin

      if Info.From_String then
         Info.End_Of_File := True;
         return;
      end if;

      if Info.End_Of_File then
         return;
      end if;

      if not Info.Stdin then
         if Ada.Text_IO.End_Of_File (Info.File) then
            Info.End_Of_File := True;
            return;
         end if;
      else
         if Ada.Text_IO.End_Of_File then
            Info.End_Of_File := True;
            return;
         end if;
      end if;

      Info.Line_No := Info.Line_No + 1;
      if not Info.Stdin then
         Ada.Text_IO.Get_Line (Info.File, Info.Curr_Line, Info.Line_Length);
      else
         if Info.Line_No = 1 then
            Ada.Text_IO.Put ("> ");
         else
            Ada.Text_IO.Put (">>> ");
         end if;
         Ada.Text_IO.Get_Line (Info.Curr_Line, Info.Line_Length);
      end if;

      --  ignore DOS line terminators, if present
      if Info.Line_Length > 0
        and then Info.Curr_Line (Info.Line_Length) = Character'Val (13)
      then
         Info.Line_Length := Info.Line_Length - 1;
      end if;

      Info.Line_Ptr := 1;
      Info.Indent   := 1;
   end Next_Line;

   -----------
   -- Match --
   -----------

   function Match (Text       : String;
                   Skip_Match : Boolean := False) return Boolean
   is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      if End_Of_File or else End_Of_Line or else Text = "" then
         return False;
      end if;

      if Info.Line_Ptr + Text'Length - 1 > Info.Line_Length then
         return False;
      end if;

      if Info.Curr_Line (Info.Line_Ptr .. Info.Line_Ptr + Text'Length - 1)
        = Text
      then
         if Skip_Match then
            Info.Line_Ptr := Info.Line_Ptr + Text'Length;
         end if;
         return True;
      else
         return False;
      end if;
   end Match;

   --------------------------
   -- Set_Current_Position --
   --------------------------

   procedure Set_Current_Position (File   : Source_File_Type;
                                   Line   : Line_Number;
                                   Col    : Column_Number;
                                   Indent : Column_Number)
   is
   begin
      Tok_File   := File;
      Tok_Line   := Line;
      Tok_Col    := Col;
      Tok_Indent := Indent;
   end Set_Current_Position;

   ------------
   -- Unskip --
   ------------

   procedure Unskip is
      Info : Source_File_Info renames Source_File_Stack (Source_Files_Open);
   begin
      if Info.Line_Ptr = 1 then
         raise GCS.Exceptions.File_Manager_Error;
      else
         Info.Line_Ptr := Info.Line_Ptr - 1;
      end if;
   end Unskip;

end GCS.File_Manager;
