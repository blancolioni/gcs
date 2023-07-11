with Ada.Directories;

with GCS.File_Manager;

package body GCS.Positions is

   ---------
   -- "<" --
   ---------

   function "<" (Left, Right : File_Position) return Boolean is
   begin
      if Left.File = Right.File then
         if Left.Line = Right.Line then
            if Left.Col = Right.Col then
               return False;
            else
               return Left.Col < Right.Col;
            end if;
         else
            return Left.Line < Right.Line;
         end if;
      else
         return Left.File < Right.File;
      end if;
   end "<";

   ----------------
   -- Get_Column --
   ----------------

   function Get_Column (From : File_Position) return Column_Count is
   begin
      return From.Col;
   end Get_Column;

   --------------------------
   -- Get_Current_Position --
   --------------------------

   function  Get_Current_Position return File_Position is
      Result : File_Position;
   begin
      GCS.File_Manager.Get_Current_Position (Result.File, Result.Line,
                                             Result.Col, Result.Indent);
      return Result;
   end Get_Current_Position;

   --------------
   -- Get_File --
   --------------

   function Get_File   (From : File_Position) return Source_File_Type is
   begin
      return From.File;
   end Get_File;

   ----------------
   -- Get_Indent --
   ----------------

   function Get_Indent (From : File_Position) return Column_Number is
   begin
      return From.Indent;
   end Get_Indent;

   --------------
   -- Get_Line --
   --------------

   function Get_Line   (From : File_Position) return Line_Number is
   begin
      return From.Line;
   end Get_Line;

   -----------
   -- Image --
   -----------

   function Image (Item : File_Position) return String is
      Line_Image : constant String := Line_Number'Image (Get_Line (Item));
      Col_Image  : constant String :=
        Column_Number'Image (Get_Column (Item));
   begin
      return Ada.Directories.Simple_Name
        (File_Manager.Get_File_Name (Get_File (Item)))
        & ':' & Line_Image (Line_Image'First + 1 .. Line_Image'Last) &
        ':' & Col_Image (Col_Image'First + 1 .. Col_Image'Last);
   end Image;

   -------------------
   -- Null_Position --
   -------------------

   function Null_Position return File_Position is
   begin
      return (0, 0, 1, 1);
   end Null_Position;

end GCS.Positions;
