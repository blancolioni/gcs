with Ada.Text_IO;

package body GCS.Token_Parser is

   subtype State_Vector is List_Of_States.Vector;

   type Array_Of_State_Lists is array (Positive range <>) of State_Vector;
   type Array_Of_State_List_Access is access Array_Of_State_Lists;

   type Character_Map is array (Character) of Natural;

   State_Machine : Array_Of_State_List_Access;
   Map           : Character_Map := (others => 0);
   State_Count   : Natural := 0;

   procedure Set_Symbol_Characters (Chars : String) is
      Char_Count    : Natural;
   begin
      Char_Count := 0;
      for I in Chars'Range loop
         if Chars (I) /= ' ' then
            if Map (Chars (I)) = 0 then
               Char_Count := Char_Count + 1;
               Map (Chars (I)) := Char_Count;
            end if;
         end if;
      end loop;

      Char_Count := Char_Count + 1;
      Map (' ') := Char_Count;
      State_Machine := new Array_Of_State_Lists (1 .. Char_Count);
   end Set_Symbol_Characters;

   function Get_Command (Char    : Character;
                         State   : Positive) return State_Command
   is
   begin
      if State > State_Machine (Map (Char)).Last_Index then
         return No_Command;
      else
         return State_Machine (Map (Char)).Element (State).Command;
      end if;
   end Get_Command;

   function Get_Result (Char  : Character;
                        State : Positive) return Positive is
   begin
      return State_Machine (Map (Char)).Element (State).Result;
   end Get_Result;

   function New_State return Positive is
      E : constant State_Entry := (No_Command, 1);
   begin
      State_Count := State_Count + 1;
      for I in State_Machine.all'Range loop
         State_Machine (I).Append (E);
      end loop;
      return State_Count;
   end New_State;

   procedure Fill_State (State   : Positive;
                         Cmd     : State_Command;
                         Result  : Positive)
   is
      E : constant State_Entry := (Cmd, Result);
   begin
      for I in State_Machine.all'Range loop
         State_Machine (I).Replace_Element (State, E);
      end loop;
   end Fill_State;

   procedure Fill_State (State   : Positive;
                         Filter  : State_Command;
                         Cmd     : State_Command;
                         Result  : Positive)
   is
      E : constant State_Entry := (Cmd, Result);
   begin
      for I in State_Machine.all'Range loop
         declare
            St   : State_Vector renames State_Machine (I);
            Item : State_Entry renames St (State);
         begin
            if Item.Command = Filter then
               Item := E;
            end if;
         end;
      end loop;
   end Fill_State;

   procedure Set_Command (Char   : Character;
                          State  : Positive;
                          Cmd    : State_Command;
                          Result : Positive)
   is
   begin
      State_Machine (Map (Char)).Replace_Element (State, (Cmd, Result));
   end Set_Command;

   procedure Dump_State_Table is
      use Ada.Text_IO;
      Ch : Character;
   begin
      for I in 1 .. Positive_Count (State_Count) loop
         Set_Col (I * 6);
         Put (Positive_Count'Image (I));
      end loop;
      New_Line;

      for I in State_Machine.all'Range loop
         for J in Character loop
            if Map (J) = I then
               Ch := J;
               Put (Ch);
               exit;
            end if;
         end loop;

         for Index in 1 .. State_Count loop
            Set_Col (Positive_Count (Index * 6));
            case Get_Command (Ch, Index) is
               when No_Command =>
                  Put ("X");
               when Accept_And_Skip =>
                  Put ("AS" & Integer'Image (-Get_Result (Ch, Index)));
               when Accept_And_Leave =>
                  Put ("AL" & Integer'Image (-Get_Result (Ch, Index)));
               when Skip_And_Change =>
                  Put ("SC" & Integer'Image (-Get_Result (Ch, Index)));
            end case;
         end loop;
         New_Line;
      end loop;

   end Dump_State_Table;

end GCS.Token_Parser;
