function hall = hall_signal(theta)
% SPDX-License-Identifier: MIT
%HALL_SIGNAL Encode ideal Hall sensors in the documented phase convention.
lut=uint8([5 4 6 2 3 1]);
sector=floor(mod(double(theta)-pi/6,2*pi)/(pi/3))+1;
hall=reshape(lut(sector),size(theta));
end
