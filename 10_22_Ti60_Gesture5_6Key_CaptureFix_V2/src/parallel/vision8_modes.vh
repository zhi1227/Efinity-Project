// Shared presentation mapping. Internal algorithm IDs deliberately stay stable.
function [2:0] slot_to_mode;
 input [2:0] slot;
 begin case(slot)5:slot_to_mode=7;6:slot_to_mode=5;7:slot_to_mode=6;default:slot_to_mode=slot;endcase end
endfunction
function [2:0] mode_to_slot;
 input [2:0] mode;
 begin case(mode)7:mode_to_slot=5;5:mode_to_slot=6;6:mode_to_slot=7;default:mode_to_slot=mode;endcase end
endfunction
