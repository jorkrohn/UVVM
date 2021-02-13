--================================================================================================================================
-- Copyright 2020 Bitvis
-- Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 and in the provided LICENSE.TXT.
--
-- Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
-- an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and limitations under the License.
--================================================================================================================================
-- Note : Any functionality not explicitly described in the documentation is subject to change at any time
----------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Description   : See library quick reference (under 'doc') and README-file(s)
------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.types_pkg.all;
use work.adaptations_pkg.all;
use work.string_methods_pkg.all;
use work.global_signals_and_shared_variables_pkg.all;
use work.methods_pkg.all;
use work.rand_pkg.all;

package funct_cov_pkg is

  constant C_MAX_NUM_CROSS_BINS   : positive := 15;
  --TODO: move to adaptations_pkg?
  constant C_MAX_NUM_BINS         : positive := 100; --Q: make it possible to grow?
  constant C_MAX_NUM_BIN_VALUES   : positive := 10;
  constant C_MAX_BIN_NAME_LENGTH  : positive := 20;
  constant C_MAX_PROC_CALL_LENGTH : positive := 100;

  ------------------------------------------------------------
  -- Types
  ------------------------------------------------------------
  type t_cov_bin_type is (VAL, VAL_IGNORE, VAL_ILLEGAL, RAN, RAN_IGNORE, RAN_ILLEGAL, TRN, TRN_IGNORE, TRN_ILLEGAL);
  type t_overlap_action is (ALERT, COUNT_ALL, COUNT_ONE); --TODO: use

  type t_new_bin is record
    contains   : t_cov_bin_type;
    values     : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
    num_values : natural;
  end record;
  type t_new_bin_vector is array (natural range <>) of t_new_bin;

  type t_new_cov_bin is record
    bin_vector : t_new_bin_vector(0 to C_MAX_NUM_BINS-1); --Q: possible to not constrain here?
    num_bins   : natural;
    proc_call  : string(1 to C_MAX_PROC_CALL_LENGTH);
  end record;
  type t_new_bin_array is array (natural range <>) of t_new_cov_bin;
  constant C_EMPTY_NEW_BIN_ARRAY : t_new_bin_array(0 to 0) := (0 => ((0 to C_MAX_NUM_BINS-1 => (VAL, (others => 0), 0)),
                                                                     0,
                                                                     (1 to C_MAX_PROC_CALL_LENGTH => ' ')));

  type t_bin is record
    contains       : t_cov_bin_type;
    values         : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
    num_values     : natural;
    transition_idx : natural;
  end record;
  type t_bin_vector is array (natural range <>) of t_bin;

  type t_cov_bin is record
    cross_bins     : t_bin_vector(0 to C_MAX_NUM_CROSS_BINS-1);
    hits           : natural;
    min_hits       : natural;
    rand_weight    : natural;
    name           : string(1 to C_MAX_BIN_NAME_LENGTH);
  end record;
  type t_cov_bin_vector is array (natural range <>) of t_cov_bin;

  ------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------
  -- Creates a bin with a single value
  impure function bin(
    constant value      : integer)
  return t_new_bin_array;

  -- Creates a bin with multiple values
  impure function bin(
    constant set_values : integer_vector)
  return t_new_bin_array;

  -- Divides a range of values into a number bins. If num_bins is 0 then a bin is created for each value.
  impure function bin_range(
    constant min_value  : integer;
    constant max_value  : integer;
    constant num_bins   : natural := 0)
  return t_new_bin_array;

  -- Creates a bin for each value in the vector's range
  impure function bin_vector(
    constant vector     : std_logic_vector)
  return t_new_bin_array;

  -- Creates a bin with a transition of values
  impure function bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array;

  -- Creates an ignore bin with a single value
  impure function ignore_bin(
    constant value      : integer)
  return t_new_bin_array;

  -- Creates an ignore bin with a range of values
  impure function ignore_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_array;

  -- Creates an ignore bin with a transition of values
  impure function ignore_bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array;

  -- Creates an illegal bin with a single value
  impure function illegal_bin(
    constant value      : integer)
  return t_new_bin_array;

  -- Creates an illegal bin with a range of values
  impure function illegal_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_array;

  -- Creates an illegal bin with a transition of values
  impure function illegal_bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array;

  ------------------------------------------------------------
  -- Protected type
  ------------------------------------------------------------
  type t_cov_point is protected

    ------------------------------------------------------------
    -- Configuration
    ------------------------------------------------------------
    procedure set_scope(
      constant scope : in string);

    impure function get_scope(
      constant VOID : t_void)
    return string;

    procedure set_name(
      constant name : in string);

    impure function get_name(
      constant VOID : t_void)
    return string;

    ------------------------------------------------------------
    -- Bins
    ------------------------------------------------------------
    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "");

    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant min_cov       : in positive;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure add_cross(
      constant bin1          : in t_new_bin_array;
      constant bin2          : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "");

    procedure add_cross(
      constant bin1          : in t_new_bin_array;
      constant bin2          : in t_new_bin_array;
      constant bin3          : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "");

    ------------------------------------------------------------
    -- Randomization
    ------------------------------------------------------------
    impure function rand(
      constant msg_id_panel  : t_msg_id_panel := shared_msg_id_panel)
    return integer;

    impure function rand(
      constant msg_id_panel  : t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : string         := "")
    return integer_vector;

    ------------------------------------------------------------
    -- Coverage
    ------------------------------------------------------------
    procedure sample_coverage(
      constant value         : in integer;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel);

    procedure sample_coverage(
      constant values        : in integer_vector;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "");

    impure function coverage_complete(
      constant VOID : t_void)
    return boolean;

    procedure print_summary(
      constant VOID : in t_void);

  end protected t_cov_point;

end package funct_cov_pkg;

package body funct_cov_pkg is

  ------------------------------------------------------------
  -- Functions
  ------------------------------------------------------------
  -- Creates a bin with a single value
  impure function bin(
    constant value      : integer)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "bin(" & to_string(value) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := VAL;
    v_ret(0).bin_vector(0).values(0)  := value;
    v_ret(0).bin_vector(0).num_values := 1;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates a bin with multiple values
  impure function bin(
    constant set_values : integer_vector)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "bin(" & to_string(set_values) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := VAL;
    v_ret(0).bin_vector(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).bin_vector(0).num_values := set_values'length;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Divides a range of values into a number bins. If num_bins is 0 then a bin is created for each value.
  impure function bin_range(
    constant min_value  : integer;
    constant max_value  : integer;
    constant num_bins   : natural := 0)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "bin_range(" & to_string(min_value) & "," & to_string(max_value) & "," & to_string(num_bins) & ")";
    constant C_RANGE_WIDTH     : integer := abs(max_value - min_value) + 1;
    variable v_div_range       : integer;
    variable v_div_residue     : integer := 0;
    variable v_div_residue_min : integer := 0;
    variable v_div_residue_max : integer := 0;
    variable v_num_bins        : integer := 0;
    variable v_ret             : t_new_bin_array(0 to 0);
  begin
    if min_value <= max_value then
      -- Create a bin for each value in the range
      if num_bins = 0 then
        for i in min_value to max_value loop
          v_ret(0).bin_vector(i-min_value).contains   := VAL;
          v_ret(0).bin_vector(i-min_value).values(0)  := i;
          v_ret(0).bin_vector(i-min_value).num_values := 1;
        end loop;
        v_num_bins  := C_RANGE_WIDTH;
      -- Create several bins
      else
        if C_RANGE_WIDTH > num_bins then
          v_div_residue := C_RANGE_WIDTH mod num_bins;
          v_div_range   := C_RANGE_WIDTH / num_bins;
          v_num_bins    := num_bins;
        else
          v_div_residue := 0;
          v_div_range   := 1;
          v_num_bins    := C_RANGE_WIDTH;
        end if;
        for i in 0 to v_num_bins-1 loop
          -- Add the residue values to the last bins
          if v_div_residue /= 0 and i = v_num_bins-v_div_residue then
            v_div_residue_max := v_div_residue_max + 1;
          elsif v_div_residue /= 0 and i > v_num_bins-v_div_residue then
            v_div_residue_min := v_div_residue_min + 1;
            v_div_residue_max := v_div_residue_max + 1;
          end if;
          v_ret(0).bin_vector(i).contains   := RAN;
          v_ret(0).bin_vector(i).values(0)  := min_value + v_div_range*i + v_div_residue_min;
          v_ret(0).bin_vector(i).values(1)  := min_value + v_div_range*(i+1)-1 + v_div_residue_max;
          v_ret(0).bin_vector(i).num_values := 2;
        end loop;
      end if;
    else
      alert(TB_ERROR, C_LOCAL_CALL & "=> Failed. min_value must be less or equal than max_value", C_SCOPE);
    end if;
    v_ret(0).num_bins := v_num_bins;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates a bin for each value in the vector's range
  impure function bin_vector(
    constant vector     : std_logic_vector)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "bin_vector(LEN:" & to_string(vector'length) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    for i in 0 to 2**vector'length-1 loop
      v_ret(0).bin_vector(i).contains   := VAL;
      v_ret(0).bin_vector(i).values(0)  := i;
      v_ret(0).bin_vector(i).num_values := 1;
    end loop;
    v_ret(0).num_bins := 2**vector'length;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates a bin with a transition of values
  impure function bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "bin_transition(" & to_string(set_values) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := TRN;
    v_ret(0).bin_vector(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).bin_vector(0).num_values := set_values'length;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an ignore bin with a single value
  impure function ignore_bin(
    constant value      : integer)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "ignore_bin(" & to_string(value) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := VAL_IGNORE;
    v_ret(0).bin_vector(0).values(0)  := value;
    v_ret(0).bin_vector(0).num_values := 1;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an ignore bin with a range of values
  impure function ignore_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "ignore_bin_range(" & to_string(min_value) & "," & to_string(max_value) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := RAN_IGNORE;
    v_ret(0).bin_vector(0).values(0)  := min_value;
    v_ret(0).bin_vector(0).values(1)  := max_value;
    v_ret(0).bin_vector(0).num_values := 2;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an ignore bin with a transition of values
  impure function ignore_bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "ignore_bin_transition(" & to_string(set_values) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := TRN_IGNORE;
    v_ret(0).bin_vector(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).bin_vector(0).num_values := set_values'length;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an illegal bin with a single value
  impure function illegal_bin(
    constant value      : integer)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "illegal_bin(" & to_string(value) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := VAL_ILLEGAL;
    v_ret(0).bin_vector(0).values(0)  := value;
    v_ret(0).bin_vector(0).num_values := 1;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an illegal bin with a range of values
  impure function illegal_bin_range(
    constant min_value  : integer;
    constant max_value  : integer)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "illegal_bin_range(" & to_string(min_value) & "," & to_string(max_value) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := RAN_ILLEGAL;
    v_ret(0).bin_vector(0).values(0)  := min_value;
    v_ret(0).bin_vector(0).values(1)  := max_value;
    v_ret(0).bin_vector(0).num_values := 2;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  -- Creates an illegal bin with a transition of values
  impure function illegal_bin_transition(
    constant set_values : integer_vector)
  return t_new_bin_array is
    constant C_LOCAL_CALL : string := "illegal_bin_transition(" & to_string(set_values) & ")";
    variable v_ret : t_new_bin_array(0 to 0);
  begin
    v_ret(0).bin_vector(0).contains   := TRN_ILLEGAL;
    v_ret(0).bin_vector(0).values(0 to set_values'length-1) := set_values;
    v_ret(0).bin_vector(0).num_values := set_values'length;
    v_ret(0).num_bins := 1;
    v_ret(0).proc_call(1 to C_LOCAL_CALL'length) := C_LOCAL_CALL;
    return v_ret;
  end function;

  ------------------------------------------------------------
  -- Protected type
  ------------------------------------------------------------
  type t_cov_point is protected body
    variable priv_scope                         : line    := new string'(C_SCOPE);
    variable priv_name                          : line    := new string'("");
    variable priv_bins                          : t_cov_bin_vector(0 to C_MAX_NUM_BINS-1);
    variable priv_bins_idx                      : natural := 0;
    variable priv_invalid_bins                  : t_cov_bin_vector(0 to C_MAX_NUM_BINS-1);
    variable priv_invalid_bins_idx              : natural := 0;
    variable priv_num_bins_crossed              : integer := -1;
    variable priv_rand_gen                      : t_rand;
    variable priv_rand_transition_bin_idx       : integer := -1;
    variable priv_rand_transition_bin_value_idx : natural := 0;

    ------------------------------------------------------------
    -- Internal functions and procedures
    ------------------------------------------------------------
    -- Returns a string with all the procedure calls in the array
    impure function get_proc_calls(
      bin_array : t_new_bin_array)
    return string is
      variable v_line   : line;
      variable v_result : string(1 to 500);
      variable v_width  : natural;
    begin
      for i in bin_array'range loop
        write(v_line, bin_array(i).proc_call);
        if i < bin_array'length-1 then
          write(v_line, ',');
        end if;
      end loop;

      v_width := v_line'length;
      v_result(1 to v_width) := v_line.all;
      deallocate(v_line);
      return v_result(1 to v_width);
    end function;

    -- Returns a string with all the bins values in the array
    impure function get_bin_array_values(
      bin_array     : t_new_bin_array;
      use_full_name : boolean := false;
      bin_delimiter : character := ',')
    return string is
      variable v_line   : line;
      variable v_result : string(1 to 500);
      variable v_width  : natural;
    begin
      for i in bin_array'range loop
        for j in 0 to bin_array(i).num_bins-1 loop
          case bin_array(i).bin_vector(j).contains is
            when VAL | VAL_IGNORE | VAL_ILLEGAL =>
              if bin_array(i).bin_vector(j).contains = VAL then
                write(v_line, string'(return_string1_if_true_otherwise_string2("bin", "", use_full_name)));
              elsif bin_array(i).bin_vector(j).contains = VAL_IGNORE then
                write(v_line, string'(return_string1_if_true_otherwise_string2("ignore_bin", "IGN", use_full_name)));
              else
                write(v_line, string'(return_string1_if_true_otherwise_string2("illegal_bin", "ILL", use_full_name)));
              end if;
              if bin_array(i).bin_vector(j).num_values = 1 then
                write(v_line, '(');
                write(v_line, to_string(bin_array(i).bin_vector(j).values(0)));
                write(v_line, ')');
              else
                write(v_line, to_string(bin_array(i).bin_vector(j).values(0 to bin_array(i).bin_vector(j).num_values-1)));
              end if;
            when RAN | RAN_IGNORE | RAN_ILLEGAL =>
              if bin_array(i).bin_vector(j).contains = RAN then
                write(v_line, string'(return_string1_if_true_otherwise_string2("bin_range", "", use_full_name)));
              elsif bin_array(i).bin_vector(j).contains = RAN_IGNORE then
                write(v_line, string'(return_string1_if_true_otherwise_string2("ignore_bin_range", "IGN", use_full_name)));
              else
                write(v_line, string'(return_string1_if_true_otherwise_string2("illegal_bin_range", "ILL", use_full_name)));
              end if;
              write(v_line, "(" & to_string(bin_array(i).bin_vector(j).values(0)) & " to " & to_string(bin_array(i).bin_vector(j).values(1)) & ")");
            when TRN | TRN_IGNORE | TRN_ILLEGAL =>
              if bin_array(i).bin_vector(j).contains = TRN then
                write(v_line, string'(return_string1_if_true_otherwise_string2("bin_transition", "", use_full_name)));
              elsif bin_array(i).bin_vector(j).contains = TRN_IGNORE then
                write(v_line, string'(return_string1_if_true_otherwise_string2("ignore_bin_transition", "IGN", use_full_name)));
              else
                write(v_line, string'(return_string1_if_true_otherwise_string2("illegal_bin_transition", "ILL", use_full_name)));
              end if;
              write(v_line, '(');
              for k in 0 to bin_array(i).bin_vector(j).num_values-1 loop
                write(v_line, to_string(bin_array(i).bin_vector(j).values(k)));
                if k < bin_array(i).bin_vector(j).num_values-1 then
                  write(v_line, string'("->"));
                end if;
              end loop;
              write(v_line, ')');
          end case;
          if i < bin_array'length-1 or j < bin_array(i).num_bins-1 then
            write(v_line, bin_delimiter);
          end if;
        end loop;
      end loop;

      v_width := v_line'length;
      v_result(1 to v_width) := v_line.all;
      deallocate(v_line);
      return v_result(1 to v_width);
    end function;

    -- Returns a string with all the bins values in the vector
    -- Used in the report, so the bins in the vector are crossed
    impure function get_bin_vector_values(
      bins : t_bin_vector)
    return string is
      variable v_new_bin_array : t_new_bin_array(0 to 0);
    begin
      for i in 0 to bins'length-1 loop
        v_new_bin_array(0).bin_vector(i).contains   := bins(i).contains;
        v_new_bin_array(0).bin_vector(i).values     := bins(i).values;
        v_new_bin_array(0).bin_vector(i).num_values := bins(i).num_values;
      end loop;
      v_new_bin_array(0).num_bins := bins'length;
      return get_bin_array_values(v_new_bin_array, false, 'x');
    end function;

    -- Returns a string with the bin content
    impure function get_bin_info(
      bin : t_bin)
    return string is
      variable v_new_bin_array : t_new_bin_array(0 to 0);
    begin
      v_new_bin_array(0).bin_vector(0).contains   := bin.contains;
      v_new_bin_array(0).bin_vector(0).values     := bin.values;
      v_new_bin_array(0).bin_vector(0).num_values := bin.num_values;
      v_new_bin_array(0).num_bins := 1;
      return get_bin_array_values(v_new_bin_array, true);
    end function;

    -- Returns true if the bin is ignored
    impure function is_bin_ignore(
      constant bin : t_cov_bin)
    return boolean is
      variable v_is_ignore : boolean := false;
    begin
      for i in 0 to priv_num_bins_crossed-1 loop
        v_is_ignore := v_is_ignore or (bin.cross_bins(i).contains = VAL_IGNORE or
                                       bin.cross_bins(i).contains = RAN_IGNORE or
                                       bin.cross_bins(i).contains = TRN_IGNORE);
      end loop;
      return v_is_ignore;
    end function;

    -- Returns true if the bin is illegal
    impure function is_bin_illegal(
      constant bin : t_cov_bin)
    return boolean is
      variable v_is_illegal : boolean := false;
    begin
      for i in 0 to priv_num_bins_crossed-1 loop
        v_is_illegal := v_is_illegal or (bin.cross_bins(i).contains = VAL_ILLEGAL or
                                         bin.cross_bins(i).contains = RAN_ILLEGAL or
                                         bin.cross_bins(i).contains = TRN_ILLEGAL);
      end loop;
      return v_is_illegal;
    end function;

    -- Returns the number of covered bins
    impure function get_num_covered_bins(
      constant VOID : t_void)
    return integer is
      variable v_cnt : integer := 0;
    begin
      for i in 0 to priv_bins_idx-1 loop
        v_cnt := v_cnt + 1 when priv_bins(i).hits >= priv_bins(i).min_hits;
      end loop;
      return v_cnt;
    end function;

    -- Returns the number of illegal bins
    impure function get_num_illegal_bins(
      constant VOID : t_void)
    return integer is
      variable v_cnt : integer := 0;
    begin
      for i in 0 to priv_invalid_bins_idx-1 loop
        v_cnt := v_cnt + 1 when is_bin_illegal(priv_invalid_bins(i));
      end loop;
      return v_cnt;
    end function;

    -- Returns the percentage of hits/min_hits in a bin
    impure function get_bin_coverage(
      constant bin : t_cov_bin)
    return real is
    begin
      return real(bin.hits)*100.0/real(bin.min_hits);
    end function;

    -- Returns the percentage of bins_covered/total_bins in the coverpoint
    impure function get_covpoint_coverage(
      constant VOID : t_void)
    return real is
      variable v_num_cov_bins : integer := 0;
    begin
      v_num_cov_bins := get_num_covered_bins(VOID);
      return real(v_num_cov_bins)*100.0/real(priv_bins_idx);
    end function;

    -- Returns the percentage of hits/min_hits for all the bins in the coverpoint
    impure function get_covpoint_coverage_accumulated(
      constant VOID : t_void)
    return real is
      variable v_hits     : natural := 0;
      variable v_min_hits : natural := 0;
    begin
      for i in 0 to priv_bins_idx-1 loop
        v_hits     := v_hits + priv_bins(i).hits;
        v_min_hits := v_min_hits + priv_bins(i).min_hits;
      end loop;
      return real(v_hits)*100.0/real(v_min_hits);
    end function;

    -- Generates the correct procedure call to be used for logging or alerts
    procedure create_proc_call(
      constant proc_call     : in    string;
      constant ext_proc_call : in    string;
      variable new_proc_call : inout line) is
    begin
      -- Called directly from sequencer/VVC
      if ext_proc_call = "" then
        write(new_proc_call, proc_call);
      -- Called from another procedure
      else
        write(new_proc_call, ext_proc_call);
      end if;
    end procedure;

    -- Checks that the number of bins used does not change
    procedure check_num_bins_crossed(
      constant num_bins_crossed : in natural;
      constant local_call       : in string) is
    begin
      -- The number of bins crossed is set on the first call and can't be changed
      if priv_num_bins_crossed = -1 then
        priv_num_bins_crossed := num_bins_crossed;
      elsif priv_num_bins_crossed /= num_bins_crossed then
        alert(TB_FAILURE, local_call & "=> Failed. Cannot mix different number of crossed bins.", priv_scope.all);
      end if;
    end procedure;

    -- Creates a bin array from several bin vectors
    procedure create_bin_array(
      variable bin_array : out t_new_bin_array;
      constant bin1      : in  t_new_bin_array;
      constant bin2      : in  t_new_bin_array := C_EMPTY_NEW_BIN_ARRAY;
      constant bin3      : in  t_new_bin_array := C_EMPTY_NEW_BIN_ARRAY;
      constant bin4      : in  t_new_bin_array := C_EMPTY_NEW_BIN_ARRAY) is
      variable v_num_bins : natural := 0;
    begin
      for i in bin1'range loop
        bin_array(0).bin_vector(v_num_bins to v_num_bins+bin1(i).num_bins-1) := bin1(i).bin_vector(0 to bin1(i).num_bins-1);
        v_num_bins := v_num_bins + bin1(i).num_bins;
      end loop;
      bin_array(0).num_bins := v_num_bins;

      if bin2 /= C_EMPTY_NEW_BIN_ARRAY then
        v_num_bins := 0;
        for i in bin2'range loop
          bin_array(1).bin_vector(v_num_bins to v_num_bins+bin2(i).num_bins-1) := bin2(i).bin_vector(0 to bin2(i).num_bins-1);
          v_num_bins := v_num_bins + bin2(i).num_bins;
        end loop;
        bin_array(1).num_bins := v_num_bins;
      end if;

      if bin3 /= C_EMPTY_NEW_BIN_ARRAY then
        v_num_bins := 0;
        for i in bin3'range loop
          bin_array(2).bin_vector(v_num_bins to v_num_bins+bin3(i).num_bins-1) := bin3(i).bin_vector(0 to bin3(i).num_bins-1);
          v_num_bins := v_num_bins + bin3(i).num_bins;
        end loop;
        bin_array(2).num_bins := v_num_bins;
      end if;

      if bin4 /= C_EMPTY_NEW_BIN_ARRAY then
        v_num_bins := 0;
        for i in bin4'range loop
          bin_array(3).bin_vector(v_num_bins to v_num_bins+bin4(i).num_bins-1) := bin4(i).bin_vector(0 to bin4(i).num_bins-1);
          v_num_bins := v_num_bins + bin4(i).num_bins;
        end loop;
        bin_array(3).num_bins := v_num_bins;
      end if;
      -- TODO: add more bins
    end procedure;

    -- Adds bins in a recursive way
    procedure add_bins_recursive(
      constant bin_array     : in    t_new_bin_array;
      constant bin_array_idx : in    integer;
      variable idx_reg       : inout integer_vector;
      constant min_cov       : in    positive;
      constant rand_weight   : in    natural;
      constant bin_name      : in    string) is
      constant C_NUM_CROSS_BINS : natural := bin_array'length;
      variable v_bin_is_valid   : boolean := true;
    begin
      -- Iterate through the bins in the current array element
      for i in 0 to bin_array(bin_array_idx).num_bins-1 loop
        -- Store the bin index for the current element of the array
        idx_reg(bin_array_idx) := i;
        -- Last element of the array has been reached, add bins
        if bin_array_idx = C_NUM_CROSS_BINS-1 then
          -- Check that all the bins being added are valid
          for j in 0 to C_NUM_CROSS_BINS-1 loop
            v_bin_is_valid := v_bin_is_valid and (bin_array(j).bin_vector(idx_reg(j)).contains = VAL or
                                                  bin_array(j).bin_vector(idx_reg(j)).contains = RAN or
                                                  bin_array(j).bin_vector(idx_reg(j)).contains = TRN);
          end loop;
          -- Store valid bins
          if v_bin_is_valid then
            for j in 0 to C_NUM_CROSS_BINS-1 loop
              priv_bins(priv_bins_idx).cross_bins(j).contains       := bin_array(j).bin_vector(idx_reg(j)).contains;
              priv_bins(priv_bins_idx).cross_bins(j).values         := bin_array(j).bin_vector(idx_reg(j)).values;
              priv_bins(priv_bins_idx).cross_bins(j).num_values     := bin_array(j).bin_vector(idx_reg(j)).num_values;
              priv_bins(priv_bins_idx).cross_bins(j).transition_idx := 0;
            end loop;
            priv_bins(priv_bins_idx).hits                         := 0;
            priv_bins(priv_bins_idx).min_hits                     := min_cov;
            priv_bins(priv_bins_idx).rand_weight                  := rand_weight;
            priv_bins(priv_bins_idx).name(1 to bin_name'length)   := bin_name;
            priv_bins_idx := priv_bins_idx + 1;
          -- Store ignore or illegal bins
          else
            for j in 0 to C_NUM_CROSS_BINS-1 loop
              priv_invalid_bins(priv_invalid_bins_idx).cross_bins(j).contains       := bin_array(j).bin_vector(idx_reg(j)).contains;
              priv_invalid_bins(priv_invalid_bins_idx).cross_bins(j).values         := bin_array(j).bin_vector(idx_reg(j)).values;
              priv_invalid_bins(priv_invalid_bins_idx).cross_bins(j).num_values     := bin_array(j).bin_vector(idx_reg(j)).num_values;
              priv_invalid_bins(priv_invalid_bins_idx).cross_bins(j).transition_idx := 0;
            end loop;
            priv_invalid_bins(priv_invalid_bins_idx).hits                         := 0;
            priv_invalid_bins(priv_invalid_bins_idx).min_hits                     := min_cov;
            priv_invalid_bins(priv_invalid_bins_idx).rand_weight                  := rand_weight;
            priv_invalid_bins(priv_invalid_bins_idx).name(1 to bin_name'length)   := bin_name;
            priv_invalid_bins_idx := priv_invalid_bins_idx + 1;
          end if;
        -- Go to the next element of the array
        else
          add_bins_recursive(bin_array, bin_array_idx+1, idx_reg, min_cov, rand_weight, bin_name);
        end if;
      end loop;
    end procedure;

    ------------------------------------------------------------
    -- Configuration
    ------------------------------------------------------------
    procedure set_scope(
      constant scope : in string) is
    begin
      DEALLOCATE(priv_scope);
      priv_scope := new string'(scope);
    end procedure;

    impure function get_scope(
      constant VOID : t_void)
    return string is
    begin
      return priv_scope.all;
    end function;

    procedure set_name(
      constant name : in string) is
    begin
      DEALLOCATE(priv_name);
      priv_name := new string'(name);
    end procedure;

    impure function get_name(
      constant VOID : t_void)
    return string is
    begin
      return priv_name.all;
    end function;

    ------------------------------------------------------------
    -- Bins
    ------------------------------------------------------------
    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "") is
      constant C_LOCAL_CALL : string := "add_bins(" & get_proc_calls(bin) & ", min_cov:" & to_string(min_cov) &
        ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """)";
      constant C_NUM_CROSS_BINS : natural := 1;
      variable v_proc_call      : line;
      variable v_bin_array      : t_new_bin_array(0 to C_NUM_CROSS_BINS-1);
      variable v_idx_reg        : integer_vector(0 to C_NUM_CROSS_BINS-1);
    begin
      create_proc_call(C_LOCAL_CALL, ext_proc_call, v_proc_call);
      log(ID_FUNCT_COV, v_proc_call.all, priv_scope.all, msg_id_panel);
      log(ID_FUNCT_COV_BINS, "Adding bins: " &  get_bin_array_values(bin) & ", min_cov:" & to_string(min_cov) &
        ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """", priv_scope.all, msg_id_panel);

      -- Copy the bins into an array and use a recursive procedure to add them to the list
      check_num_bins_crossed(C_NUM_CROSS_BINS, v_proc_call.all);
      create_bin_array(v_bin_array, bin);
      add_bins_recursive(v_bin_array, 0, v_idx_reg, min_cov, rand_weight, bin_name);
    end procedure;

    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant min_cov       : in positive;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
      constant C_LOCAL_CALL : string := "add_bins(" & get_proc_calls(bin) & ", min_cov:" & to_string(min_cov) &
        ", """ & bin_name & """)";
    begin
      add_bins(bin, min_cov, 1, bin_name, msg_id_panel, C_LOCAL_CALL);
    end procedure;

    procedure add_bins(
      constant bin           : in t_new_bin_array;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
      constant C_LOCAL_CALL : string := "add_bins(" & get_proc_calls(bin) & ", """ & bin_name & """)";
    begin
      add_bins(bin, 1, 1, bin_name, msg_id_panel, C_LOCAL_CALL);
    end procedure;

    procedure add_cross(
      constant bin1          : in t_new_bin_array;
      constant bin2          : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "") is
      constant C_LOCAL_CALL : string := "add_cross((" & get_proc_calls(bin1) & "),(" & get_proc_calls(bin2) &
        "), min_cov:" & to_string(min_cov) & ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """)";
      constant C_NUM_CROSS_BINS : natural := 2;
      variable v_proc_call      : line;
      variable v_bin_array      : t_new_bin_array(0 to C_NUM_CROSS_BINS-1);
      variable v_idx_reg        : integer_vector(0 to C_NUM_CROSS_BINS-1);
    begin
      create_proc_call(C_LOCAL_CALL, ext_proc_call, v_proc_call);
      log(ID_FUNCT_COV, v_proc_call.all, priv_scope.all, msg_id_panel);
      log(ID_FUNCT_COV_BINS, "Adding cross: " &  get_bin_array_values(bin1) & " x "  &  get_bin_array_values(bin2) &
        ", min_cov:" & to_string(min_cov) & ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """", priv_scope.all, msg_id_panel);

      -- Copy the bins into an array and use a recursive procedure to add them to the list
      check_num_bins_crossed(C_NUM_CROSS_BINS, v_proc_call.all);
      create_bin_array(v_bin_array, bin1, bin2);
      add_bins_recursive(v_bin_array, 0, v_idx_reg, min_cov, rand_weight, bin_name);
    end procedure;

    procedure add_cross(
      constant bin1          : in t_new_bin_array;
      constant bin2          : in t_new_bin_array;
      constant bin3          : in t_new_bin_array;
      constant min_cov       : in positive;
      constant rand_weight   : in natural;
      constant bin_name      : in string         := "";
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "") is
      constant C_LOCAL_CALL : string := "add_cross((" & get_proc_calls(bin1) & "),(" & get_proc_calls(bin2) & "),(" & get_proc_calls(bin3) &
        "), min_cov:" & to_string(min_cov) & ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """)";
      constant C_NUM_CROSS_BINS : natural := 3;
      variable v_proc_call      : line;
      variable v_bin_array      : t_new_bin_array(0 to C_NUM_CROSS_BINS-1);
      variable v_idx_reg        : integer_vector(0 to C_NUM_CROSS_BINS-1);
    begin
      create_proc_call(C_LOCAL_CALL, ext_proc_call, v_proc_call);
      log(ID_FUNCT_COV, v_proc_call.all, priv_scope.all, msg_id_panel);
      log(ID_FUNCT_COV_BINS, "Adding cross: " &  get_bin_array_values(bin1) & " x "  &  get_bin_array_values(bin2) & " x "  &  get_bin_array_values(bin3) &
        ", min_cov:" & to_string(min_cov) & ", rand_weight:" & to_string(rand_weight) & ", """ & bin_name & """", priv_scope.all, msg_id_panel);

      -- Copy the bins into an array and use a recursive procedure to add them to the list
      check_num_bins_crossed(C_NUM_CROSS_BINS, v_proc_call.all);
      create_bin_array(v_bin_array, bin1, bin2, bin3);
      add_bins_recursive(v_bin_array, 0, v_idx_reg, min_cov, rand_weight, bin_name);
    end procedure;

    ------------------------------------------------------------
    -- Randomization
    ------------------------------------------------------------
    impure function rand(
      constant msg_id_panel  : t_msg_id_panel := shared_msg_id_panel)
    return integer is
      constant C_LOCAL_CALL  : string := "rand()";
      variable v_ret         : integer_vector(0 to 0);
    begin
      v_ret := rand(msg_id_panel, C_LOCAL_CALL);
      log(ID_FUNCT_COV, C_LOCAL_CALL & "=> " & to_string(v_ret(0)), priv_scope.all, msg_id_panel);
      return v_ret(0);
    end function;

    impure function rand(
      constant msg_id_panel  : t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : string         := "")
    return integer_vector is
      constant C_LOCAL_CALL      : string := "rand()";
      variable v_bin_weight_list : t_val_weight_int_vec(0 to priv_bins_idx-1);
      variable v_acc_weight      : integer := 0;
      variable v_values_vec      : integer_vector(0 to C_MAX_NUM_BIN_VALUES-1);
      variable v_bin_idx         : integer;
      variable v_ret             : integer_vector(0 to priv_num_bins_crossed-1);
    begin
      if priv_num_bins_crossed = -1 then
        alert(TB_FAILURE, C_LOCAL_CALL & "=> Failed. Coverage point has not been initialized", priv_scope.all);
      end if;

      -- A transition bin returns all the transition values before allowing to select a different bin value
      if priv_rand_transition_bin_idx /= -1 then
        v_bin_idx := priv_rand_transition_bin_idx;
      else
        -- Assign each bin a randomization weight
        for i in 0 to priv_bins_idx-1 loop
          v_bin_weight_list(i).value := i;
          if priv_bins(i).hits < priv_bins(i).min_hits then
            v_bin_weight_list(i).weight := priv_bins(i).rand_weight;
          else
            v_bin_weight_list(i).weight := 0;
          end if;
          v_acc_weight := v_acc_weight + v_bin_weight_list(i).weight;
        end loop;
        -- When all bins have reached their min_hits re-enable valid bins for selection
        if v_acc_weight = 0 then
          for i in 0 to priv_bins_idx-1 loop
            v_bin_weight_list(i).weight := priv_bins(i).rand_weight;
          end loop;
        end if;

        -- Choose a random bin index
        v_bin_idx := priv_rand_gen.rand_val_weight(v_bin_weight_list, msg_id_panel);
      end if;

      -- Select the random bin values to return (ignore and illegal bin values are never selected)
      for i in 0 to priv_num_bins_crossed-1 loop
        v_values_vec := (others => 0);
        if priv_bins(v_bin_idx).cross_bins(i).contains = VAL then
          if priv_bins(v_bin_idx).cross_bins(i).num_values = 1 then
            v_ret(i) := priv_bins(v_bin_idx).cross_bins(i).values(0);
          else
            for j in 0 to priv_bins(v_bin_idx).cross_bins(i).num_values-1 loop
              v_values_vec(j) := priv_bins(v_bin_idx).cross_bins(i).values(j);
            end loop;
            v_ret(i) := priv_rand_gen.rand(ONLY, v_values_vec(0 to priv_bins(v_bin_idx).cross_bins(i).num_values-1), NON_CYCLIC, msg_id_panel);
          end if;
        elsif priv_bins(v_bin_idx).cross_bins(i).contains = RAN then
          v_ret(i) := priv_rand_gen.rand(priv_bins(v_bin_idx).cross_bins(i).values(0), priv_bins(v_bin_idx).cross_bins(i).values(1), NON_CYCLIC, msg_id_panel);
        elsif priv_bins(v_bin_idx).cross_bins(i).contains = TRN then
          if priv_rand_transition_bin_idx = -1 then
            v_ret(i) := priv_bins(v_bin_idx).cross_bins(i).values(0);
            priv_rand_transition_bin_idx       := v_bin_idx;
            priv_rand_transition_bin_value_idx := 1;
          else
            v_ret(i) := priv_bins(priv_rand_transition_bin_idx).cross_bins(i).values(priv_rand_transition_bin_value_idx);
            if priv_rand_transition_bin_value_idx < priv_bins(priv_rand_transition_bin_idx).cross_bins(i).num_values-1 then
              priv_rand_transition_bin_value_idx := priv_rand_transition_bin_value_idx + 1;
            else
              priv_rand_transition_bin_idx       := -1;
              priv_rand_transition_bin_value_idx := 0;
            end if;
          end if;
        else
          alert(TB_FAILURE, C_LOCAL_CALL & "=> Failed. Unexpected error, bin contains " & to_upper(to_string(priv_bins(v_bin_idx).cross_bins(i).contains)), priv_scope.all);
        end if;
      end loop;

      -- Do not print log message when being called from another function
      if ext_proc_call = "" then
        log(ID_FUNCT_COV, C_LOCAL_CALL & "=> " & to_string(v_ret), priv_scope.all, msg_id_panel);
      end if;
      return v_ret;
    end function;

    ------------------------------------------------------------
    -- Coverage
    ------------------------------------------------------------
    procedure sample_coverage(
      constant value         : in integer;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel) is
      constant C_LOCAL_CALL  : string := "sample_coverage(" & to_string(value) & ")";
      variable v_values      : integer_vector(0 to 0) := (0 => value);
    begin
      sample_coverage(v_values, msg_id_panel, C_LOCAL_CALL);
    end procedure;

    procedure sample_coverage(
      constant values        : in integer_vector;
      constant msg_id_panel  : in t_msg_id_panel := shared_msg_id_panel;
      constant ext_proc_call : in string         := "") is
      constant C_LOCAL_CALL        : string := "sample_coverage(" & to_string(values) & ")";
      variable v_proc_call         : line;
      variable v_invalid_sample    : boolean := false;
      variable v_value_match       : std_logic_vector(0 to priv_num_bins_crossed-1) := (others => '0');
      variable v_illegal_match_idx : integer := -1;
    begin
      create_proc_call(C_LOCAL_CALL, ext_proc_call, v_proc_call);
      log(ID_FUNCT_COV, v_proc_call.all, priv_scope.all, msg_id_panel);

      if priv_num_bins_crossed = -1 then
        alert(TB_FAILURE, v_proc_call.all & "=> Failed. Coverage point has not been initialized", priv_scope.all);
      elsif priv_num_bins_crossed /= values'length then
        alert(TB_FAILURE, v_proc_call.all & "=> Failed. Number of values does not match the number of crossed bins", priv_scope.all);
      end if;

      -- Check if the values should be ignored or are illegal
      l_bin_loop : for i in 0 to priv_invalid_bins_idx-1 loop
        for j in 0 to priv_num_bins_crossed-1 loop
          case priv_invalid_bins(i).cross_bins(j).contains is
            when VAL | VAL_IGNORE | VAL_ILLEGAL =>
              for k in 0 to priv_invalid_bins(i).cross_bins(j).num_values-1 loop
                if values(j) = priv_invalid_bins(i).cross_bins(j).values(k) then
                  v_value_match(j)    := '1';
                  v_illegal_match_idx := j when priv_invalid_bins(i).cross_bins(j).contains = VAL_ILLEGAL;
                end if;
              end loop;
            when RAN | RAN_IGNORE | RAN_ILLEGAL =>
              if values(j) >= priv_invalid_bins(i).cross_bins(j).values(0) and values(j) <= priv_invalid_bins(i).cross_bins(j).values(1) then
                v_value_match(j)    := '1';
                v_illegal_match_idx := j when priv_invalid_bins(i).cross_bins(j).contains = RAN_ILLEGAL;
              end if;
            when TRN | TRN_IGNORE | TRN_ILLEGAL =>
              if values(j) = priv_invalid_bins(i).cross_bins(j).values(priv_invalid_bins(i).cross_bins(j).transition_idx) then
                if priv_invalid_bins(i).cross_bins(j).transition_idx < priv_invalid_bins(i).cross_bins(j).num_values-1 then
                  priv_invalid_bins(i).cross_bins(j).transition_idx := priv_invalid_bins(i).cross_bins(j).transition_idx + 1;
                else
                  priv_invalid_bins(i).cross_bins(j).transition_idx := 0;
                  v_value_match(j)    := '1';
                  v_illegal_match_idx := j when priv_invalid_bins(i).cross_bins(j).contains = TRN_ILLEGAL;
                end if;
              else
                priv_invalid_bins(i).cross_bins(j).transition_idx := 0;
              end if;
            when others =>
              alert(TB_FAILURE, v_proc_call.all & "=> Failed. Unexpected error, invalid bin contains " & to_upper(to_string(priv_invalid_bins(i).cross_bins(j).contains)), priv_scope.all);
          end case;
        end loop;

        if and(v_value_match) = '1' then
          v_invalid_sample := true;
          priv_invalid_bins(i).hits := priv_invalid_bins(i).hits + 1;
          if v_illegal_match_idx /= -1 then
            alert(TB_WARNING, v_proc_call.all & "=> Sampled " & get_bin_info(priv_invalid_bins(i).cross_bins(v_illegal_match_idx)), priv_scope.all);
            exit l_bin_loop;
          end if;
        end if;
        v_value_match       := (others => '0');
        v_illegal_match_idx := -1;
      end loop;

      -- Check if the values are in the valid bins
      if not(v_invalid_sample) then
        for i in 0 to priv_bins_idx-1 loop
          for j in 0 to priv_num_bins_crossed-1 loop
            case priv_bins(i).cross_bins(j).contains is
              when VAL =>
                for k in 0 to priv_bins(i).cross_bins(j).num_values-1 loop
                  if values(j) = priv_bins(i).cross_bins(j).values(k) then
                    v_value_match(j) := '1';
                  end if;
                end loop;
              when RAN =>
                if values(j) >= priv_bins(i).cross_bins(j).values(0) and values(j) <= priv_bins(i).cross_bins(j).values(1) then
                  v_value_match(j) := '1';
                end if;
              when TRN =>
                if values(j) = priv_bins(i).cross_bins(j).values(priv_bins(i).cross_bins(j).transition_idx) then
                  if priv_bins(i).cross_bins(j).transition_idx < priv_bins(i).cross_bins(j).num_values-1 then
                    priv_bins(i).cross_bins(j).transition_idx := priv_bins(i).cross_bins(j).transition_idx + 1;
                  else
                    priv_bins(i).cross_bins(j).transition_idx := 0;
                    v_value_match(j) := '1';
                  end if;
                else
                  priv_bins(i).cross_bins(j).transition_idx := 0;
                end if;
              when others =>
                alert(TB_FAILURE, v_proc_call.all & "=> Failed. Unexpected error, valid bin contains " & to_upper(to_string(priv_bins(i).cross_bins(j).contains)), priv_scope.all);
            end case;
          end loop;

          if and(v_value_match) = '1' then
            priv_bins(i).hits := priv_bins(i).hits + 1;
          end if;
          v_value_match := (others => '0');
        end loop;
      end if;
    end procedure;

    --Q: is_covered/covered/coverage_complete
    impure function coverage_complete(
      constant VOID : t_void)
    return boolean is
      variable v_cov_complete : boolean := true;
    begin
      for i in 0 to priv_bins_idx-1 loop
        if priv_bins(i).hits < priv_bins(i).min_hits then
          v_cov_complete := false;
          exit;
        end if;
      end loop;
      return v_cov_complete;
    end function;

    --Q: always write to log and file? do like log and have a generic name and possible to modify?
    procedure print_summary(
      constant VOID : in t_void) is
      constant C_PREFIX           : string := C_LOG_PREFIX & "     ";
      constant C_HEADER           : string := "*** FUNCTIONAL COVERAGE SUMMARY: " & to_string(priv_scope.all) & " ***";
      constant C_BIN_COLUMN_WIDTH : positive := 40; --Q: how to handle when bins overflow the column? trucante and "..."? currently shifts everything
      constant C_COLUMN_WIDTH     : positive := 15;
      variable v_line             : line;
      variable v_line_copy        : line;
      variable v_log_extra_space  : integer := 0;

      impure function get_bin_status(cov_bin : t_cov_bin) return string is
      begin
        if is_bin_illegal(cov_bin) then
          return "ILLEGAL";
        elsif is_bin_ignore(cov_bin) then
          return "IGNORE";
        else
          if cov_bin.hits >= cov_bin.min_hits then
            return "COVERED";
          else
            return "UNCOVERED";
          end if;
        end if;
      end function;

    begin
      -- Calculate how much space we can insert between the columns of the report
      v_log_extra_space := (C_LOG_LINE_WIDTH - C_PREFIX'length - C_BIN_COLUMN_WIDTH - C_COLUMN_WIDTH*5 - C_MAX_BIN_NAME_LENGTH - 20)/6;
      if v_log_extra_space < 1 then
        alert(TB_WARNING, "C_LOG_LINE_WIDTH is too small or C_MAX_BIN_NAME_LENGTH is too big, the report will not be properly aligned.", priv_scope.all);
        v_log_extra_space := 1;
      end if;

      -- Print report header
      write(v_line, LF & fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF &
                    timestamp_header(now, justify(C_HEADER, LEFT, C_LOG_LINE_WIDTH - C_PREFIX'length, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE)) & LF &
                    "Coverpoint:     " & priv_name.all & LF &
                    "Uncovered bins: " & to_string(priv_bins_idx-get_num_covered_bins(VOID)) & "(" & to_string(priv_bins_idx) & ")" & LF &
                    "Illegal bins:   " & to_string(get_num_illegal_bins(VOID)) & LF &
                    "Coverage:       " & to_string(get_covpoint_coverage(VOID),2) & "% (accumulated: " & to_string(get_covpoint_coverage_accumulated(VOID),2) & "%)" & LF &
                    fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF);

      -- Print column headers
      write(v_line, justify(
        fill_string(' ', 5) &
        justify("BINS"       , center, C_BIN_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("HITS"       , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("MIN_HITS"   , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("COVERAGE"   , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("RAND_WEIGHT", center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("NAME"       , center, C_MAX_BIN_NAME_LENGTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
        justify("STATUS"     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
        left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);

      -- Print illegal bins
      for i in 0 to priv_invalid_bins_idx-1 loop
        if is_bin_illegal(priv_invalid_bins(i)) then
          write(v_line, justify(
            fill_string(' ', 5) &
            justify(get_bin_vector_values(priv_invalid_bins(i).cross_bins(0 to priv_num_bins_crossed-1)), center, C_BIN_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).hits)                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).min_hits)                 , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(get_bin_coverage(priv_invalid_bins(i)),2) & "%", center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).rand_weight)              , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).name)                     , center, C_MAX_BIN_NAME_LENGTH, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(get_bin_status(priv_invalid_bins(i))                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
            left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);
        end if;
      end loop;

      -- Print ignore bins
      for i in 0 to priv_invalid_bins_idx-1 loop
        if is_bin_ignore(priv_invalid_bins(i)) then
          write(v_line, justify(
            fill_string(' ', 5) &
            justify(get_bin_vector_values(priv_invalid_bins(i).cross_bins(0 to priv_num_bins_crossed-1)), center, C_BIN_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).hits)                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).min_hits)                 , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(get_bin_coverage(priv_invalid_bins(i)),2) & "%", center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).rand_weight)              , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_invalid_bins(i).name)                     , center, C_MAX_BIN_NAME_LENGTH, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(get_bin_status(priv_invalid_bins(i))                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
            left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);
        end if;
      end loop;

      -- Print uncovered bins
      for i in 0 to priv_bins_idx-1 loop
        if priv_bins(i).hits < priv_bins(i).min_hits then
          write(v_line, justify(
            fill_string(' ', 5) &
            justify(get_bin_vector_values(priv_bins(i).cross_bins(0 to priv_num_bins_crossed-1)), center, C_BIN_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).hits)                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).min_hits)                 , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(get_bin_coverage(priv_bins(i)),2) & "%", center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).rand_weight)              , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).name)                     , center, C_MAX_BIN_NAME_LENGTH, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(get_bin_status(priv_bins(i))                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
            left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);
        end if;
      end loop;

      -- Print covered bins
      for i in 0 to priv_bins_idx-1 loop
        if priv_bins(i).hits >= priv_bins(i).min_hits then
          write(v_line, justify(
            fill_string(' ', 5) &
            justify(get_bin_vector_values(priv_bins(i).cross_bins(0 to priv_num_bins_crossed-1)), center, C_BIN_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).hits)                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).min_hits)                 , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(get_bin_coverage(priv_bins(i)),2) & "%", center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).rand_weight)              , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(to_string(priv_bins(i).name)                     , center, C_MAX_BIN_NAME_LENGTH, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space) &
            justify(get_bin_status(priv_bins(i))                     , center, C_COLUMN_WIDTH, SKIP_LEADING_SPACE, DISALLOW_TRUNCATE) & fill_string(' ', v_log_extra_space),
            left, C_LOG_LINE_WIDTH - C_PREFIX'length, KEEP_LEADING_SPACE, DISALLOW_TRUNCATE) & LF);
        end if;
      end loop;

      -- Print report bottom line
      write(v_line, fill_string('=', (C_LOG_LINE_WIDTH - C_PREFIX'length)) & LF & LF);
      wrap_lines(v_line, 1, 1, C_LOG_LINE_WIDTH-C_PREFIX'length);
      prefix_lines(v_line, C_PREFIX);

      -- Write the info string to transcript
      write (v_line_copy, v_line.all);  -- copy line
      writeline(OUTPUT, v_line);
      writeline(LOG_FILE, v_line_copy);
      deallocate(v_line);
      deallocate(v_line_copy);
    end procedure;

  end protected body t_cov_point;

end package body funct_cov_pkg;