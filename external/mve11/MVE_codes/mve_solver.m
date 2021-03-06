function [x,E2,msg,y,z,iter] = mve_solver(A,b,x0,maxiter,tol)
%  Find the maximum volume ellipsoid
%    {v:  v = x + Es, ||s|| <= 1}
%  inscribing a full-dimensional polytope
%          {v:  Av <= b}
%  Input:  A, b --- defining the polytope
%          x0 --- interior point (Ax0 < b)
%  Output: x --- center of the ellipsoid
%          E2 --- E'*E

%--------------------------------------
% Yin Zhang, Rice University, 07/29/02
%--------------------------------------

t0 = cputime; 
[m, n] = size(A);
bnrm = norm(b); 

if ~exist('maxiter') maxiter = 50; end;
if ~exist('tol') tol = 1.e-4; end;
minmu = 1.e-8; tau0 = .75;

bmAx0 = b - A*x0;
if any(bmAx0<=0) error('x0 not interior'); end

A = sparse(1:m,1:m,1./bmAx0)*A; b = ones(m,1); 
x = zeros(n,1); y = ones(m,1); bmAx = b;

fprintf('\n  Residuals:   Primal     Dual    Duality  logdet(E)\n');
fprintf('  --------------------------------------------------\n');
resid1 = zeros(maxiter,1); %Ben
resid2 = zeros(maxiter,1); %Ben
resid3 = zeros(maxiter,1); %Ben
cond1 = zeros(maxiter,1); %Ben
cond2 = zeros(maxiter,1); %Ben
condE = zeros(maxiter,1); %Ben

res = 1; msg = 0;
prev_obj = -Inf;
for iter=1:maxiter %----- loop starts -----

if iter > 1 bmAx = bmAx - astep*Adx; end

Y = sparse(1:m,1:m,y);
E2 = inv(full(A'*Y*A));

condE(iter) = rcond(E2); %Ben
Q = A*E2*A';
h = sqrt(diag(Q));
if iter==1
   t = min(bmAx./h); 
   y = y/t^2; h = t*h;
   z = max(1.e-1, bmAx-h);
   Q = t^2*Q; Y = Y/t^2;
end

yz = y.*z; yh = y.*h;
gap = sum(yz)/m;
rmu = min(.5, gap)*gap;
rmu = max(rmu, minmu);

R1 = -A'*yh;
R2 = bmAx - h - z;
R3 = rmu - yz;

r1 = norm(R1,'inf');
r2 = norm(R2,'inf');
r3 = norm(R3,'inf');
res = max([r1 r2 r3]);
objval = log(det(E2))/2;

if mod(iter,10)==0
    fprintf('  iter %3i  ', iter);
    fprintf('%9.1e %9.1e %9.1e  %9.3e\n', r2,r1,r3,objval);
end
if (res < tol*(1+bnrm) && rmu <= minmu ) || (iter>100 && prev_obj ~= -Inf && (prev_obj >= (1-tol)*objval  || prev_obj <=(1-tol)*objval))
% if prev_obj ~= -Inf && (prev_obj >= (1-tol)*objval  || prev_obj <=(1-tol)*objval) && iter>10
   fprintf('  Converged!\n'); 
   x = x + x0; msg=1; break; 
end
prev_obj = objval;

YQ = Y*Q; YQQY = YQ.*YQ'; y2h = 2*yh; YA = Y*A;
G  = YQQY + sparse(1:m,1:m,max(1.e-8,y2h.*z)); %Ben
[csG,rsG] = gmscale(G,0,.99); %Ben
% T = (diag(1./rsG)*G*diag(1./csG)) \ (diag(1./rsG)*(sparse(1:m,1:m,h+z)*YA));
T = (diag(1./rsG)*G*diag(1./csG)) \ (diag(1./rsG)*(sparse(1:m,1:m,h+z)*YA)); %Ben
T = diag(1./csG)*T; %Ben
cond1(iter) = rcond(diag(1./rsG)*G*diag(1./csG)); %Ben
resid1(iter) = norm(G*T-sparse(1:m,1:m,h+z)*YA); %Ben
ATP = (sparse(1:m,1:m,y2h)*T-YA)';

R3Dy = R3./y; R23 = R2 - R3Dy;
ATP_A = ATP*A;
[csA,rsA] = gmscale(ATP_A,0,.99); %Ben
dx = (diag(1./rsA)*ATP_A*diag(1./csA))\(diag(1./rsA)*(R1 + ATP*R23)); %Ben
dx = diag(1./csA)*dx; %Ben
cond2(iter) = rcond(diag(1./rsA)*ATP_A*diag(1./csA)); %Ben

resid2(iter) = norm((ATP_A)*dx-(R1+ATP*R23)); %Ben

Adx = A*dx;
dyDy = (diag(1./rsG)*G*diag(1./csG))\(diag(1./rsG)*y2h.*(Adx - R23)); %Ben
dyDy = diag(1./csG)*dyDy; %Ben
resid3(iter) = norm(G*dyDy - y2h.*(Adx - R23)); %Ben

dy = y.*dyDy;
dz = R3Dy - z.*dyDy;

ax = -1/min([-Adx./bmAx; -.5]);
ay = -1/min([ dyDy; -.5]);
az = -1/min([dz./z; -.5]); 
tau = max(tau0, 1 - res);
astep = tau*min([1 ax ay az]);

x = x + astep*dx;
y = y + astep*dy;
z = z + astep*dz;

% fprintf('rG1=%e, rATP_A=%e, rG2=%e, cE = %e, cG=%e, cATP_A=%e\n', resid1(iter),resid2(iter),resid3(iter),condE(iter),cond1(iter),cond2(iter));%Ben 

if cond2(iter)<1e-5 && iter>=10 %Ben
    break; %Ben
end %Ben

end
