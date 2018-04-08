function [phi2, lambda2, backAz] = forwardGeodesic(phi1, lambda1, faz, s, ellipsoid)
%   Solve the forward (direct) problem of geometric geodesy:  Given an
%   initial point (PHI1,LAMBDA1), find a second point at a specified azimuth
%   FAZ and distance S along a geodesic on the specified ELLIPSOID. All
%   angles and geodetic coordinates are in degrees.  The geodetic distance
%   S must have the same units as the semimajor axis of the ellipsoid,
%   ellipsoid(1).  The azimuths are defined to be clockwise from north.
%
%   See also GEODESICINV, MERIDIANFWD.

%   Copyright 2004-2011 The MathWorks, Inc.

%--------------------------- filter input -----------------------------

% Inputs must be double or single.
supportedClasses = {'double','single'};
requiredAttributes = {'real'};
validateattributes(phi1,      supportedClasses, requiredAttributes, mfilename)
validateattributes(lambda1,   supportedClasses, requiredAttributes, mfilename)
validateattributes(faz,       supportedClasses, requiredAttributes, mfilename)
validateattributes(s,         supportedClasses, requiredAttributes, mfilename)
validateattributes(ellipsoid, supportedClasses, requiredAttributes, mfilename)

phi1 = deg2rad(phi1);
lambda1 = deg2rad(lambda1);
faz = deg2rad(faz);

% Convert any class single inputs to double; single precision is
% insufficient to support the algorithm implemented here.
singleInput = isa(phi1,'single') || isa(lambda1,'single') ...
    || isa(faz,'single') || isa(s,'single') || isa(ellipsoid,'single');
if singleInput
    phi1      = double(phi1);
    lambda1   = double(lambda1);
    faz       = double(faz);
    s         = double(s);
    ellipsoid = double(ellipsoid);
end

%-------------------- process in double precision ---------------------

%   Adapted from U.S. National Geodetic Survey (NGS) Fortran program
%   FORWARD.FOR, Version 200208.19 by Stephen J. Frakes, including
%   subroutine DIRCT1 by LCDR L. Pfeifer (1975/02/20) and John G. Gergen
%   (1975/06/08).

% Compute a distance limit.  Beyond this limit, the algorithm from DIRCT1
% (below) degrades in accuracy.  The limit is twice the distance from the
% equator to the north pole, for our reference ellipsoid, minus one meter.
dd_max = 2 * meridianarc(0,pi/2,ellipsoid) - 1;
if any(s >= dd_max)
    warning('map:geodesic:longGeodesic',...
        'Some geodesics reach halfway around the earth or farther. Loss of accuracy is possible.');
end

% Comments from DIRCT1:  SOLUTION OF THE GEODETIC DIRECT PROBLEM AFTER
% T.VINCENTY MODIFIED RAINSFORD'S METHOD WITH HELMERT'S ELLIPTICAL TERMS
% EFFECTIVE IN ANY AZIMUTH AND AT ANY DISTANCE SHORT OF ANTIPODAL

tol = 0.5e-13;

f = ecc2flat(ellipsoid);   % Semi-major axis of the reference ellipsoid
a = ellipsoid(1);          % Flattening of the reference ellipsoid

r = 1 - f;
tu = r * sin(phi1) ./ cos(phi1);
sf = sin(faz);
cf = cos(faz);
baz = zeros(size(phi1));
q = (cf ~= 0);
baz(q) = 2* atan2(tu(q),cf(q));
cu = 1./sqrt(tu.^2 + 1);
su = tu .* cu;
sa = cu .* sf;
c2a = -sa.^2 + 1;
x = sqrt((1/r/r - 1)*c2a + 1) + 1;
x = (x - 2)./x;
c = 1 - x;
c = (1 + (x.^2)/4)./c;
d = (0.375 * x.^2 - 1) .* x;
tu = s ./ r ./ a ./ c;
y = tu;

repeat = true;
while(repeat)
    sy = sin(y);
    cy = cos(y);
    cz = cos(baz + y);
    e = 2 * cz.^2 - 1;
    c = y;
    x = e .* cy;
    y = 2 * e - 1;
    y = (((4 * sy.^2 - 3) .* y .* cz .* d/6 + x) .* d/4 - cz) .* sy .* d + tu;
    repeat = any(abs(y - c) > tol);
end

baz = cu .* cy .* cf - su .* sy;
c = r * sqrt(sa.^2 + baz.^2);
d = su .* cy + cu .* sy .* cf;
phi2 = atan2(d,c);
c = cu .* cy - su .* sy .* cf;
x = atan2(sy .* sf, c);
c = ((-3 * c2a + 4) * f + 4) .* c2a * f/16;
d = ((e .* cy .* c + cz) .* sy .* c + y) .* sa;
lambda2 = lambda1 + x - (1 - c) .* d .* f;
baz = atan2(sa,baz) + pi;

%-------------------------- filter output -----------------------------

% If any inputs were single, all outputs should be single.
if singleInput
    phi2    = single(phi2);
    lambda2 = single(lambda2);
    baz     = single(baz);
end

phi2 = rad2deg(phi2);
lambda2 = rad2deg(lambda2);
backAz = rad2deg(baz);
end

function angleInRadians = deg2rad(angleInDegrees)
% DEG2RAD Convert angles from degrees to radians.
%   DEG2RAD(X) converts angle units from degrees to radians for each
%   element of X.
%
%   See also RAD2DEG.

% Copyright 2015 The MathWorks, Inc.

if isfloat(angleInDegrees)
    angleInRadians = (pi/180) * angleInDegrees;
else
    error(message('MATLAB:deg2rad:nonFloatInput'))
end
end

function angleInDegrees = rad2deg(angleInRadians)
% RAD2DEG Convert angles from radians to degrees.
%   RAD2DEG(X) converts angle units from radians to degrees for each
%   element of X.
%
%   See also DEG2RAD.

% Copyright 2015 The MathWorks, Inc.

if isfloat(angleInRadians)
    angleInDegrees = (180/pi) * angleInRadians;
else
    error(message('MATLAB:rad2deg:nonFloatInput'))
end
end

function s = meridianarc(phi1, phi2, ellipsoid)
%MERIDIANARC Ellipsoidal distance along meridian
%
%   S = MERIDIANARC(PHI1, PHI2, ELLIPSOID) calculates the (signed) distance
%   S between latitudes PHI1 and PHI2 along a meridian on the specified
%   ellipsoid. ELLIPSOID is a reference ellipsoid (oblate spheroid) object,
%   a reference sphere object, or a vector of the form [semimajor_axis,
%   eccentricity].  PHI1 and PHI2 are in radians. S has the same units as
%   the semimajor axis of the ellipsoid.  S is negative if phi2 is less
%   than phi1.
%
%   See also MERIDIANFWD.

% Copyright 2004-2011 The MathWorks, Inc.

% The following provides an equivalent (but less efficient) computation:
%
% s = rsphere('rectifying',ellipsoid)...
%        * (convertlat(ellipsoid,phi2,'geodetic','rectifying','radians')...
%         - convertlat(ellipsoid,phi1,'geodetic','rectifying','radians'));

if isobject(ellipsoid)
    a = ellipsoid.SemimajorAxis;
    n = ellipsoid.ThirdFlattening;
else
    a = ellipsoid(1);
    n = ecc2n(ellipsoid(2));
end

n2 = n^2;

% Radius of rectifying sphere
r = a * (1 - n) * (1 - n2) * (1 + ((9/4) + (225/64)*n2)*n2);

f1 = (3/2 - (9/16) * n2) * n;
f2 = (15/16 - (15/32) * n2) * n2;
f3 = (35/48) * n * n2;
f4 = (315/512) * n2 * n2;

% Rectifying latitudes
mu1 = phi1 - f1*sin(2*phi1) + f2*sin(4*phi1) - f3*sin(6*phi1) + f4*sin(8*phi1);
mu2 = phi2 - f1*sin(2*phi2) + f2*sin(4*phi2) - f3*sin(6*phi2) + f4*sin(8*phi2);

s = r * (mu2 - mu1);
end

function n = ecc2n(ecc)
%ECC2N  Third flattening of ellipse from eccentricity
%
%   Support for nonscalar input, including the syntax
%   n = ECC2N(ellipsoid), will be removed in a future release.
%
%   n = ECC2N(ecc) computes the parameter n (the "third flattening") of an
%   ellipse (or ellipsoid of revolution) given its eccentricity ecc.  n is
%   defined as (a-b)/(a+b), where a is the semimajor axis and b is the
%   semiminor axis.  Except when the input has 2 columns (or is a row
%   vector), each element is assumed to be an eccentricity and the output n
%   has the same size as ecc.
%
%   n = ECC2N(ellipsoid), where ellipsoid has two columns (or is a row
%   vector), assumes that the eccentricity is in the second column, and a
%   column vector is returned.
%
%   See also ECC2FLAT, MAJAXIS, MINAXIS, N2ECC, oblateSpheroid

% Copyright 1996-2013 The MathWorks, Inc.

if min(size(ecc)) == 1 && ndims(ecc) <= 2
    % First col if scalar or column vector input
    % Second col if two column input or row vector
    col = min(size(ecc,2), 2);
    ecc = ecc(:,col);
end

%  Ensure real inputs
ecc = ignoreComplex(ecc, mfilename, 'eccentricity');

%  Compute n. The formula used below is the algebraic equivalent of the
%  more obvious formula, n = (1 - sqrt(1 - e2)) ./ (1 + sqrt(1 - e2)), but
%  affords better numerical precision because it avoids taking the
%  difference of two O(1) quantities.
e2 = ecc.^2;
n = e2 ./ (1 + sqrt(1 - e2)).^2;
end

function A = ignoreComplex(A, func_name, var_name) 
%IGNORECOMPLEX Convert complex input to real and issue warning
%
%   IGNORECOMPLEX(A, FUNC_NAME, VAR_NAME) replaces complex A with its real
%   part and issues a warning.

% Copyright 1996-2011 The MathWorks, Inc.

if ~isnumeric(A)
    error(message('map:validate:nonNumericInput', func_name, var_name))
end

if ~isreal(A)
    id = ['map:' func_name ':ignoringComplexArg'];
    warning(id,'%s',getString(message('map:removing:complexInput', ...
        upper(var_name), upper(func_name))))
	A = real(A);
end
end

function f = ecc2flat(ecc)
%ECC2FLAT Flattening of ellipse from eccentricity
%
%   Support for nonscalar input, including the syntax
%   f = ECC2FLAT(ellipsoid), will be removed in a future release.
%
%   f = ECC2FLAT(ecc) computes the flattening of an ellipse (or ellipsoid
%   of revolution) given its eccentricity ecc.  Except when the input has 2
%   columns (or is a row vector), each element is assumed to be an
%   eccentricity and the output f has the same size as ecc.
%
%   f = ECC2FLAT(ellipsoid), where ellipsoid has two columns (or is a row
%   vector), assumes that the eccentricity is in the second column, and a
%   column vector is returned.
%
%   See also FLAT2ECC, ECC2N, MAJAXIS, MINAXIS, oblateSpheroid

% Copyright 1996-2013 The MathWorks, Inc.

if min(size(ecc)) == 1 && ndims(ecc) <= 2
    % First col if scalar or column vector input
    % Second col if two column input or row vector
    col = min(size(ecc,2), 2);
    ecc = ecc(:,col);
end

%  Ensure real inputs
ecc = ignoreComplex(ecc, mfilename, 'eccentricity');

% Compute the flattening. The formula used below is the algebraic
% equivalent of the more obvious formula, f = 1 - sqrt(1 - e2), but
% affords better numerical precision because it avoids taking the
% difference of two O(1) quantities.
e2 = ecc.^2;
f = e2 ./ (1 + sqrt(1 - e2));
end