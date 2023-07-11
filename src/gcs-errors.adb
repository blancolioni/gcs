with Ada.Directories;
with Ada.Strings.Unbounded;            use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GCS.File_Manager;

package body GCS.Errors is

   Contact_Email : constant String := "help@@whitelion.com";

   Current_File    : Source_File_Type;
   Current_Line    : Line_Number;
   Current_Column  : Column_Number;

   function "+" (Left : String) return Unbounded_String
                 renames To_Unbounded_String;

   Prefix : constant array (Error_Level) of Unbounded_String :=
     (+"warning: ", +"", +"fatal error: ", +"internal error: ");
   Got_Error : array (Error_Level) of Boolean := (others => False);
   Is_Error  : constant array (Error_Level) of Boolean :=
     (Warning   => False,
      others    => True);
   Is_Fatal  : constant array (Error_Level) of Boolean :=
     (Fatal     => True,
      Internal  => True,
      others    => False);

   procedure Put_Error (Message : String);

   ------------------
   -- Clear_Errors --
   ------------------

   procedure Clear_Errors is
   begin
      Got_Error := (others => False);
   end Clear_Errors;

   -----------
   -- Error --
   -----------

   procedure Error (File_Name   : String;
                    Line        : Line_Number;
                    Column      : Column_Count;
                    Message     : String)
   is
      Line_Img : constant String := Line_Number'Image (Line);
      Col_Img  : constant String := Column_Number'Image (Column);
   begin
      Got_Error (Error) := True;

      Put_Error (Ada.Directories.Simple_Name (File_Name) & ':' &
                 Line_Img (2 .. Line_Img'Last) & ':' &
                 Col_Img (2 .. Col_Img'Last) & ": " &
                 Message);
   end Error;

   -----------
   -- Error --
   -----------

   procedure Error (Level    : Error_Level;
                    Message  : String)
   is
      Line_Img : constant String := Line_Number'Image (Current_Line);
      Col_Img  : constant String := Column_Number'Image (Current_Column);
   begin
      Put_Error (File_Manager.Get_File_Name (Current_File) &
                 ":" &
                 Line_Img (2 .. Line_Img'Last) & ':' &
                 Col_Img (2 .. Col_Img'Last) & ": " &
                 To_String (Prefix (Level)) &
                 Message);
      Got_Error (Level) := True;
      if Is_Fatal (Error) then
         raise Hit_Fatal_Error;
      end if;

   end Error;

   -----------
   -- Error --
   -----------

   procedure Error (Level       : Error_Level;
                    File_Name   : String;
                    Line        : Line_Number;
                    Column      : Column_Count;
                    Message     : String)
   is
      Line_Img : constant String := Line_Number'Image (Line);
      Col_Img  : constant String := Column_Number'Image (Column);
   begin
      Put_Error (File_Name & ":" &
                 Line_Img (2 .. Line_Img'Last) & ':' &
                 Col_Img (2 .. Col_Img'Last) & ": " &
                 To_String (Prefix (Level)) &
                 Message);

      Got_Error (Level) := True;
      if Is_Fatal (Error) then
         raise Hit_Fatal_Error;
      end if;

   end Error;

   -----------
   -- Error --
   -----------

   procedure Error (Level    : Error_Level;
                    Location : GCS.Positions.File_Position;
                    Message  : String)
   is
      use GCS.Positions;
   begin
      Error (Level,
             GCS.File_Manager.Get_File_Name (Get_File (Location)),
             Get_Line (Location), Get_Column (Location),
             Message);
   end Error;

   -----------
   -- Error --
   -----------

   procedure Error (Location : GCS.Positions.File_Position;
                    Message  : String)
   is
   begin
      Error (Error, Location, Message);
   end Error;

   -----------------
   -- Fatal_Error --
   -----------------

   procedure Fatal_Error (File_Name   : String;
                          Line        : Line_Number;
                          Column      : Column_Number;
                          Message     : String)
   is
      Line_Img : constant String := Line_Number'Image (Line);
      Col_Img  : constant String := Column_Number'Image (Column);
   begin
      Got_Error (Fatal) := True;

      Put_Error (File_Name & ':' &
                 Line_Img (2 .. Line_Img'Last) & ':' &
                 Col_Img (2 .. Col_Img'Last) & ": " &
                 "fatal error: " &
                 Message);
      raise Hit_Fatal_Error;
   end Fatal_Error;

   ----------------
   -- Has_Errors --
   ----------------

   function Has_Errors return Boolean is
   begin
      for I in Error_Level loop
         if Got_Error (I) and then Is_Error (I) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Errors;

   ---------------------
   -- Has_Fatal_Error --
   ---------------------

   function Has_Fatal_Error return Boolean is
   begin
      for I in Error_Level loop
         if Got_Error (I) and then Is_Fatal (I) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Fatal_Error;

   ------------------
   -- Has_Warnings --
   ------------------

   function Has_Warnings return Boolean is
   begin
      return Got_Error (Warning);
   end Has_Warnings;

   --------------------
   -- Internal_Error --
   --------------------

   procedure Internal_Error (File_Name   : String;
                             Line        : Line_Number;
                             Column      : Column_Number;
                             Message     : String)
   is
   begin
      Got_Error (Internal) := True;

      Put_Error ("The following internal compiler error " &
                 "has occured:");
      Error (File_Name, Line, Column, Message);
      Put_Error ("Please contact " & Contact_Email);
      raise Hit_Internal_Error;
   end Internal_Error;

   ---------------
   -- Put_Error --
   ---------------

   procedure Put_Error (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            Message);
   end Put_Error;

   -----------------
   -- Set_Context --
   -----------------

   procedure Set_Context (File_Index  : Source_File_Type;
                          Line        : Line_Number;
                          Column      : Column_Number)
   is
   begin
      Current_File   := File_Index;
      Current_Line   := Line;
      Current_Column := Column;
   end Set_Context;

   -------------
   -- Warning --
   -------------

   procedure Warning (File_Name   : String;
                      Line        : Line_Number;
                      Column      : Column_Number;
                      Message     : String)
   is
      Line_Img : constant String := Line_Number'Image (Line);
      Col_Img  : constant String := Column_Number'Image (Column);
   begin
      Got_Error (Warning) := True;

      Put_Error (File_Name & ':' &
                 Line_Img (2 .. Line_Img'Last) & ':' &
                 Col_Img (2 .. Col_Img'Last) & ": " &
                 "warning: " &
                 Message);
   end Warning;

end GCS.Errors;
