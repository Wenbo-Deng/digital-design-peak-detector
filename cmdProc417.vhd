package state_pack is
	type STATE_NAME is
		(  
		    INIT, 
			data_echoing_state,check_command_state,
			send_first_start,wait_data_ready,one_bit_first_hex_letter,one_bit_second_hex_letter,one_bit_space_hex,check_byte_num,
			peek_data_first_hex_letter,peek_data_second_hex_letter,peek_data_space_hex,peek_index,peek_index_min,check_peek_index_nums,
			list_data_first_hex_letter,list_data_second_hex_letter,list_data_space_hex,check_list_number,
			print_line_LF,print_line,print_end_LF,check_line_number,print_end_line_CR,print_line_CR,print_command_CR,print_command_LF,check_line_nums
		);
end state_pack;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
use ieee.std_logic_unsigned.all;
use work.state_pack.all;

entity cmdProc is
 port(
      clk:     in std_logic;
      reset:   in std_logic;
	  --rx section
      rxnow:   in std_logic;
      rxData:  in std_logic_vector (7 downto 0); --data in rx
      txData:  out std_logic_vector (7 downto 0);
      rxdone:  out std_logic; -- to tell rx that the command process has get data
      ovErr:   in std_logic;
      framErr: in std_logic;
	  --tx section
      txnow:   out std_logic;
      txdone:  in std_logic;
	  --command processor connect with data processor
      start:   out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
	  );
	end;
	
	architecture control_unit of cmdProc is
	   signal curState, nextState: STATE_NAME;
	   type ACSII_ARRAY_TYPE is array (integer range<>) of std_logic_vector(7 downto 0);
	   signal reg_ANNN_command: ACSII_ARRAY_TYPE(3 downto 0):= (others => "00000000");
	   signal tmp_seqDone: std_logic := '0';
	   signal tmp_data_result :CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1):= (others => "00000000");
	   signal tmp_max_Index: BCD_ARRAY_TYPE(2 downto 0):= (others =>"0000");
	   signal byte_counter : integer := 0;
	   signal peek_counter : integer := 3;
	   signal line_counter: integer :=0;
	   signal list_counter: integer:=0;
	   signal en_shift,en_number_words: std_logic := '0';
	   signal en_reset_seqDone: std_logic:= '0';
	   signal en_list_counter,en_reset_list_counter: std_logic := '0';
	   signal en_line_counter,en_reset_line_counter: std_logic := '0';
	   signal en_peek_counter,en_reset_peek_counter: std_logic := '0';
	   
	  
	function BCD_to_ascii(BCD_num :std_logic_vector(3 downto 0)) return std_logic_vector is 
	   --tansfer ascii to BCD
        variable result : std_logic_vector(7 downto 0);
      begin
        case BCD_num is
          when "0000" => result := "00110000"; --0
          when "0001" => result := "00110001"; --1
          when "0010" => result := "00110010"; --2
          when "0011" => result := "00110011"; --3
          when "0100" => result := "00110100"; --4
          when "0101" => result := "00110101"; --5
          when "0110" => result := "00110110"; --6
          when "0111" => result := "00110111"; --7
          when "1000" => result := "00111000"; --8
          when "1001" => result := "00111001"; --9
		  when "1010" => result := "01000001"; --A
		  when "1011" => result := "01000010"; --B
		  when "1100" => result := "01000011"; --C
		  when "1101" => result := "01000100"; --D
		  when "1110" => result := "01000101"; --E
		  when "1111" => result := "01000110"; --F
          when others => result := (others => 'X');
        end case;
        return result;
      end function;
	
	  begin
	  
	    stateReister: process(clk,reset)
         --to make sure the state is change on rising_edge(clk)
	    begin
		if rising_edge (clk) then
			if (reset = '1') then
				curState <= INIT;
			else
				curState <= nextState;
			end if;
		 end if;
	    end process;
		
		-- to record the data result and max index
		get_seqDone_signal: process(seqDone,reset,clk,en_reset_seqDone)
		 begin
		   if reset = '1' then
			  tmp_data_result <= (others => "00000000");
			  tmp_max_Index <=(others =>"0000");	
			elsif seqDone = '1'  and rising_edge(clk) then
			  tmp_data_result <= dataResults;
			  tmp_max_Index <= maxIndex;
			end if;
		  end process;
		  
		check_byte_num_process : process(seqDone,clk,en_reset_seqDone,reset)
		  begin
		    if reset = '1' or en_reset_seqDone = '1' then
			   tmp_seqDone <= '0';
			elsif seqDone = '1' and rising_edge(clk) then
			   tmp_seqDone <= '1';
			end if;
		  end process;
		 
        --shift the 4bit-reg_ANNN_command, and assign new value to zero bit		 
		shift_and_assign_new_value_to_reg: process(reset,en_shift,rxData,clk)
		   begin
		    if reset = '1' then
			  reg_ANNN_command <=(others =>"11111111");
			elsif en_shift = '1'  and rising_edge(clk) then
			  reg_ANNN_command <= reg_ANNN_command(2 downto 0) & "00000000";
			  reg_ANNN_command(0) <= rxData;
			end if;
		  end process;	

        number_Words_transfer: process(clk, en_number_words,reg_ANNN_command)
		variable tmp_numWords_bcd:BCD_ARRAY_TYPE(2 downto 0);
           begin
            if en_number_words = '1' and rising_edge(clk) then
               tmp_numWords_bcd(2):= reg_ANNN_command(2)(3 downto 0);
			   tmp_numWords_bcd(1):= reg_ANNN_command(1)(3 downto 0);
			   tmp_numWords_bcd(0):= reg_ANNN_command(0)(3 downto 0);
            end if;
			   numWords_bcd <= tmp_numWords_bcd;
           end process;			
		  
		  list_counter_mins: process(clk,reset,en_list_counter,en_reset_list_counter)
		  variable count: integer;
		    begin
			 if reset = '1' or en_reset_list_counter = '1' then 
              count:= 7;
			 elsif rising_edge(clk) and en_list_counter = '1' then
			   count:= count - 1;
             end if;
			 list_counter <= count;
			end process;
			
		  line_counter_add: process(clk,reset,en_line_counter,en_reset_line_counter)
		    variable count: integer;
		    begin
			 if reset = '1'  or en_reset_line_counter = '1' then
			     count:= 0;
			 elsif rising_edge(clk) and en_line_counter = '1' then
			     count:= count + 1;
			 end if;
			 line_counter <= count;
			end process;
			
		  peek_counter_opreation: process(clk,en_peek_counter,en_reset_peek_counter,reset)
		     variable count:integer;
			 begin
			  if reset = '1' or en_reset_peek_counter = '1' then
			    count := 3;
			  elsif rising_edge(clk) and en_peek_counter = '1' then
			       count := count - 1;
			  end if;
			  peek_counter <= count;
			end process;
		
	   nextStateLogical: process(curState,rxnow,rxData,txdone,reg_ANNN_command,dataReady,byte,tmp_data_result,tmp_max_Index,list_counter,byte_counter,line_counter,peek_counter,tmp_seqDone)
		variable reg_checkCommand_nextState: STATE_NAME;
		begin
		--default value of entity
		txnow <= '0';
		start <= '0';
		rxDone <= '0';
		en_shift <= '0';
		en_reset_seqDone <= '0';
		en_list_counter <= '0';
		en_reset_list_counter <= '0';
		en_line_counter <= '0';
		en_reset_line_counter <= '0';
		en_peek_counter <= '0';
		en_reset_peek_counter <= '0';
		en_number_words <= '0';

		case curState is
		
		   
		   when INIT =>
			 en_reset_seqDone <= '1';
			 en_reset_list_counter <= '1';
			 en_reset_line_counter <= '1';
			 en_reset_peek_counter <= '1';
			if rxnow = '1' then
			     nextState <= data_echoing_state;
			  else
			     nextState <= INIT;
			  end if;
			
		   when data_echoing_state =>
		     --send the data_echoing_data to tx
			 if txdone = '1' then
			    en_shift <= '1';
			    txnow <= '1';
			    txData <= rxdata;
				nextState <= check_command_state;
			else
			    nextState <= data_echoing_state;
			 end if;		
		   
		   when check_command_state =>
		     --to check the command is vaild
			 --this for ANNN is vaild command
			if txdone = '1' then 
			 if (reg_ANNN_command(3) = "01100001" or reg_ANNN_command(3) = "01000001") and (reg_ANNN_command(0) >= "00110000" and reg_ANNN_command(0) <= "00111001") and (reg_ANNN_command(1) >= "00110000" and reg_ANNN_command(1) <= "00111001") and (reg_ANNN_command(2) >= "00110000" and reg_ANNN_command(2) <= "00111001") and not(reg_ANNN_command(0) = "00110000" and reg_ANNN_command(1) = "00110000" and reg_ANNN_command(2) = "00110000") then
				reg_checkCommand_nextState := send_first_start;
				en_number_words <= '1';
				nextState <= print_command_LF;
			
            --the p command is vaild			
			elsif reg_ANNN_command(0) = "01110000" or reg_ANNN_command(0) = "01010000" then
				reg_checkCommand_nextState := peek_data_first_hex_letter;
				nextState <= print_command_LF;
				
			--the l command is vaild
			elsif reg_ANNN_command(0) = "01101100" or reg_ANNN_command(0) = "01001100" then
				reg_checkCommand_nextState := list_data_first_hex_letter;
				nextState <= print_command_LF;
				
            -- back to INIT state			
			else
			   rxdone <= '1';
			   nextState <= INIT;
			end if;
		    else
			  nextState <= check_command_state;
			end if;
				
         --this section is the ANNN command section	to print NNN data 
	        when send_first_start =>
			if txdone = '1' then
	              en_reset_seqDone <= '1';
			      start <= '1';
				  nextState <= wait_data_ready;
			else
			      nextState <= send_first_start;
			end if;
			 
		  when wait_data_ready =>
			   if dataReady = '1' then
				 nextState <= one_bit_first_hex_letter;
			   else
			     nextState <= wait_data_ready;
			   end if;
				
		  when one_bit_first_hex_letter =>
			if txdone = '1' then
			   txnow <= '1';
			   txData<= BCD_to_ascii(byte(7 downto 4));
			   nextState <= one_bit_second_hex_letter;
			else
			   nextState <= one_bit_first_hex_letter;
			end if;				 
			  
		   when one_bit_second_hex_letter =>
			   if txdone = '1'  then
			      txnow <= '1';
			      txData <= BCD_to_ascii(byte(3 downto 0));
			      nextState <= one_bit_space_hex;
			   else
				  nextState <= one_bit_second_hex_letter;
				end if;
			
		   when one_bit_space_hex =>
			   if txdone = '1'  then
			     txnow <= '1';
			     txData <= "00100000";
			     nextState <= check_byte_num;
			   else
			     nextState <= one_bit_space_hex;
				end if;
				
			when check_byte_num =>
			 if txdone = '1' then
			    if tmp_seqDone = '1' then
				  nextState <= print_line_LF;
				else
				  start <= '1';
				  nextState <= wait_data_ready;
			    end if;	
			  else
			    nextState <= check_byte_num;
			end if;
						
          -- this section is the peek command section to print peek data and it index	
		   when peek_data_first_hex_letter =>
		      if txdone = '1' then
			     txnow <= '1';
			     txData <= BCD_to_ascii(tmp_data_result(3)(7 downto 4));
			     nextState <= peek_data_second_hex_letter;
			  else
			     nextState <= peek_data_first_hex_letter;
			  end if;
	   
		   when peek_data_second_hex_letter =>
		      if txdone = '1' then
			     txnow <= '1';
			     txData <= BCD_to_ascii(tmp_data_result(3)(3 downto 0));
			     nextState <=  peek_data_space_hex;
			  else
			     nextState <= peek_data_second_hex_letter;
			  end if;
		   
           when peek_data_space_hex =>
		      if txdone = '1' then
				    txnow <= '1';
                    txData <= "00100000"; --space
			        nextState <= peek_index;
			  else
			        nextState <= peek_data_space_hex;
			  end if;
			  
		   when peek_index =>
		       if txdone = '1' then
			        txnow <= '1';
                    txData <= BCD_to_ascii(tmp_max_Index(peek_counter - 1));
					nextState <= peek_index_min;
			   else
			        nextState <= peek_index;
			   end if;
		  
		  when peek_index_min =>
		      if txdone = '1' then
			     en_peek_counter <= '1';
				 nextState <= check_peek_index_nums;
			  else
			     nextState <= peek_index_min;
			  end if;
			  
		  when check_peek_index_nums =>
		      if peek_counter <= 0 then
			     nextState <= print_line_LF;
			  else
			     nextState <= peek_index;
			  end if;				
		  
		  --this section is to print list command dataReady--seven data
		  when list_data_first_hex_letter =>
		        if txdone = '1' then
                    txnow <= '1';
                    txData <= BCD_to_ascii(tmp_data_result(list_counter -1)(7 downto 4));
			        nextState <= list_data_second_hex_letter;
			    else
				    nextState <= list_data_first_hex_letter;
				end if;	  

		  when list_data_second_hex_letter =>
		        if txdone = '1' then
                    txnow <= '1';
                    txData <= BCD_to_ascii(tmp_data_result(list_counter - 1)(3 downto 0));
			        nextState <= list_data_space_hex;
				else
				    nextState <= list_data_second_hex_letter;
				end if;
		
		  when list_data_space_hex =>
			    if txdone = '1' then
					txnow <= '1';
                    txData <= "00100000"; --space= 
					en_list_counter <= '1';
			        nextState <= check_list_number;
				else
				    nextState <= list_data_space_hex;
			    end if;				
      
           when check_list_number =>
		     if txdone = '1' then
              if list_counter <= 0 then
                   nextState <= print_line_LF;
				else 
				   nextState <= list_data_first_hex_letter;
                end if;
			 else
			    nextState <= check_list_number;
			 end if;
		  
		  --this section is to print line feed, carriage return and '='
		  when print_command_LF =>
		     if txdone = '1' then
			     txnow <= '1';
	             txData <= "00001010";
			     nextState <= print_command_CR;
              else
                 nextState <= print_command_LF;
              end if;
			  
          when print_command_CR =>
			  if txdone = '1' then
			    txnow <= '1';
				txData <= "00001101";
				nextState <= reg_checkCommand_nextState;
			  else
			    nextState <=  print_command_CR;
			  end if;			  
		        
	      when print_line_LF => 
		      if txdone = '1' then
			     txnow <= '1';
	             txData <= "00001010";
			     nextState <=  print_line_CR;
              else
                 nextState <= print_line_LF;
              end if;
			  
          when print_line_CR =>
			  if txdone = '1' then
			    txnow <= '1';
				txData <= "00001101";
				nextState <= print_line;
			  else
			    nextState <=  print_line_CR;
			  end if;	  

	      when print_line =>
		      if txdone = '1' then
			     en_line_counter <= '1';
			     txnow <= '1';
	             txData <= "00111101"; --===
			     nextState <= check_line_nums;
			  else
			     nextState <= print_line;
			  end if;
		  
		   when check_line_nums =>
		       if line_counter >= 4 then
			      nextState <= print_end_LF;
			   else
			      nextState <= print_line;
			  end if;
				
		   when print_end_LF =>
		       if txdone = '1' then
			     txnow <= '1';
				 txData <= "00001010";
			     nextState <= print_end_line_CR;
			   else
			     nextState <= print_end_LF;
				end if;
				
		    when print_end_line_CR =>
			  if txdone = '1' then
			    txnow <= '1';
				txData <= "00001101";
				rxDone <= '1';
			    nextState <= INIT;
			  else
			    nextState <=  print_end_line_CR;
			  end if;
	    
		  when others =>
		        nextState <= INIT;
		  end case;
         end process;
 end;