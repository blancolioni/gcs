with GCS.Constraints;                   use GCS.Constraints;
with GCS.Positions;

package GCS.Errors is

   --  Standard error package.  There are four error levels: warning,
   --  non-fatal error, fatal error and internal error.  Perhaps this
   --  should be an enumerated type with properties.

   Hit_Internal_Error : exception;
   Hit_Fatal_Error    : exception;

   type Error_Level is (Warning, Error, Fatal, Internal);

   function Has_Warnings return Boolean;
   function Has_Errors   return Boolean;
   function Has_Fatal_Error return Boolean;

   procedure Clear_Errors;
   --  Clear all errors and warnings

   procedure Warning (File_Name   : String;
                      Line        : Line_Number;
                      Column      : Column_Number;
                      Message     : String);

   procedure Error (File_Name   : String;
                    Line        : Line_Number;
                    Column      : Column_Count;
                    Message     : String);

   procedure Fatal_Error (File_Name   : String;
                          Line        : Line_Number;
                          Column      : Column_Number;
                          Message     : String);

   procedure Internal_Error (File_Name   : String;
                             Line        : Line_Number;
                             Column      : Column_Number;
                             Message     : String);

   procedure Set_Context (File_Index  : Source_File_Type;
                          Line        : Line_Number;
                          Column      : Column_Number);

   procedure Error (Level    : Error_Level;
                    Message  : String);

   procedure Error (Level       : Error_Level;
                    File_Name   : String;
                    Line        : Line_Number;
                    Column      : Column_Count;
                    Message     : String);

   procedure Error (Level    : Error_Level;
                    Location : GCS.Positions.File_Position;
                    Message  : String);

   procedure Error (Location : GCS.Positions.File_Position;
                    Message  : String);

end GCS.Errors;
