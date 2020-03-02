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

---------------------------------------------------------------------------------------------
-- Description : See library quick reference (under 'doc') and README-file(s)
---------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library uvvm_vvc_framework;
use uvvm_vvc_framework.ti_vvc_framework_support_pkg.all;

library bitvis_vip_gmii;
context bitvis_vip_gmii.vvc_context;

library bitvis_vip_sbi;
context bitvis_vip_sbi.vvc_context;

entity hvvc_to_vvc_bridge is
  generic(
    GC_INTERFACE           : t_interface;
    GC_INSTANCE_IDX        : integer;
    GC_DUT_IF_FIELD_CONFIG : t_dut_if_field_config_direction_array;
    GC_MAX_NUM_BYTES       : positive;
    GC_PHY_MAX_ACCESS_TIME : time;
    GC_SCOPE               : string
  );
  port(
    hvvc_to_bridge : in  t_hvvc_to_bridge(data_bytes(0 to GC_MAX_NUM_BYTES-1));
    bridge_to_hvvc : out t_bridge_to_hvvc(data_bytes(0 to GC_MAX_NUM_BYTES-1))
  );
end entity hvvc_to_vvc_bridge;

architecture func of hvvc_to_vvc_bridge is
  constant C_UNSUPPORTED_OPERATION   : string         := "Unsupported operation";
  constant C_UNSUPPORTED_INTERFACE   : string         := "Unsupported interface";
  constant C_INTERFACE_CONFIG_LENGTH : positive       := GC_DUT_IF_FIELD_CONFIG(GC_DUT_IF_FIELD_CONFIG'low)'length;
begin

  p_executor : process
    variable v_cmd_idx                    : integer;
    variable v_gmii_received_data         : bitvis_vip_gmii.vvc_cmd_pkg.t_vvc_result;
    variable v_sbi_received_data          : bitvis_vip_sbi.vvc_cmd_pkg.t_vvc_result;
    variable v_sbi_send_data              : std_logic_vector(bitvis_vip_sbi.transaction_pkg.C_VVC_CMD_DATA_MAX_LENGTH-1 downto 0);
    variable v_direction                  : t_direction;
    variable v_interface_config_idx       : natural := 0;
    variable v_dut_address                : unsigned(GC_DUT_IF_FIELD_CONFIG(GC_DUT_IF_FIELD_CONFIG'low)(GC_DUT_IF_FIELD_CONFIG(GC_DUT_IF_FIELD_CONFIG'low)'high).dut_address'range);
    variable v_dut_address_increment      : integer;
    variable v_num_of_transfers           : integer;
    variable v_byte_idx                   : natural range 0 to GC_MAX_NUM_BYTES;
    variable v_bit_idx                    : natural range 0 to 7;
    variable v_data_width                 : positive;
  begin

    loop

      -- Await cmd
      wait until hvvc_to_bridge.trigger = true;

      if hvvc_to_bridge.operation = TRANSMIT then -- Expand if other operations
        v_direction := TRANSMIT;
      else
        v_direction := RECEIVE;
      end if;

      -- If not configs are defined for all fields the last config is used
      if hvvc_to_bridge.dut_if_field_idx > GC_DUT_IF_FIELD_CONFIG(v_direction)'high then
        -- Set address and address incrementation
        v_dut_address_increment := GC_DUT_IF_FIELD_CONFIG(v_direction)(GC_DUT_IF_FIELD_CONFIG(v_direction)'high).dut_address_increment;
        v_dut_address := GC_DUT_IF_FIELD_CONFIG(v_direction)(GC_DUT_IF_FIELD_CONFIG(v_direction)'high).dut_address +
            (hvvc_to_bridge.current_byte_idx_in_field*v_dut_address_increment);
        -- Set data width
        v_data_width := GC_DUT_IF_FIELD_CONFIG(v_direction)(GC_DUT_IF_FIELD_CONFIG(v_direction)'high).data_width;
      else
        -- Set address and address incrementation
        v_dut_address_increment := GC_DUT_IF_FIELD_CONFIG(v_direction)(hvvc_to_bridge.dut_if_field_idx).dut_address_increment;
        v_dut_address := GC_DUT_IF_FIELD_CONFIG(v_direction)(hvvc_to_bridge.dut_if_field_idx).dut_address +
            (hvvc_to_bridge.current_byte_idx_in_field*v_dut_address_increment);
        -- Set data width
        v_data_width := GC_DUT_IF_FIELD_CONFIG(v_direction)(hvvc_to_bridge.dut_if_field_idx).data_width;
      end if;

      -- Calculate number of transfers
      v_num_of_transfers := (hvvc_to_bridge.num_data_bytes*8)/v_data_width;
      -- Extra transfer if remainder
      if ((hvvc_to_bridge.num_data_bytes*8) rem v_data_width) /= 0 then
        v_num_of_transfers := v_num_of_transfers+1;
      end if;

      -- Execute command
      case GC_INTERFACE is

        -------------------------------------
        -- GMII
        -------------------------------------
        when GMII =>

          case hvvc_to_bridge.operation is

            when TRANSMIT =>
              --gmii_write(GMII_VVCT, GC_INSTANCE_IDX, TX, hvvc_to_bridge.data_bytes(0 to hvvc_to_bridge.num_data_bytes-1), "Send data over GMII", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
              gmii_write(GMII_VVCT, GC_INSTANCE_IDX, TX, hvvc_to_bridge.data_bytes(0 to hvvc_to_bridge.num_data_bytes-1), "Send data over GMII", GC_SCOPE);
              v_cmd_idx := get_last_received_cmd_idx(GMII_VVCT, GC_INSTANCE_IDX, TX, GC_SCOPE);
              await_completion(GMII_VVCT, GC_INSTANCE_IDX, TX, v_cmd_idx, v_num_of_transfers*GC_PHY_MAX_ACCESS_TIME + hvvc_to_bridge.field_timeout_margin,
                "Wait for write to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);

            when RECEIVE =>
              --gmii_read(GMII_VVCT, GC_INSTANCE_IDX, RX, hvvc_to_bridge.num_data_bytes, "Read data over GMII", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
              gmii_read(GMII_VVCT, GC_INSTANCE_IDX, RX, hvvc_to_bridge.num_data_bytes, "Read data over GMII", GC_SCOPE);
              v_cmd_idx := get_last_received_cmd_idx(GMII_VVCT, GC_INSTANCE_IDX, RX, GC_SCOPE);
              await_completion(GMII_VVCT, GC_INSTANCE_IDX, RX, v_cmd_idx, v_num_of_transfers*GC_PHY_MAX_ACCESS_TIME + hvvc_to_bridge.field_timeout_margin,
                "Wait for read to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
              fetch_result(GMII_VVCT, GC_INSTANCE_IDX, RX, v_cmd_idx, v_gmii_received_data, "Fetching received data.", TB_ERROR, GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
              bridge_to_hvvc.data_bytes(0 to hvvc_to_bridge.num_data_bytes-1) <= v_gmii_received_data.data_array(0 to hvvc_to_bridge.num_data_bytes-1);

            when others =>
              alert(TB_ERROR, C_UNSUPPORTED_OPERATION);

          end case;

        -------------------------------------
        -- SBI
        -------------------------------------
        when SBI =>

          case hvvc_to_bridge.operation is

            when TRANSMIT =>
              v_byte_idx := 0;
              v_bit_idx  := 0;
              -- Loop through transfers
              for i in 0 to v_num_of_transfers-1 loop
                -- Fill the data vector
                v_sbi_send_data := (others => '0');
                for send_data_idx in 0 to v_data_width-1 loop
                  if v_byte_idx = hvvc_to_bridge.num_data_bytes then
                    exit; -- No more data
                  else
                    v_sbi_send_data(send_data_idx) := hvvc_to_bridge.data_bytes(v_byte_idx)(v_bit_idx);
                  end if;

                  if v_bit_idx = 7 then
                    v_byte_idx := v_byte_idx+1;
                    v_bit_idx := 0;
                  else
                    v_bit_idx := v_bit_idx+1;
                  end if;
                end loop;

                -- Send data over SBI
                sbi_write(SBI_VVCT, GC_INSTANCE_IDX, v_dut_address, v_sbi_send_data(v_data_width-1 downto 0), "Send data over SBI", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                v_cmd_idx := get_last_received_cmd_idx(SBI_VVCT, GC_INSTANCE_IDX, NA, GC_SCOPE);
                if shared_sbi_vvc_config(GC_INSTANCE_IDX).bfm_config.use_ready_signal then
                  await_completion(SBI_VVCT, GC_INSTANCE_IDX, v_cmd_idx, GC_PHY_MAX_ACCESS_TIME*2 + hvvc_to_bridge.field_timeout_margin,
                    "Wait for write to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                else
                  await_completion(SBI_VVCT, GC_INSTANCE_IDX, v_cmd_idx, GC_PHY_MAX_ACCESS_TIME + hvvc_to_bridge.field_timeout_margin,
                    "Wait for write to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                end if;
                v_dut_address := v_dut_address + v_dut_address_increment;
              end loop;


            when RECEIVE =>
              v_byte_idx := 0;
              v_bit_idx  := 0;
              bridge_to_hvvc.data_bytes <= (others => (others => '0'));
              -- Loop through bytes
              for i in 0 to v_num_of_transfers-1 loop
                -- Read data over SBI
                sbi_read(SBI_VVCT, GC_INSTANCE_IDX, v_dut_address, "Read data over SBI", TO_RECEIVE_BUFFER, GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                v_cmd_idx := get_last_received_cmd_idx(SBI_VVCT, GC_INSTANCE_IDX, NA, GC_SCOPE);
                if shared_sbi_vvc_config(GC_INSTANCE_IDX).bfm_config.use_ready_signal then
                  await_completion(SBI_VVCT, GC_INSTANCE_IDX, v_cmd_idx, GC_PHY_MAX_ACCESS_TIME*2 + hvvc_to_bridge.field_timeout_margin,
                    "Wait for read to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                else
                  await_completion(SBI_VVCT, GC_INSTANCE_IDX, v_cmd_idx, GC_PHY_MAX_ACCESS_TIME + hvvc_to_bridge.field_timeout_margin,
                    "Wait for read to finish.", GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);
                end if;
                fetch_result(SBI_VVCT, GC_INSTANCE_IDX, v_cmd_idx, v_sbi_received_data, "Fetching received data.", TB_ERROR, GC_SCOPE, USE_PROVIDED_MSG_ID_PANEL, hvvc_to_bridge.msg_id_panel);

                -- Fill data bytes to HVVC
                for receive_data_idx in 0 to v_data_width-1 loop
                   if v_byte_idx = hvvc_to_bridge.num_data_bytes then
                    exit; -- No more data
                  else
                    bridge_to_hvvc.data_bytes(v_byte_idx)(v_bit_idx) <= v_sbi_received_data(receive_data_idx);
                  end if;

                  if v_bit_idx = 7 then
                    v_byte_idx := v_byte_idx+1;
                    v_bit_idx := 0;
                  else
                    v_bit_idx := v_bit_idx+1;
                  end if;
                end loop;
                v_dut_address := v_dut_address + v_dut_address_increment;
              end loop;


            when others =>
              alert(TB_ERROR, C_UNSUPPORTED_OPERATION);

          end case;

        when others =>
          alert(TB_ERROR, C_UNSUPPORTED_INTERFACE);

      end case;

      bridge_to_hvvc.trigger <= true;
      wait for 0 ns;
      bridge_to_hvvc.trigger <= false;

    end loop;

  end process;

end architecture func;