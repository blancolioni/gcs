with GCS.Constraints;                  use GCS.Constraints;

private package GCS.File_Manager is

   pragma Elaborate_Body;

   procedure Open  (Name : String);
   procedure Open_Standard_Input;

   procedure Close;

   procedure Open_String (Text : String);

   procedure Add_Include_Path (Path   : String);

   function Current_File return Source_File_Type;
   function Current_File_Name return String;
   function Current_File_Title return String;
   function Get_File_Name (F : Source_File_Type) return String;

   function Current_Line return Line_Number;
   function Current_Column return Column_Number;
   function Current_Indent return Column_Number;
   function Current_Line_Text return String;

   function Current_Character return Character;
   function End_Of_Line return Boolean;
   function End_Of_File return Boolean;

   function Match (Text       : String;
                   Skip_Match : Boolean := False) return Boolean;

   procedure Skip;
   procedure Unskip;
   procedure Skip_Spaces;
   procedure Next_Line;

   procedure Set_Current_Position (File   : Source_File_Type;
                                   Line   : Line_Number;
                                   Col    : Column_Number;
                                   Indent : Column_Number);

   procedure Get_Current_Position (File   : out Source_File_Type;
                                   Line   : out Line_Number;
                                   Col    : out Column_Count;
                                   Indent : out Column_Count);

   procedure Add_Hash (Text : String);
   function Current_Hash return File_Hash;

private

   pragma Inline (Skip);

end GCS.File_Manager;
