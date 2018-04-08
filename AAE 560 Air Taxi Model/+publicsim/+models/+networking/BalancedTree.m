function [ nodes ] = BalancedTree( numNodesPerBranch, nodeFunc, connectFunc )
%BALANCEDTREE Summary of this function goes here
%   Detailed explanation goes here

assert(numNodesPerBranch(1)==1,'Tree needs Single Node Root');
rootNode=nodeFunc(1,1);
childNodes=buildChildren(rootNode,numNodesPerBranch,2,nodeFunc,connectFunc,1);
nodes{1}={rootNode};

for i=2:(length(numNodesPerBranch)-1)
    nodes{i}=childNodes{1};
    childNodes=childNodes{2};
end
nodes{length(numNodesPerBranch)}=childNodes;

end

function nodes=buildChildren(rootNode,numNodes,numNodeIdx,nodeFunc,connectFunc,childIterNum)
leafNodes={};
childNodes={};
for k=1:numNodes(numNodeIdx)
    newNode=nodeFunc(numNodeIdx,childIterNum);
    connectFunc(rootNode,newNode);
    if numNodeIdx+1 <= length(numNodes)
        childNodes=[childNodes,buildChildren(newNode,numNodes,numNodeIdx+1,nodeFunc,connectFunc,k)]; %#ok<AGROW>
    end
    leafNodes{k}=newNode; %#ok<AGROW>
end

if ~isempty(childNodes)
    nodes={leafNodes,childNodes};
else
    nodes={leafNodes};
end
end
