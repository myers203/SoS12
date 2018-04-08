function [s, fwd_az, back_az] = inverseGeodesic(phi1, lambda1, phi2, lambda2, ellipsoid)
% Solves the inverse problem of geometric geodesy: Given a pair of points
% with geodetic coordinates PHI1, LAMBDA1, PHI2, LAMBDA2, find the distance
% S between them along a geodesic on the specified ELLIPSOID.
%
% Also determines the forward azimuth FAZ (azimuth from point 1 to point)
% and the back azimuth BAZ (azimuth from point 2 to point 1).
%
% All inputs and output angles and geodetic coordinates are in degrees.
% Distance S is in the same units as the major axis length defined in
% ELLIPSOID.

phi1 = phi1 *pi/180;
lambda1 = lambda1 *pi/180;
phi2 = phi2 *pi/180;
lambda2 = lambda2 *pi/180;

% Convert any class single inputs to double; single precision is
% insufficient to support the algorithm implemented here.
singleInput = isa(phi1,'single') || isa(lambda1,'single') ...
    || isa(phi2,'single') || isa(lambda2,'single') || isa(ellipsoid,'single');
if singleInput
    phi1      = double(phi1);
    lambda1   = double(lambda1);
    phi2      = double(phi2);
    lambda2   = double(lambda2);
    ellipsoid = double(ellipsoid);
end

%-------------------- process in double precision ---------------------

%   Adapted from U.S. National Geodetic Survey (NGS) Fortran program
%   INVERSE.FOR, Version 200208.19 by Stephen J. Frakes, including
%   subroutines GPNHRI and GPNLOA by Robert (Sid) Safford.

lambda1(lambda1 < 0) = lambda1(lambda1 < 0) + 2*pi;
lambda2(lambda2 < 0) = lambda2(lambda2 < 0) + 2*pi;

% compute the geodetic inverse
[fwd_az, back_az, s] = gpnhri(phi1, lambda1, phi2, lambda2, ellipsoid);

% convert radians to degrees
fwd_az = fwd_az.*180/pi;
back_az = back_az.*180/pi;

% check for a non distance
q = (s/ellipsoid(1) < 0.00005/6371000);
fwd_az(q) = 0;
back_az(q) = 0;

%-------------------------- filter output -----------------------------

% If any inputs were single, all outputs should be single.
if singleInput
    s   = single(s);
    fwd_az = single(fwd_az);
    back_az = single(back_az) ;
end

%--------------------------------------------------------------------------

function [az1,az2,s] = gpnhri(p1,e1,p2,e2,ellipsoid)

%   Adapted from Fortran subroutine GPNHRI (compute helmert rainsford
%   inverse proglem), Version 200208.09 by Robert (Sid) Safford.
%
%   solution of the geodetic inverse problem after t. vincenty modified
%   rainsford's method with helmert's elliptical terms effective in any
%   azimuth and at any distance short of antipocal from/to stations must
%   not be the geographic pole. parameter a is the semi-major axis of the
%   reference ellipsoid finv=1/f is the inverse flattening of the reference
%   ellipsoid latitudes and longitudes in radians positive north and west
%   forward and back azimuths returned in radians clockwise from south
%   geodesic distance s returned in units of semi-major axis a
%
%   1. do not use for meridional arcs and be careful on the equator.
%   2. azimuths are from north(+) clockwise and
%   3. longitudes are positive east(+)
%
%   input parameters:
%   -----------------
%   p1           lat station 1                               radians
%   e1           lon station 1                               radians
%   p2           lat station 2                               radians
%   e2           lon station 2                               radians
%   ellipsoid    ellipsoid vector [semimajor-axis eccentricity]
%
%   output parameters:
%   ------------------
%   az1          azi at sta 1 -> sta 2                       radians
%   az2          azi at sta 2 -> sta 1                       radians
%   s            geodetic dist between sta(s) 1 & 2          meters
%
%   local variables and constants:
%   ------------------------------
%   a            semi-major axis of reference ellipsoid      meters
%   f            flattening (0.0033528...)
%   esq          eccentricity squared
%   aa           constant from subroutine gpnloa
%   alimit       equatorial arc distance along the equator   (radians)
%   arc          meridional arc distance latitude p1 to p2 (in meters)
%   az1          azimuth forward                          (in radians)
%   az2          azimuth back                             (in radians)
%   bb           constant from subroutine gpnloa
%   dlon         temporary value for difference in longitude (radians)
%   equ          equatorial distance                       (in meters)
%   r1,r2        temporary variables
%   s            ellipsoid distance                        (in meters)
%   sms          equatorial - geodesic distance (S - s) "Sms"
%   ss           temporary variable
%   tol0         tolerance for checking computation value
%   tol1         tolerance for checking a real zero value
%   tol2         tolerance for close to zero value
%   twopi        two times constant pi

az1 = zeros(size(p1));
az2 = zeros(size(p1));
s   = zeros(size(p1));

a = ellipsoid(1);
e_squared = ellipsoid(2)^2;
f = e_squared/(1 + sqrt(1 - e_squared));
esq  = ellipsoid(2)^2;

tol0 = 5.0d-15;
tol1 = 5.0d-14;
tol2 = 7.0d-03;

twopi = 2*pi;

% test the longitude difference with tol1
% tol1 is approximately 0.000000001 arc seconds
ss = e2 - e1;

q0 = abs(ss) < tol1;
e2(q0) = e2(q0) + tol1;
arc = meridianDist(p1(q0), p2(q0), ellipsoid);
s(q0) = abs(arc);
az1(q0) = pi;
az2(q0) = 0;
az1(q0 & (p2 > p1)) = 0;
az2(q0 & (p2 > p1)) = pi;
if all(q0)
    return
end

% test for longitude over 180 degrees
dlon = e2 - e1;
q1 = dlon >= 0;
q2 = q1 & (pi <= dlon) & (dlon < twopi);
ss = abs(dlon);
q3 = ~q1 & (pi <= ss) & (ss < twopi);
dlon(q2) = dlon(q2) - twopi;
dlon(q3) = dlon(q3) + twopi;

q4 = ss > pi;
ss(q4) = twopi - ss(q4);

% compute the limit in longitude (alimit), it is equal
% to twice the distance from the equator to the pole,
% as measured along the equator (east/west)
alimit =  pi*(1 - f);

% test for anti-nodal difference
q5 = (ss > alimit);

r1 = abs(p1);
r2 = abs(p2);

% Original comment and logic derived from GPNHRI:
%    %   latitudes r1 & r2 are not near the equator
%    q6 = (r1 > tol2) & (r2 > tol2);
% Adjusted comment and logic:
%   At least one of the endpoints is "not too close" to the Equator
q6 = (r1 > tol2) | (r2 > tol2);

%   longitude difference is greater than lift-off point
%   now check to see if  "both"  r1 & r2 are on equator
q7 = (r1 < tol1) & (r2 > tol2);
q8 = (r2 < tol1) & (r1 > tol2);

%   check for either r1 or r2 just off the equator but < tol2
q9 = (r1 > tol1) | (r2 > tol1);
q10 = ~q0 & q5 & ~(q6 | q7 | q8) & q9;
az1(q10) = NaN;
az2(q10) = NaN;
s(q10) = NaN;
if any(q10)
    warning('Earth:inverseGeodesic:solutionNotReached', ...
        ['At least one input point pair consists of nearly-equatorial,\n', ...
        'nearly-antipodal points for which the long-geodesic algorithm\n', ...
        'does not apply.  The corresponding distances and azimuths are\n', ...
        'being set to NaN for %d such pairs.'], sum(q10))
end
if all(q0 & q10)
    return
end

%   compute the azimuth to anti-nodal point
q11 = ~q0 & q5 & ~(q6 | q7 | q8) & ~q9;
[az1(q11),az2(q11),sms] = gpnloa(dlon(q11),ellipsoid);

%   compute the equatorial distance & geodetic
equ = a * abs(dlon(q11));
s(q11) = equ - sms;
q12 = ~(q0 | q10 | q11);  % Flag the pairs we haven't done yet as special cases.
if ~any(q12);
    return     % We've done them all!
end

% Move on to general case ...
%  Here we split out a new routine to process a subset of the inputs
%  without the need to constantly apply the logical index q12.
[s_gen, az1_gen, az2_gen]...
    = gpnhri_gen(p1(q12),e1(q12),p2(q12),e2(q12),a,f,esq,tol0);

s(q12)   = s_gen;
az1(q12) = az1_gen;
az2(q12) = az2_gen;

%--------------------------------------------------------------------------

function [s, az1, az2] = gpnhri_gen(p1,e1,p2,e2,a,f,esq,tol0)

if length(p1) >= 2
    error('Invalid lengths in gpnhri for arguments. Only acceptable length is 1')
end

f0 = (1 - f);
a = a*f0;
esq = esq/(1 - esq);

% the longitude difference
dlon = e2-e1;
ab = dlon;
kount = 0;

% the reduced latitudes
u1 = atan(f0*sin(p1)/cos(p1));
u2 = atan(f0*sin(p2)/cos(p2));

su1 = sin(u1);
cu1 = cos(u1);

su2 = sin(u2);
cu2 = cos(u2);

repeat = true;
while(repeat)
    kount = kount + 1;
    
    clon = cos(ab);
    slon = sin(ab);
    
    csig = su1 * su2 + cu1 * cu2 * clon;
    ssig = realsqrt((slon * cu2)^2 + (su2 * cu1 - su1 * cu2 * clon)^2);
    
    sig = atan2(ssig,csig);
    sinalf = cu1 * cu2 * slon / ssig;
    
    w = (1 - sinalf ^ 2);
    t4 = w^2;
    t6 = w * t4;
    
    ao = f - f^2*(1 + f + f^2)*w/4 + 3*f^3*(1 + 9*f/4)*t4/16 - 25*f^4*t6/128;
    a2 =     f^2*(1 + f + f^2)*w/4 -   f^3*(1 + 9*f/4)*t4/4  + 75*f^4*t6/256;
    a4 =                               f^3*(1 + 9*f/4)*t4/32 - 15*f^4*t6/256;
    a6 =                                                        5*f^4*t6/768;
    
    qo = 0;
    if w > tol0
        qo = -2 * su1 * su2 / w;
    end
    
    q2 = csig + qo;
    q4 = 2*q2^2 - 1;
    q6 = q2*(4*q2^2 - 3);
    r2 =  2*ssig*csig;
    r3 = ssig*(3 - 4*ssig^2);
    
    s = sinalf * (ao*sig + a2*ssig*q2 + a4*r2*q4 + a6*r3*q6);
    xz = dlon + s;
    
    xy = abs(xz - ab);
    ab = dlon + s;
    
    repeat = ~(xy < 0.5e-13) && (kount <= 7);
end

% the coefficients of type b
z = esq * w;
bo = 1 + z*( 1/4 + z*( -3/64 + z*(   5/256 - z*175/16384)));
b2 =     z*(-1/4 + z*(  1/16 + z*( -15/512 + z* 35/2048)));
b4 =             z^2*(-1/128 + z*(   3/512 - z* 35/8192));
b6 =                       z^3*( -1/1536 + z*  5/6144);

% the distance in meters
s = a*(bo*sig + b2*ssig*q2 + b4*r2*q4 + b6*r3*q6);

% first compute the az1 & az2 for along the equator
if dlon > pi
    dlon = dlon - 2*pi;
end

if abs(dlon > pi)
    dlon= dlon + 2*pi;
end

az1 = pi/2;
if dlon  < 0
    az1 = 3*pi/2;
end

az2 = az1 + pi;
if (az2 > 2*pi)
    az2 = az2 - 2*pi;
end

% now compute the az1 & az2 for latitudes not on the equator
%   azimuths from north,longitudes positive east
q = ~((abs(su1) < tol0) & (abs(su2) < tol0));
if q
    az1 =      atan2(  sinalf*cu2(q),  sinalf*(su2 * cu1 - clon * su1 * cu2)/slon);
    az2 = pi - atan2( -sinalf*cu1(q), -sinalf*(su1 * cu2 - clon * su2 * cu1)/slon);
end

if az1 < 0
    az1 = az1 + 2*pi;
end

if az2 < 0
    az2 = az2 + 2*pi;
end

%--------------------------------------------------------------------------

function [az1,az2,sms] = gpnloa(dl,ellipsoid)

%   Adapted from Fortran subroutine GPNLOA (COMPUTE THE LIFF-OFF-AZIMUTH
%   CONSTANTS), Version 200005.26 by Robert (Sid) Safford.
%
%   INPUT PARAMETERS:
%   -----------------
%   DL           LON DIFFERENCE
%   ELLIPSOID    ellipsoid vector [semimajor-axis eccentricity]
%
%   OUTPUT PARAMETERS:
%   ------------------
%   AZ1          AZI AT STA 1 -> STA 2
%   AZ2          AZ2 AT STA 2 -> STA 1
%   SMS          DISTANCE ... EQUATORIAL - GEODESIC  (S - s)   "SMS"

amax = ellipsoid(1);         % SEMI-MAJOR AXIS OF REFERENCE ELLIPSOID
e2 = ellipsoid(2)^2;         % ECCENTRICITY SQUARED FOR REFERENCE ELLIPSOID
f = e2/(1 + sqrt(1 - e2));

tt = 5e-13;

cons = (pi - abs(dl))/(pi*f);

% COMPUTE AN APPROXIMATE AZ
az = asin(cons);

t1 =     1;
t2 =   (-1/4)*f*(1 + f + f*f);
t4 =   (3/16)*f*f*(1 + (9/4)*f);
t6 = (-25/128)*f*f*f;

repeat = true;
iter = 0;
while(repeat)
    iter = iter + 1;
    s = cos(az);
    c2 = s.*s;
    ao = t1 + t2*c2 + t4*c2.*c2 + t6*c2.*c2.*c2;
    cs = cons./ao;
    s  = asin(cs);
    q = abs(s - az) < tt;
    az(~q) = s(~q);
    repeat = any(~q) && (iter <= 6);
end
az1 = s;

az1(dl < 0) = 2*pi - az1(dl < 0);

az2 = 2*pi - az1;

% EQUATORIAL - GEODESIC  (S - s)   "SMS"
esqp = e2/(1 - e2);
s = cos(az1);

u2 = esqp * s .* s;
u4 = u2 .* u2;
u6 = u4 .* u2;
u8 = u6 .* u2;

t1 =      1;
t2 =     (1/4)*u2;
t4 =    (-3/64)*u4;
t6 =    (5/256)*u6;
t8 = (-175/16384)*u8;

bo = t1 + t2 + t4 + t6 + t8;
s = sin(az1);
sms = amax * pi * (1 - f*abs(s).*ao - bo*(1 - f));

%--------------------------------------------------------------------------

function s = meridianDist(phi1, phi2, ellipsoid)
%MERIDIANDIST Ellipsoidal distance along meridian
%
%  S = MERIDIANDIST(PHI1, PHI2, ELLIPSOID) calculates the distance S
%  between latitudes PHI1 and PHI2 along a meridian on the input ellipsoid.
%  PHI1 and PHI2 are in radians. S has the same units as the semimajor axis
%  of the ellipsoid.

e2 = ellipsoid(2)^2;
n = e2/(1 + sqrt(1 - e2))^2;

n2 = n^2;

% Radius of rectifying sphere
r = ellipsoid(1) * (1 - n) * (1 - n2) * (1 + ((9/4) + (225/64)*n2)*n2);

f1 = (3/2 - (9/16) * n2) * n;
f2 = (15/16 - (15/32) * n2) * n2;
f3 = (35/48) * n * n2;
f4 = (315/512) * n2 * n2;

% Rectifying latitudes
mu1 = phi1 - f1*sin(2*phi1) + f2*sin(4*phi1) - f3*sin(6*phi1) + f4*sin(8*phi1);
mu2 = phi2 - f1*sin(2*phi2) + f2*sin(4*phi2) - f3*sin(6*phi2) + f4*sin(8*phi2);

s = r * (mu2 - mu1);
