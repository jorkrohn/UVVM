--================================================================================================================================
-- Copyright 2020 Bitvis and Inventas AS
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

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_scoreboard;
use bitvis_vip_scoreboard.generic_sb_support_pkg.all;
use bitvis_vip_scoreboard.slv_sb_pkg.all;

use work.sbi_bfm_pkg.all;
use work.vvc_cmd_pkg.all;
use work.td_target_support_pkg.all;
use work.transaction_pkg.all;


--=================================================================================================
--=================================================================================================
--=================================================================================================
package vvc_methods_pkg is

  --===============================================================================================
  -- Types and constants for the SBI VVC
  --===============================================================================================
  constant C_VVC_NAME     : string := "SBI_VVC";

  signal SBI_VVCT          : t_vvc_target_record := set_vvc_target_defaults(C_VVC_NAME);
  alias  THIS_VVCT         : t_vvc_target_record is SBI_VVCT;
  alias  t_bfm_config is t_sbi_bfm_config;

  -- Type found in UVVM-Util types_pkg
  constant C_SBI_INTER_BFM_DELAY_DEFAULT : t_inter_bfm_delay := (
    delay_type                          => NO_DELAY,
    delay_in_time                       => 0 ns,
    inter_bfm_delay_violation_severity  => WARNING
  );

  type t_vvc_config is
  record
    inter_bfm_delay                       : t_inter_bfm_delay;-- Minimum delay between BFM accesses from the VVC. If parameter delay_type is set to NO_DELAY, BFM accesses will be back to back, i.e. no delay.
    cmd_queue_count_max                   : natural;          -- Maximum pending number in command queue before queue is full. Adding additional commands will result in an ERROR.
    cmd_queue_count_threshold             : natural;          -- An alert with severity 'cmd_queue_count_threshold_severity' will be issued if command queue exceeds this count. Used for early warning if command queue is almost full. Will be ignored if set to 0.
    cmd_queue_count_threshold_severity    : t_alert_level;    -- Severity of alert to be initiated if exceeding cmd_queue_count_threshold
    result_queue_count_max                : natural;
    result_queue_count_threshold_severity : t_alert_level;
    result_queue_count_threshold          : natural;
    bfm_config                            : t_sbi_bfm_config; -- Configuration for the BFM. See BFM quick reference
    msg_id_panel                          : t_msg_id_panel;   -- VVC dedicated message ID panel
  end record;

  type t_vvc_config_array is array (natural range <>) of t_vvc_config;
  type t_vvc_config_full_array is array (t_channel range <>) of t_vvc_config_array;

  constant C_SBI_VVC_CONFIG_DEFAULT : t_vvc_config := (
    inter_bfm_delay                       => C_SBI_INTER_BFM_DELAY_DEFAULT,
    cmd_queue_count_max                   => C_CMD_QUEUE_COUNT_MAX, --  from adaptation package
    cmd_queue_count_threshold             => C_CMD_QUEUE_COUNT_THRESHOLD,
    cmd_queue_count_threshold_severity    => C_CMD_QUEUE_COUNT_THRESHOLD_SEVERITY,
    result_queue_count_max                => C_RESULT_QUEUE_COUNT_MAX,
    result_queue_count_threshold_severity => C_RESULT_QUEUE_COUNT_THRESHOLD_SEVERITY,
    result_queue_count_threshold          => C_RESULT_QUEUE_COUNT_THRESHOLD,
    bfm_config                            => C_SBI_BFM_CONFIG_DEFAULT,
    msg_id_panel                          => C_VVC_MSG_ID_PANEL_DEFAULT
    );

  type t_vvc_status is
  record
    current_cmd_idx       : natural;
    previous_cmd_idx      : natural;
    pending_cmd_cnt       : natural;
  end record;

  type t_vvc_status_array is array (natural range <>) of t_vvc_status;

  constant C_VVC_STATUS_DEFAULT : t_vvc_status := (
    current_cmd_idx      => 0,
    previous_cmd_idx     => 0,
    pending_cmd_cnt      => 0
  );

  -- Transaction information to include in the wave view during simulation
  type t_transaction_info is
  record
    operation       : t_operation;
    addr            : unsigned(C_VVC_CMD_ADDR_MAX_LENGTH-1 downto 0);
    data            : std_logic_vector(C_VVC_CMD_DATA_MAX_LENGTH-1 downto 0);
    msg             : string(1 to C_VVC_CMD_STRING_MAX_LENGTH);
  end record;

  type t_transaction_info_array is array (natural range <>) of t_transaction_info;

  constant C_TRANSACTION_INFO_DEFAULT : t_transaction_info := (
    operation           =>  NO_OPERATION,
    addr                => (others => '0'),
    data                => (others => '0'),
    msg                 => (others => ' ')
  );


  shared variable shared_sbi_vvc_config : t_vvc_config_array(0 to C_MAX_VVC_INSTANCE_NUM-1)             := (others => C_SBI_VVC_CONFIG_DEFAULT);
  shared variable shared_sbi_vvc_status : t_vvc_status_array(0 to C_MAX_VVC_INSTANCE_NUM-1)             := (others => C_VVC_STATUS_DEFAULT);
  shared variable shared_sbi_transaction_info : t_transaction_info_array(0 to C_MAX_VVC_INSTANCE_NUM-1) := (others => C_TRANSACTION_INFO_DEFAULT);

  -- Scoreboard
  shared variable shared_sbi_sb : t_generic_sb;

  --==========================================================================================
  -- Methods dedicated to this VVC
  -- - These procedures are called from the testbench in order for the VVC to execute
  --   BFM calls towards the given interface. The VVC interpreter will queue these calls
  --   and then the VVC executor will fetch the commands from the queue and handle the
  --   actual BFM execution.
  --   For details on how the BFM procedures work, see the QuickRef.
  --==========================================================================================

  procedure sbi_write(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  );


  procedure sbi_write(
    signal   VVCT               : inout t_vvc_target_record;
    constant vvc_instance_idx   : in integer;
    constant addr               : in unsigned;
    constant num_words          : in natural;
    constant randomisation      : in t_randomisation;
    constant msg                : in string;
    constant scope              : in string := C_TB_SCOPE_DEFAULT & "(uvvm)"
  );

  procedure sbi_read(
    signal   VVCT                       : inout t_vvc_target_record;
    constant vvc_instance_idx           : in    integer;
    constant addr                       : in    unsigned;
    constant msg                        : in    string;
    constant data_routing               : in    t_data_routing              := TO_RECEIVE_BUFFER;
    constant scope                      : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel  : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel               : in    t_msg_id_panel              := shared_msg_id_panel
  );

  procedure sbi_read(
    signal VVCT               : inout t_vvc_target_record;
    constant vvc_instance_idx : in    integer;
    constant addr             : in    unsigned;
    constant data_routing     : in    t_data_routing;
    constant msg              : in    string;
    constant scope            : in    string := C_TB_SCOPE_DEFAULT & "(uvvm)"
    );

  procedure sbi_check(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant alert_level               : in    t_alert_level               := ERROR;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  );

  procedure sbi_poll_until(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant max_polls                 : in    integer                     := 100;
    constant timeout                   : in    time                        := 1 us;  -- To assure a given timeout
    constant alert_level               : in    t_alert_level               := ERROR;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  );


  --==============================================================================
  -- Direct Transaction Transfer methods
  --==============================================================================
  procedure set_global_dtt(
    signal dtt_trigger    : inout std_logic;
    variable dtt_group    : inout t_transaction_group;
    constant vvc_cmd      : in t_vvc_cmd_record;
    constant vvc_config   : in t_vvc_config;
    constant scope        : in string := C_VVC_CMD_SCOPE_DEFAULT);


  procedure reset_dtt_info(
    variable dtt_group    : inout t_transaction_group;
    constant vvc_cmd      : in t_vvc_cmd_record);


  --==============================================================================
  -- Activity Watchdog
  --==============================================================================
  procedure activity_watchdog_register_vvc_state( signal global_trigger_activity_watchdog : inout std_logic;
                                                  constant busy                           : in    boolean;
                                                  constant vvc_idx_for_activity_watchdog  : in    integer;
                                                  constant last_cmd_idx_executed          : in    natural;
                                                  constant scope                          : in    string := "SBI_VVC");


  --==============================================================================
  -- Hierarchical VVC SB
  --==============================================================================
  function to_sb_result(
    constant data : in std_logic_vector
  ) return t_vvc_result;


end package vvc_methods_pkg;

package body vvc_methods_pkg is



  --==============================================================================
  -- Methods dedicated to this VVC
  -- Notes:
  --   - shared_vvc_cmd is initialised to C_VVC_CMD_DEFAULT, and also reset to this after every command
  --==============================================================================

  procedure sbi_write(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
        & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ", " & to_string(data, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_normalised_addr    : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
        normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
    variable v_normalised_data    : std_logic_vector(shared_vvc_cmd.data'length-1 downto 0) :=
        normalize_and_check(data, shared_vvc_cmd.data, ALLOW_WIDER_NARROWER, "data", "shared_vvc_cmd.data", proc_call & " called with to wide data. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, WRITE);
    shared_vvc_cmd.operation                          := WRITE;
    shared_vvc_cmd.addr                               := v_normalised_addr;
    shared_vvc_cmd.data                               := v_normalised_data;
    shared_vvc_cmd.use_provided_msg_id_panel          := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel                       := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure;


  procedure sbi_write(
    signal   VVCT               : inout t_vvc_target_record;
    constant vvc_instance_idx   : in integer;
    constant addr               : in unsigned;
    constant num_words          : in natural;
    constant randomisation      : in t_randomisation;
    constant msg                : in string;
    constant scope              : in string := C_TB_SCOPE_DEFAULT & "(uvvm)"
  ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
        & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ", RANDOM)";
    variable v_normalised_addr    : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
        normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, WRITE);
    shared_vvc_cmd.operation                          := WRITE;
    shared_vvc_cmd.addr                               := v_normalised_addr;
    shared_vvc_cmd.randomisation                      := randomisation;
    shared_vvc_cmd.num_words                          := num_words;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure;


  procedure sbi_read(
    signal   VVCT                       : inout t_vvc_target_record;
    constant vvc_instance_idx           : in    integer;
    constant addr                       : in    unsigned;
    constant msg                        : in    string;
    constant data_routing               : in    t_data_routing              := TO_RECEIVE_BUFFER;
    constant scope                      : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel  : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel               : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
        & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_normalised_addr    : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
        normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, READ);
    shared_vvc_cmd.addr                       := v_normalised_addr;
    shared_vvc_cmd.data_routing               := data_routing;
    shared_vvc_cmd.use_provided_msg_id_panel  := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel               := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure;


  procedure sbi_read(
    signal VVCT               : inout t_vvc_target_record;
    constant vvc_instance_idx : in    integer;
    constant addr             : in    unsigned;
    constant data_routing     : in    t_data_routing;
    constant msg              : in    string;
    constant scope            : in    string := C_TB_SCOPE_DEFAULT & "(uvvm)"
    ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
                                   & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_normalised_addr : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
      normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, READ);
    shared_vvc_cmd.operation    := READ;
    shared_vvc_cmd.addr         := v_normalised_addr;
    shared_vvc_cmd.data_routing := data_routing;
    send_command_to_vvc(VVCT, scope => scope);
  end procedure;


  procedure sbi_check(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant alert_level               : in    t_alert_level               := ERROR;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
        & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ", " & to_string(data, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_normalised_addr    : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
        normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
    variable v_normalised_data    : std_logic_vector(shared_vvc_cmd.data'length-1 downto 0) :=
        normalize_and_check(data, shared_vvc_cmd.data, ALLOW_WIDER_NARROWER, "data", "shared_vvc_cmd.data", proc_call & " called with to wide data. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, CHECK);
    shared_vvc_cmd.addr                      := v_normalised_addr;
    shared_vvc_cmd.data                      := v_normalised_data;
    shared_vvc_cmd.alert_level               := alert_level;
    shared_vvc_cmd.use_provided_msg_id_panel := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel              := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure;


  procedure sbi_poll_until(
    signal   VVCT                      : inout t_vvc_target_record;
    constant vvc_instance_idx          : in    integer;
    constant addr                      : in    unsigned;
    constant data                      : in    std_logic_vector;
    constant msg                       : in    string;
    constant max_polls                 : in    integer                     := 100;
    constant timeout                   : in    time                        := 1 us;
    constant alert_level               : in    t_alert_level               := ERROR;
    constant scope                     : in    string                      := C_VVC_CMD_SCOPE_DEFAULT;
    constant use_provided_msg_id_panel : in    t_use_provided_msg_id_panel := DO_NOT_USE_PROVIDED_MSG_ID_PANEL;
    constant msg_id_panel              : in    t_msg_id_panel              := shared_msg_id_panel
  ) is
    constant proc_name : string := get_procedure_name_from_instance_name(vvc_instance_idx'instance_name);
    constant proc_call : string := proc_name & "(" & to_string(VVCT, vvc_instance_idx)  -- First part common for all
        & ", " & to_string(addr, HEX, AS_IS, INCL_RADIX) & ", " & to_string(data, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_normalised_addr    : unsigned(shared_vvc_cmd.addr'length-1 downto 0) :=
        normalize_and_check(addr, shared_vvc_cmd.addr, ALLOW_WIDER_NARROWER, "addr", "shared_vvc_cmd.addr", proc_call & " called with to wide address. " & add_msg_delimiter(msg));
    variable v_normalised_data    : std_logic_vector(shared_vvc_cmd.data'length-1 downto 0) :=
        normalize_and_check(data, shared_vvc_cmd.data, ALLOW_WIDER_NARROWER, "data", "shared_vvc_cmd.data", proc_call & " called with to wide data. " & add_msg_delimiter(msg));
  begin
    -- Create command by setting common global 'VVCT' signal record and dedicated VVC 'shared_vvc_cmd' record
    -- locking semaphore in set_general_target_and_command_fields to gain exclusive right to VVCT and shared_vvc_cmd
    -- semaphore gets unlocked in await_cmd_from_sequencer of the targeted VVC
    set_general_target_and_command_fields(VVCT, vvc_instance_idx, proc_call, msg, QUEUED, POLL_UNTIL);
    shared_vvc_cmd.addr                      := v_normalised_addr;
    shared_vvc_cmd.data                      := v_normalised_data;
    shared_vvc_cmd.max_polls                 := max_polls;
    shared_vvc_cmd.timeout                   := timeout;
    shared_vvc_cmd.alert_level               := alert_level;
    shared_vvc_cmd.use_provided_msg_id_panel := use_provided_msg_id_panel;
    shared_vvc_cmd.msg_id_panel              := msg_id_panel;
    send_command_to_vvc(VVCT, std.env.resolution_limit, scope, msg_id_panel);
  end procedure;

  function to_sb_result(
    constant data : in std_logic_vector
  ) return t_vvc_result is
    variable v_vvc_result : t_vvc_result := (others => '-');
  begin
    v_vvc_result(data'length-1 downto 0) := data;
    return v_vvc_result;
  end function to_sb_result;


  --==============================================================================
  -- DTT procedures
  --==============================================================================
  procedure set_global_dtt(
    signal dtt_trigger    : inout std_logic;
    variable dtt_group    : inout t_transaction_group;
    constant vvc_cmd      : in t_vvc_cmd_record;
    constant vvc_config   : in t_vvc_config;
    constant scope        : in string := C_VVC_CMD_SCOPE_DEFAULT) is
  begin
    case vvc_cmd.operation is
      when WRITE | READ | CHECK =>
        dtt_group.bt.operation                                  := vvc_cmd.operation;
        dtt_group.bt.address(vvc_cmd.addr'length-1 downto 0)    := vvc_cmd.addr;
        dtt_group.bt.data(vvc_cmd.data'length-1 downto 0)       := vvc_cmd.data;
        dtt_group.bt.randomisation                              := vvc_cmd.randomisation;
        dtt_group.bt.num_words                                  := vvc_cmd.num_words;
        dtt_group.bt.vvc_meta.msg(1 to vvc_cmd.msg'length)      := vvc_cmd.msg;
        dtt_group.bt.vvc_meta.cmd_idx                           := vvc_cmd.cmd_idx;
        dtt_group.bt.transaction_status                         := IN_PROGRESS;
        gen_pulse(dtt_trigger, 0 ns, "pulsing global DTT trigger", scope, ID_NEVER);

      when POLL_UNTIL =>
        dtt_group.ct.operation                                  := vvc_cmd.operation;
        dtt_group.ct.address(vvc_cmd.addr'length-1 downto 0)    := vvc_cmd.addr;
        dtt_group.ct.data(vvc_cmd.data'length-1 downto 0)       := vvc_cmd.data;
        dtt_group.bt.randomisation                              := vvc_cmd.randomisation;
        dtt_group.bt.num_words                                  := vvc_cmd.num_words;
        dtt_group.bt.max_polls                                  := vvc_cmd.max_polls;
        dtt_group.ct.vvc_meta.msg(1 to vvc_cmd.msg'length)      := vvc_cmd.msg;
        dtt_group.ct.vvc_meta.cmd_idx                           := vvc_cmd.cmd_idx;
        dtt_group.ct.transaction_status                         := IN_PROGRESS;
        gen_pulse(dtt_trigger, 0 ns, "pulsing global DTT trigger", scope, ID_NEVER);

      when others =>
        alert(TB_ERROR, "VVC operation not recognized");
    end case;

    wait for 0 ns;
  end procedure set_global_dtt;


  procedure reset_dtt_info(
    variable dtt_group    : inout t_transaction_group;
    constant vvc_cmd      : in t_vvc_cmd_record) is
  begin
    case vvc_cmd.operation is
      when WRITE | READ | CHECK =>
        dtt_group.bt := C_TRANSACTION_SET_DEFAULT;

      when POLL_UNTIL =>
        dtt_group.ct := C_TRANSACTION_SET_DEFAULT;

      when others =>
        null;
    end case;

    wait for 0 ns;
  end procedure reset_dtt_info;


  --==============================================================================
  -- Activity Watchdog
  --==============================================================================
  procedure activity_watchdog_register_vvc_state( signal global_trigger_activity_watchdog : inout std_logic;
                                                  constant busy                           : in    boolean;
                                                  constant vvc_idx_for_activity_watchdog  : in    integer;
                                                  constant last_cmd_idx_executed          : in    natural;
                                                  constant scope                          : in    string := "SBI_VVC") is
  begin
    shared_activity_watchdog.priv_report_vvc_activity(vvc_idx               => vvc_idx_for_activity_watchdog,
                                                      busy                  => busy,
                                                      last_cmd_idx_executed => last_cmd_idx_executed);
    gen_pulse(global_trigger_activity_watchdog, 0 ns, "pulsing global trigger for activity watchdog", scope, ID_NEVER);
  end procedure;


end package body vvc_methods_pkg;


