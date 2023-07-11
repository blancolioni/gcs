------------------------------------------------------------------------------
--                                                                          --
--                         GENERIC COMPILER SYSTEM                          --
--                                                                          --
--                           G C S . S T Y L E S                            --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--                            $Revision: 1.1.1.1 $                              --
--                                                                          --
--                    Copyright (c) 2000 Fraser Wilson                      --
--                                                                          --
-- GCS is free software; you can redistribute it  and/or  modify  it  under --
-- terms  of  the  GNU  General  Public  License  as  published by the Free --
-- Software Foundation; either version 2, or (at  your  option)  any  later --
-- version.  GCS  is  distributed  in  the hope that it will be useful, but --
-- WITHOUTANY WARRANTY; without even the implied warranty of  MERCHANTABIL- --
-- ITY  or  FITNESS  FOR  A  PARTICULAR PURPOSE. See the GNU General Public --
-- License for more details. You should have received a  copy  of  the  GNU --
-- General  Public  License distributed with GCS; see file COPYING. If not, --
-- write to the Free Software Foundation, 59  Temple  Place  -  Suite  330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
------------------------------------------------------------------------------

package GCS.Styles is

--     pragma Pure (GCS.Styles);

   type Property is
      (Multi_Line_Strings,            --  strings do not need to be on one line
       Multi_Characters,              --  multiple chars between single quotes
       Single_Quote_Token,            --  lone quote is a separate token
       Case_Sensitive_Identifiers,    --  XXX is different to xxx
       Ada_Number_Bases,              --  16#F00D#
       Two_Quote_Escape);             --  "" -> " within "'s
                                      --  '' -> ' with 's

   type Property_List is array (Property) of Boolean;

   type Hook_Function_Property is
     (Character_Hook);       --  Hook function for transforming characters

   type Hook_Function is access function (Item : String) return String;

   type Hook_Function_List is
     array (Hook_Function_Property) of Hook_Function;

   Ada_Property_List : constant Property_List :=
     (Single_Quote_Token    => True,
      Two_Quote_Escape      => True,
      Ada_Number_Bases      => True,
      others                => False);

   C_Property_List : constant Property_List :=
     (Case_Sensitive_Identifiers => True,
      others                     => False);

   Default_Hook_Function_List : constant Hook_Function_List :=
     (others => null);

end GCS.Styles;
