function p = pCDF(x, lambda)
%PCDF Poisson CDF
%   Detailed explanation goes here
    i = 0:floor(x);
    p = exp(-lambda)*sum((lambda.^i)./(factorial(i)));
end

