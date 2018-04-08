function k = getThermalConductivity(T)
%GETTHERMALCONDUCTIVITY Gets the thermal conductivity of standard air
% Inputs: 
% T: Static temperature [K]
% Data taken from: "The Thermal Conductivity of Fluid Air", K. Stephan and
% A. Laesecke. Retreive on 11/1/2017 at: https://srd.nist.gov/JPCRD/jpcrd269.pdf
% Outputs:
% k: Thermal conductivity [W/m*K]


C1 = 33.9729025; 
C2 = -164.702679; 
C3 = 262.108546;
C4 = -21.5346955;
C5 = -443.455815;
C6 = 607.339582;
C7 = -368.790121;
C8 = 111.296674;
C9 = -13.4122465;

T_c = 132.52; % [K] Critical temperature

T_r = T / T_c;

lambda_0r = C1 * T_r^-1 + C2 * T_r^(-2/3) + C3 * T_r^(-1/3) + C4 + ...
    C5 * T_r^(1/3) + C6 * T_r^(2/3) + C7 * T_r + C8 * T_r^(4/3) + C9 * T_r^(5/3);

del = 4.358e-3; % [W/m*K] Reduced conductivity

k = lambda_0r * del;

end

