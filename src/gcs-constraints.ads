------------------------------------------------------------------------------
--                                                                          --
--                         GENERIC COMPILER SYSTEM                          --
--                                                                          --
--                      G C S . C O N S T R A I N T S                       --
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

package GCS.Constraints is

   pragma Pure (GCS.Constraints);

   --  2000-12-14:fraser: Since Max_Open_Files is currently a hard
   --  limit, we set it to something ridiculous.  What we should do
   --  is close files when we run out of descriptors, then re-open
   --  them and seek to the appropriate spot.  Mind you, this could
   --  lead to nasty race conditions.  I don't know, really.  A hard
   --  limit is Bad though.

   Max_Line_Length       : constant := 4096;
   Max_Identifier_Length : constant := 200;
   Max_Open_Files        : constant := 500;
   Max_Source_Files      : constant := 10_000;

   subtype Column_Count is Integer range 0 .. Max_Line_Length;
   subtype Column_Number is Integer range 1 .. Column_Count'Last;

   subtype Line_Count is Integer range 0 .. Integer'Last;
   subtype Line_Number is Line_Count;
   --  Line_Number zero is used for things which
   --  don't actually appear in source, e.g.
   --  implicit declarations

   type Source_File_Type is range 0 .. Max_Source_Files;

end GCS.Constraints;
