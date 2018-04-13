function check = spawnWeather(simTime,cur,max)
%SPAWNWEATHER Summary of this function goes here
%   Detailed explanation goes here
	check = false;
	if mod(simTime,10) ~= 0
		return
	end
	
	if rand() > 0.5
		check = true;
	end
end

