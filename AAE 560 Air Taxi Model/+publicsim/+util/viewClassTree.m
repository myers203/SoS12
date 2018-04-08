function  [H,allFullClasses]=viewClassTree(directory)
% View a class inheritence hierarchy. All classes residing in the directory
% or any subdirectory are discovered. Parents of these classes are also
% discovered as long as they are in the matlab search path. 
% There are a few restrictions:
% (1) classes must be written using the new 2008a classdef syntax
% (2) classes must reside in their own @ directories.
% (3) requires the bioinformatics biograph class to display the tree.
% (4) works only on systems that support 'dir', i.e. windows. 
%  
% directory  is an optional parameter specifying the directory one level
%            above all of the @ class directories. The current working
%            directory is used if this is not specified.
%Written by Matthew Dunham 



if nargin == 0
    directory = '.';
end


info = dirinfo(directory);
%baseClasses = vertcat(info.classes);
fullClasses = vertcat(info.fullClasses);
%baseClasses = cell(numel(fullClasses),1);
for i=1:numel(fullClasses)
    tmpVar=fullClasses{i};
    tmpVar(1)=[];
    tmpVar=strrep(tmpVar,'\+','.');
    tmpVar=strrep(tmpVar,'\','.');
    if tmpVar(1)=='.'
        tmpVar(1)=[];
    end
    fullClasses{i}=tmpVar;
    %sname=strsplit(tmpVar,'.');
    %baseClasses{i}=sname{end};
end

if(isempty(fullClasses))
    fprintf('\nNo classes found in this directory.\n');
    return;
end

%allClasses = baseClasses;
allFullClasses = fullClasses;
for c=1:numel(fullClasses)
   %allClasses = union(allClasses,ancestors(fullClasses{c}));
   allFullClasses = union(allFullClasses,ancestors(fullClasses{c}));
end

allClasses=cell(numel(allFullClasses),1);
for i=1:numel(allClasses)
    sname=strsplit(allFullClasses{i},'.');
    allClasses{i}=sname{end};
end

matrix = zeros(numel(allClasses));
map = struct;
for i=1:numel(allClasses)
   map.(allClasses{i}) = i; 
end

for i=1:numel(allClasses)
    try
        meta = eval(['?',allFullClasses{i}]);
        parents = meta.SuperClasses;
    catch ME
        warning('CLASSTREE:discoveryWarning',['Could not discover information about class ',allClasses{i}]);
        continue;
    end
    for j=1:numel(parents)
        pname=strsplit(parents{j}.Name,'.');
        pname=pname{end};
        if strcmp(pname,'handle') == 1 || strcmp(pname,'dynamicprops') == 1
            continue;
        end
        
       matrix(map.(allClasses{i}),map.(pname)) = 1;
    end
end

for i=1:numel(allClasses)
    allClasses{i} = ['@',allClasses{i},'-',num2str(i)]; 
end


G=digraph(matrix,allClasses);
%Prune unconnected classes
nodeOrder=indegree(G)+outdegree(G);
nodeId=1:numel(nodeOrder);
nodeId(nodeOrder > 0)=[];
H=rmnode(G,nodeId);
figure;
ph=plot(H,'Layout','layered');
nl = allClasses;
nl(nodeId) = [];
ph.NodeLabel = '';
xd = get(ph, 'XData');
yd = get(ph, 'YData');
th=text(xd, yd, nl, 'FontSize',9, 'FontWeight','bold', 'HorizontalAlignment','left', 'VerticalAlignment','middle');
set(th,'rotation',45);
set(gca, 'XTick', []);
set(gca, 'YTick', []);

%view(biograph(matrix,allFullClasses));

end

function info = dirinfo(directory)
%Recursively generate an array of structures holding information about each
%directory/subdirectory beginning, (and including) the initially specified
%parent directory. 
        info = what(directory);
        info.fullClasses=cell(numel(info.classes),1);
         for i=1:numel(info.classes)
             info.fullClasses{i}=[directory '\' info.classes{i}];
         end
        flist = dir(directory);
        dlist =  {flist([flist.isdir]).name};
        for i=1:numel(dlist)
            dirname = dlist{i};
            if(~strcmp(dirname,'.') && ~strcmp(dirname,'..'))
               info = [info, dirinfo([directory,'\',dirname])]; 
            end
        end
end

function list = ancestors(class)
%Recursively generate a list of all of the superclasses, (and superclasses
%of superclasses, etc) of the specified class. 
    list = {};
    try
        meta = eval(['?',class]);
        parents = meta.SuperClasses;
    catch
        return;
    end
    for p=1:numel(parents)
        if(p > numel(parents)),continue,end %bug fix for version 7.5.0 (2007b)
        list = [parents{p}.Name,ancestors(parents{p}.Name)];
    end
end




