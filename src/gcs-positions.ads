with GCS.Constraints;                   use GCS.Constraints;

package GCS.Positions is

   type File_Position is private;

   function Null_Position return File_Position;

   function  Get_Current_Position return File_Position;

   function Get_File   (From : File_Position) return Source_File_Type;
   function Get_Line   (From : File_Position) return Line_Number;
   function Get_Column (From : File_Position) return Column_Count;
   function Get_Indent (From : File_Position) return Column_Number;

   function Image (Item : File_Position) return String;

   function "<" (Left, Right : File_Position) return Boolean;

private

   type File_Position is
      record
         File   : Source_File_Type;
         Line   : Line_Number;
         Col    : Column_Count;
         Indent : Column_Count;
      end record;

end GCS.Positions;
