library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.common_pack.all;

entity dataConsume is
  port (
    	clk:		in std_logic;
		reset:		in std_logic; 					-- synchronous reset
		start: 		in std_logic; 					-- goes high to signal data transfer
		numWords_bcd: 	in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn: 	in std_logic;
		ctrlOut: 	out std_logic := '0';
		data: 		in std_logic_vector(7 downto 0);
		dataReady: 	out std_logic;
		byte: 		out std_logic_vector(7 downto 0);
		seqDone: 	out std_logic := '0';
		maxIndex: 	out BCD_ARRAY_TYPE(2 downto 0);
		dataResults: 	out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) 	-- index 3 holds the peak
  	);
end dataConsume;

--###################### design process ######################
-- the system will starts at the IDLE state, when it recieves 
-- the 'start' signal from the command processor, the data processor 
-- will start to request for data from the data generator by sending 
-- ctrlIn. the number of words is given by 'numWords_bcd' in bcd type.
-- Then data generator will send data and ctrlOut back to data
-- processor.

architecture behav of dataConsume is 

	type state_type is (s0, s1, s2, s3);
	signal cur_state : 		state_type := s0;
	signal next_state : 		state_type;
	signal ctrlIn_delayed : 	std_logic := '0';
	signal ctrlIn_detected :	std_logic := '0';
	signal ctrlOut_reg :        std_logic := '0';
	signal ctrlOut_delayed:     std_logic := '0';
	signal index : 			integer range 0 to SEQ_LENGTH;
	signal numWords_integer :	integer;
	signal count :			integer	range 0 to SEQ_LENGTH;
	signal maxIndex_dec :		integer range 0 to SEQ_LENGTH := 0;
	signal maxIndex_dec_reg :	integer range 0 to SEQ_LENGTH := 0;
	signal dataResult_reg_enable: 	std_logic := '0';
	signal clearCount :          boolean := false;
	signal enCount :             boolean := false;
	signal enMax :               boolean := false;
	signal spcase1,spcase2  :             boolean := false;
	signal data_reg :        CHAR_ARRAY_TYPE(6 downto 0):= (X"00",X"00",X"00",X"00",X"00",X"00",X"00");
    signal max_reg :        std_logic_vector(7 downto 0):= X"00";
    signal maxIndex_reg_array0 : integer range 0 to 9;
    signal maxIndex_reg_array1 : integer range 0 to 9;
    signal maxIndex_reg_array2 : integer range 0 to 9;
    
       
begin
    
    ctrlout <= ctrlOut_reg;
	ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;
	byte <= data;
	count <= index;
	
--state logic
	state_proc : process (cur_state, next_state, start, CtrlIn_detected, count, numWords_integer)
	begin
	
		case cur_state is
-- s0 is a IDLE state
			when s0 =>
			
				if start = '1' then
					next_state <= s1;
				else
					next_state <= s0;
				end if;

-- s1 is a state when recieve the data from data generator
			when s1 =>
			
				if ctrlIn_detected = '1' then
					next_state <= s2;
				else
					next_state <= s1;
				end if;

-- s2 is a state when data ready (start get from tb)
			when s2 =>
			
				if count < numWords_integer then
				    if start = '1' then 
			        next_state <= s1;				
				    else
				    next_state <= s2;
				    end if;
				else
				    next_state <= s3;
				end if;

--s3 is a state when seqdone
			when s3 =>
			
				if count = numWords_integer then
					next_state <= s0;
				else 
					next_state <= s3; 
				end if;
		          
--other situations
			when others =>
				next_state <= s0;
		end case;
	end process;
	
--state shift
    state_shift : process(clk,reset)
    begin
        if reset = '1' then
            cur_state <= s0;
        elsif rising_edge(clk) then
            cur_state <= next_state;
        end if;
    end process;

--ctrlIn_delayed
    ctrlIn_delay : process(clk)
    begin
        if rising_edge(clk) then
            CtrlIn_delayed <= ctrlIn;
            CtrlOut_delayed <= CtrlOut_reg;
        end if;
    end process;

--register to store decimal numWords
	numWrods_dec : process(clk, reset)
	begin
		if reset = '1' then 
			numWords_integer <= 0;
		elsif rising_edge(clk) then
			numWords_integer <= to_integer(unsigned(numWords_bcd(2)))* 100 + to_integer(unsigned(numWords_bcd(1)))* 10 + to_integer(unsigned(numWords_bcd(0)))* 1;
		end if;
	end process;

--stateOutput
    stateOutput : process(cur_state,start,count,numWords_integer,ctrlOut_delayed,numWords_bcd,ctrlIn_detected,data)
    begin
    dataReady <= '0';
    seqDone <= '0';
    clearCount <= false;
    encount <= false;
    ctrlOut_reg <= ctrlOut_delayed;

    case cur_state is
        when s0 =>
            clearCount <= true;
 	        if start = '1' then 
                ctrlOut_reg <= not ctrlOut_delayed; 
            end if;

        when s1 =>
            if ctrlIn_detected = '1' then 
                enCount <= true; 
                dataReady <= '1';
            end if;

        when s2 =>
            if count < numWords_integer then
                if start = '1' then
                    ctrlOut_reg <= not ctrlOut_delayed; 
                end if;
            end if;

        when s3 => 
            if count = numWords_integer then 
                seqDone <= '1';
                clearCount <= true; 
            else
                enCount <= true;
            end if;
            
    end case;
    end process; --stateOutput

--count the trasition of CtrlIn (CtrlIn_detect)
	count_reg: process(clk)
  	begin
    		if rising_edge(clk) then
      			if clearCount = true then
        			index <= 0;
      			elsif enCount = true then
      			    index <= index + 1;
      		    end if;
      		end if;
     end process;

--data_reg shift
    data_register:process(clk)	
    begin
        --if rising_edge(clk) then
        if clearCount = true then
            data_reg <= (X"00",X"00",X"00",X"00",X"00",X"00",X"00");
        elsif rising_edge(clk) and enCount = true then
                  	data_reg(0) <= data_reg(1);
                    data_reg(1) <= data_reg(2);
                    data_reg(2) <= data_reg(3);
                    data_reg(3) <= data_reg(4);
                    data_reg(4) <= data_reg(5);
                    data_reg(5) <= data_reg(6);
                    data_reg(6) <= data;                 
        end if;
        --end if;
    end process;
    
 --find max 
    max_finder : process(clk,count)
    begin
        if reset = '1' or clearCount = true then
            max_reg <= X"00";
            maxIndex_dec <= 0;
        elsif rising_edge (clk) then
            if data >  max_reg then 
                max_reg <= data;
                maxIndex_dec <=count;
            end if;
        end if;
    end process;
 
--maxIndex_dec to BCD
--array2 is the integer on the 10^2 bit
--array1 is the integer on the 10^1 bit
--array0 is the integer on the 10^0 bit	
	conventor: process(clk)
    begin 
        if reset = '1' then
            maxIndex <= ("0000","0000","0000");
            maxIndex_reg_array2 <= 0;
            maxIndex_reg_array1 <= 0;
            maxIndex_reg_array0 <= 0;
        elsif rising_edge(clk) then
            maxIndex_reg_array2 <= maxIndex_dec /100;
            maxIndex_reg_array1 <= (maxIndex_dec mod 100)/10;
            maxIndex_reg_array0 <= maxIndex_dec mod 10;
            maxIndex(2) <= std_logic_vector(to_unsigned(maxIndex_reg_array2, 4));
			maxIndex(1) <= std_logic_vector(to_unsigned(maxIndex_reg_array1, 4));
			maxIndex(0) <= std_logic_vector(to_unsigned(maxIndex_reg_array0, 4));
        end if;
        end process;
            
-- get dataResult
    dataget : process(clk,reset)
    begin
        if reset ='1' then
            dataResults <= (others => X"00");
        elsif rising_edge(clk) then
        if enCount = true and spcase2 = false then
            if data_reg(3) = max_reg and count = maxIndex_dec + 4 then
                dataResults <= data_reg;
            end if;
        elsif spcase2 = true and count = numwords_integer then
            if maxIndex_dec  = numwords_integer - 3 then
               dataResults(6) <= X"00";
               dataResults(5) <= data_reg(6);
               dataResults(4) <= data_reg(5);
               dataResults(3) <= data_reg(4);
               dataResults(2) <= data_reg(3);
               dataResults(1) <= data_reg(2);
               dataResults(0) <= data_reg(1);
            elsif maxIndex_dec = numwords_integer - 2 then
               dataResults(6) <= X"00";
               dataResults(5) <= X"00";
               dataResults(4) <= data_reg(6);
               dataResults(3) <= data_reg(5);
               dataResults(2) <= data_reg(4);
               dataResults(1) <= data_reg(3);
               dataResults(0) <= data_reg(2);
            else --- maxIndex_dec = numwords_integer
               dataResults(6) <= X"00";
               dataResults(5) <= X"00";
               dataResults(4) <= X"00";
               dataResults(3) <= data_reg(6);
               dataResults(2) <= data_reg(5);
               dataResults(1) <= data_reg(4);
               dataResults(0) <= data_reg(3);
            end if;
        elsif  spcase1 = true then
             --dataResults <= (others => X"FF");
            if maxIndex_dec = 0 then
              if count = 1 then
                 dataResults(3) <= data_reg(6);
              elsif count = 2 then
                 dataResults(2) <= data_reg(6);
                 dataResults(3) <= data_reg(5);
              elsif count = 3 then
                 dataResults(1) <= data_reg(6);
                 dataResults(2) <= data_reg(5);
                 dataResults(3) <= data_reg(4);
               end if;
               end if;
            if maxIndex_dec = 1 then
              if count = 2 then
                 dataResults(3) <= data_reg(6);
                 dataResults(4) <= data_reg(5);
              elsif count = 3 then
                 dataResults(2) <= data_reg(6);
                 dataResults(3) <= data_reg(5);
                 dataResults(4) <= data_reg(4);
               end if;
               end if;
            if maxIndex_dec = 2 then
                 dataResults(3) <= data_reg(6);
                 dataResults(4) <= data_reg(5);
                 dataResults(5) <= data_reg(4);
            end if;  
        end if; 
        end if;
    end process;

--- special case
    special1: process(clk,reset)
    begin
        if rising_edge(clk) then
          if  maxIndex_dec > numwords_integer -4 then
             spcase2 <= true;
          else 
             spcase2 <= false;
          end if;
        end if;
     end process;
     
     special2:process(clk,reset)
     begin 
       if rising_edge(clk) then
          if maxIndex_dec<3 then
             spcase1 <= true;
          else
             spcase1 <= false;
          end if;
        end if;
     end process;
end behav;
			

	
		
			




