private with Ada.Containers.Vectors;

generic
package GCS.Token_Parser is

   pragma Elaborate_Body;

   type State_Command is
      (No_Command, Accept_And_Skip, Accept_And_Leave, Skip_And_Change);

   procedure Set_Symbol_Characters (Chars : String);

   function Get_Command (Char    : Character;
                         State   : Positive) return State_Command;

   function Get_Result (Char  : Character;
                        State : Positive) return Positive;

   function New_State return Positive;

   procedure Fill_State (State   : Positive;
                         Cmd     : State_Command;
                         Result  : Positive);

   procedure Fill_State (State   : Positive;
                         Filter  : State_Command;
                         Cmd     : State_Command;
                         Result  : Positive);

   procedure Set_Command (Char   : Character;
                          State  : Positive;
                          Cmd    : State_Command;
                          Result : Positive);

   procedure Dump_State_Table;

private

   type State_Entry is
      record
         Command      : State_Command;
         Result       : Natural;
      end record;

   package List_Of_States is
      new Ada.Containers.Vectors (Positive, State_Entry);

end GCS.Token_Parser;
