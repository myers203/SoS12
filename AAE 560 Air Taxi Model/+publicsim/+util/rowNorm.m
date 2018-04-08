function out = rowNorm(mat)
% gives the 2 norm of each row in mat

mags = zeros(size(mat,1),1);

for i = 1:size(mat,2)
   mags = mags + mat(:,i).^2; 
end
mags = sqrt(mags);

out = mat.*repmat(1./mags, 1, size(mat,2));

end

